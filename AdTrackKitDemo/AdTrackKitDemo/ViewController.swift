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

// MARK: - CategoryBarView

private final class CategoryBarView: UIView {

    var onCategorySelected: ((Product.Category) -> Void)?

    private let scrollView = UIScrollView()
    private var buttons: [UIButton] = []
    private var selected: Product.Category = .all

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildViews() {
        backgroundColor = .systemBackground

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        for (index, category) in Product.Category.allCases.enumerated() {
            var config = UIButton.Configuration.bordered()
            config.title = category.rawValue
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
                var a = attrs; a.font = .systemFont(ofSize: 14, weight: .medium); return a
            }
            config.contentInsets = .init(top: 6, leading: 14, bottom: 6, trailing: 14)
            config.cornerStyle = .capsule

            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separator)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: separator.topAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stack.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -16),

            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
        ])

        refreshButtonStyles()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        let category = Product.Category.allCases[sender.tag]
        guard category != selected else { return }
        selected = category
        refreshButtonStyles()
        onCategorySelected?(category)
    }

    private func refreshButtonStyles() {
        for (index, button) in buttons.enumerated() {
            let isSelected = Product.Category.allCases[index] == selected
            var config = button.configuration ?? .bordered()
            config.baseBackgroundColor = isSelected ? .systemBlue : .clear
            config.baseForegroundColor = isSelected ? .white : .systemBlue
            button.configuration = config
        }
    }
}

// MARK: - BannerCell

private final class BannerCell: UICollectionViewCell {
    static let reuseID = "BannerCell"

    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        gradientLayer.colors = [
            UIColor(red: 0/255, green: 122/255, blue: 255/255, alpha: 1).cgColor,
            UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1).cgColor,
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)
        contentView.layer.insertSublayer(gradientLayer, at: 0)

        // Decorative emoji
        let emojiLabel = UILabel()
        emojiLabel.text = "☀️"
        emojiLabel.font = .systemFont(ofSize: 72)
        emojiLabel.alpha = 0.25
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(emojiLabel)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "봄맞이 특별 기획전"
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "인기 전자기기 · 액세서리 최대 35% 할인"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // CTA Pill
        let ctaContainer = UIView()
        ctaContainer.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        ctaContainer.layer.cornerRadius = 14
        ctaContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(ctaContainer)

        let ctaLabel = UILabel()
        ctaLabel.text = "지금 쇼핑하기 →"
        ctaLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        ctaLabel.textColor = .white
        ctaLabel.translatesAutoresizingMaskIntoConstraints = false
        ctaContainer.addSubview(ctaLabel)

        NSLayoutConstraint.activate([
            emojiLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: 16),
            emojiLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 16),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 44),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),

            ctaContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            ctaContainer.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),

            ctaLabel.topAnchor.constraint(equalTo: ctaContainer.topAnchor, constant: 7),
            ctaLabel.bottomAnchor.constraint(equalTo: ctaContainer.bottomAnchor, constant: -7),
            ctaLabel.leadingAnchor.constraint(equalTo: ctaContainer.leadingAnchor, constant: 14),
            ctaLabel.trailingAnchor.constraint(equalTo: ctaContainer.trailingAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }
}

// MARK: - ProductCell

final class ProductCell: UICollectionViewCell {
    static let reuseID = "ProductCell"

    private let emojiLabel        = UILabel()
    private let badgeLabel        = UILabel()
    private let nameLabel         = UILabel()
    private let originalPriceLabel = UILabel()
    private let priceLabel        = UILabel()
    private let discountLabel     = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        buildViews()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func buildViews() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 18
        contentView.layer.shadowColor   = UIColor.black.cgColor
        contentView.layer.shadowOpacity = 0.08
        contentView.layer.shadowOffset  = CGSize(width: 0, height: 3)
        contentView.layer.shadowRadius  = 8
        contentView.layer.masksToBounds = false

        // Emoji circle
        let circle = UIView()
        circle.backgroundColor = .systemGray6
        circle.layer.cornerRadius = 32
        circle.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(circle)

        emojiLabel.font = .systemFont(ofSize: 34)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(emojiLabel)

        // Badge
        badgeLabel.font = .systemFont(ofSize: 10, weight: .bold)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(badgeLabel)

        // Name
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.textColor = .label
        nameLabel.numberOfLines = 2
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(nameLabel)

        // Original price (strikethrough)
        originalPriceLabel.font = .systemFont(ofSize: 11)
        originalPriceLabel.textColor = .tertiaryLabel
        originalPriceLabel.isHidden = true
        originalPriceLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(originalPriceLabel)

        // Price + discount row
        priceLabel.font = .systemFont(ofSize: 16, weight: .bold)
        priceLabel.textColor = .label

        discountLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        discountLabel.textColor = .systemRed
        discountLabel.isHidden = true

        let priceRow = UIStackView(arrangedSubviews: [priceLabel, discountLabel])
        priceRow.axis = .horizontal
        priceRow.spacing = 4
        priceRow.alignment = .center
        priceRow.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(priceRow)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            circle.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            circle.widthAnchor.constraint(equalToConstant: 64),
            circle.heightAnchor.constraint(equalToConstant: 64),

            emojiLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            badgeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            badgeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 36),

            nameLabel.topAnchor.constraint(equalTo: circle.bottomAnchor, constant: 10),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            originalPriceLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 6),
            originalPriceLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),

            priceRow.topAnchor.constraint(equalTo: originalPriceLabel.bottomAnchor, constant: 2),
            priceRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            priceRow.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -12),
        ])
    }

    func configure(with product: Product) {
        emojiLabel.text = product.emoji
        nameLabel.text  = product.name
        priceLabel.text = product.formattedPrice

        // Badge
        if let badge = product.badge {
            badgeLabel.isHidden = false
            badgeLabel.text = " \(badge.rawValue) "
            switch badge {
            case .best: badgeLabel.backgroundColor = .systemOrange
            case .new:  badgeLabel.backgroundColor = .systemGreen
            case .sale: badgeLabel.backgroundColor = .systemRed
            }
        } else {
            badgeLabel.isHidden = true
        }

        // Original price (strikethrough)
        if let original = product.formattedOriginalPrice {
            originalPriceLabel.isHidden = false
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
            originalPriceLabel.attributedText = NSAttributedString(string: original, attributes: attrs)
        } else {
            originalPriceLabel.isHidden = true
        }

        // Discount rate
        if let rate = product.discountRate {
            discountLabel.isHidden = false
            discountLabel.text = "\(rate)%"
        } else {
            discountLabel.isHidden = true
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        badgeLabel.isHidden = true
        originalPriceLabel.isHidden = true
        discountLabel.isHidden = true
    }
}
