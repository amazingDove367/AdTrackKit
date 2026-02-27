//
//  ViewController.swift
//  AdTrackKitDemo
//
//  쇼핑몰 메인 화면: 배너 + 카테고리 필터 + 상품 그리드
//

import UIKit
import AdTrackKit

// MARK: - ShopViewController

final class ShopViewController: UIViewController {

    // MARK: - State

    private var allProducts = Product.samples
    private var selectedCategory: Product.Category = .all {
        didSet { applySnapshot(animated: true) }
    }
    private var displayedProducts: [Product] {
        guard selectedCategory != .all else { return allProducts }
        return allProducts.filter { $0.category == selectedCategory }
    }

    // MARK: - Views

    private lazy var categoryBar: CategoryBarView = {
        let bar = CategoryBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.onCategorySelected = { [weak self] category in
            guard let self else { return }
            self.selectedCategory = category
            ATKTracker.shared.logEvent("category_filter", properties: [
                "category": category.rawValue
            ])
        }
        return bar
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.backgroundColor = .systemGroupedBackground
        cv.showsVerticalScrollIndicator = false
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.delegate = self
        cv.register(BannerCell.self, forCellWithReuseIdentifier: BannerCell.reuseID)
        cv.register(ProductCell.self, forCellWithReuseIdentifier: ProductCell.reuseID)
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<ShopSection, ShopItem>!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupLayout()
        configureDataSource()
        applySnapshot(animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ATKTracker.shared.logEvent("screen_view", properties: [
            "screen_name": "ShopMain"
        ])
    }

    // MARK: - Navigation

    private func setupNavigation() {
        view.backgroundColor = .systemBackground

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .black)
        ]
        let logo = NSMutableAttributedString(string: "ATK MALL", attributes: attrs)
        logo.addAttribute(.foregroundColor, value: UIColor.systemBlue,
                          range: NSRange(location: 0, length: 3))
        logo.addAttribute(.foregroundColor, value: UIColor.label,
                          range: NSRange(location: 3, length: 5))
        let logoLabel = UILabel()
        logoLabel.attributedText = logo
        navigationItem.titleView = logoLabel

        let cartBtn = UIBarButtonItem(
            image: UIImage(systemName: "cart"),
            style: .plain, target: self, action: #selector(cartTapped)
        )
        let searchBtn = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain, target: self, action: #selector(searchTapped)
        )
        navigationItem.rightBarButtonItems = [cartBtn, searchBtn]
        navigationController?.navigationBar.tintColor = .systemBlue
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(categoryBar)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            categoryBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            categoryBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            categoryBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            categoryBar.heightAnchor.constraint(equalToConstant: 48),

            collectionView.topAnchor.constraint(equalTo: categoryBar.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Compositional Layout

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ -> NSCollectionLayoutSection? in
            guard let self, let section = ShopSection(rawValue: sectionIndex) else { return nil }
            switch section {
            case .banner:   return self.makeBannerSection()
            case .products: return self.makeProductsSection()
            }
        }
    }

    private func makeBannerSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .fractionalHeight(1))
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .absolute(200)),
            subitems: [item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = .init(top: 0, leading: 0, bottom: 16, trailing: 0)
        return section
    }

    private func makeProductsSection() -> NSCollectionLayoutSection {
        let item = NSCollectionLayoutItem(
            layoutSize: .init(widthDimension: .fractionalWidth(0.5),
                              heightDimension: .fractionalHeight(1))
        )
        item.contentInsets = .init(top: 0, leading: 6, bottom: 0, trailing: 6)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: .init(widthDimension: .fractionalWidth(1),
                              heightDimension: .absolute(225)),
            subitems: [item, item]
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 14
        section.contentInsets = .init(top: 4, leading: 10, bottom: 30, trailing: 10)
        return section
    }

    // MARK: - DiffableDataSource

    private func configureDataSource() {
        dataSource = UICollectionViewDiffableDataSource(collectionView: collectionView) { [weak self] cv, indexPath, item in
            switch item {
            case .banner:
                return cv.dequeueReusableCell(withReuseIdentifier: BannerCell.reuseID, for: indexPath)
            case .product(let id):
                let cell = cv.dequeueReusableCell(withReuseIdentifier: ProductCell.reuseID, for: indexPath) as! ProductCell
                if let product = self?.allProducts.first(where: { $0.id == id }) {
                    cell.configure(with: product)
                }
                return cell
            }
        }
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<ShopSection, ShopItem>()
        snapshot.appendSections(ShopSection.allCases)
        snapshot.appendItems([.banner], toSection: .banner)
        snapshot.appendItems(displayedProducts.map { .product(id: $0.id) }, toSection: .products)
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    // MARK: - Actions

    @objc private func cartTapped() {
        ATKTracker.shared.logEvent("cart_viewed", properties: [:])
        showToast("장바구니 기능은 준비 중입니다.")
    }

    @objc private func searchTapped() {
        ATKTracker.shared.logEvent("search", properties: ["query": ""])
        showToast("검색 기능은 준비 중입니다.")
    }

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { alert.dismiss(animated: true) }
    }
}

// MARK: - UICollectionViewDelegate

extension ShopViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath),
              case .product(let id) = item,
              let product = allProducts.first(where: { $0.id == id }) else { return }

        ATKTracker.shared.logEvent("view_item", properties: [
            "product_id":   product.id,
            "product_name": product.name,
            "price":        "\(product.price)"
        ])

        let detailVC = ProductDetailViewController(product: product)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}
