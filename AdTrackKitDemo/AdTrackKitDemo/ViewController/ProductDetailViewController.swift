//
//  ProductDetailViewController.swift
//  AdTrackKitDemo
//
//  상품 상세 화면: 히어로 카드 + 상품 정보 + 하단 고정 결제 버튼
//

import UIKit
import AdTrackKit

final class ProductDetailViewController: UIViewController {

    // MARK: - Properties

    private let product: Product

    // MARK: - Views

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // 하단 고정 바
    private let bottomBar: UIView = {
        let v = UIView()
        v.backgroundColor = .systemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var cartButton: UIButton = {
        var config = UIButton.Configuration.bordered()
        config.title = "장바구니"
        config.image = UIImage(systemName: "cart.badge.plus")
        config.imagePadding = 6
        config.cornerStyle = .large
        config.baseForegroundColor = .systemBlue
        config.baseBackgroundColor = .clear
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(cartTapped), for: .touchUpInside)
        return btn
    }()

    private lazy var buyButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "지금 결제하기"
        config.image = UIImage(systemName: "creditcard.fill")
        config.imagePadding = 8
        config.cornerStyle = .large
        config.baseBackgroundColor = .systemBlue
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(buyTapped), for: .touchUpInside)
        return btn
    }()

    // MARK: - Init

    init(product: Product) {
        self.product = product
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupLayout()
        buildContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ATKTracker.shared.logEvent("view_item_detail", properties: [
            "product_id":   product.id,
            "product_name": product.name,
            "price":        "\(product.price)"
        ])
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = ""
        view.backgroundColor = .systemGroupedBackground
        navigationController?.navigationBar.tintColor = .systemBlue

        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain, target: self, action: #selector(shareTapped)
        )
        let heartBtn = UIBarButtonItem(
            image: UIImage(systemName: "heart"),
            style: .plain, target: self, action: #selector(heartTapped)
        )
        navigationItem.rightBarButtonItems = [shareBtn, heartBtn]
    }

    private func setupLayout() {
        view.addSubview(scrollView)
        view.addSubview(bottomBar)
        scrollView.addSubview(contentStack)

        // 구분선
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(separator)

        let buttonRow = UIStackView(arrangedSubviews: [cartButton, buyButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 10
        buttonRow.distribution = .fill
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(buttonRow)

        NSLayoutConstraint.activate([
            // bottomBar
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            separator.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            buttonRow.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 12),
            buttonRow.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            buttonRow.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),
            buttonRow.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),

            cartButton.widthAnchor.constraint(equalTo: buttonRow.widthAnchor, multiplier: 0.38),
            buyButton.heightAnchor.constraint(equalToConstant: 52),
            cartButton.heightAnchor.constraint(equalToConstant: 52),

            // scrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
    }

    // MARK: - Content Builder

    private func buildContent() {
        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.addArrangedSubview(makePriceSection())
        contentStack.addArrangedSubview(makeRatingSection())
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeDescriptionSection())
        contentStack.addArrangedSubview(makeDivider())
        contentStack.addArrangedSubview(makeDeliverySection())
        contentStack.addArrangedSubview(makeBottomPadding())
    }

    // MARK: - Section Builders

    private func makeHeroCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .systemBackground

        // Gradient 배경
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.systemBlue.withAlphaComponent(0.08).cgColor,
            UIColor.systemPurple.withAlphaComponent(0.04).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint   = CGPoint(x: 1, y: 1)

        let gradientView = UIView()
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(gradientView)
        DispatchQueue.main.async { gradientLayer.frame = gradientView.bounds }

        // 이모지 컨테이너
        let circle = UIView()
        circle.backgroundColor = .systemGroupedBackground
        circle.layer.cornerRadius = 56
        circle.layer.shadowColor  = UIColor.black.cgColor
        circle.layer.shadowOpacity = 0.08
        circle.layer.shadowOffset  = .init(width: 0, height: 4)
        circle.layer.shadowRadius  = 12
        circle.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(circle)

        let emojiLabel = UILabel()
        emojiLabel.text = product.emoji
        emojiLabel.font = .systemFont(ofSize: 64)
        emojiLabel.textAlignment = .center
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(emojiLabel)

        // 배지
        if let badge = product.badge {
            let badgeLabel = makeBadgeLabel(text: badge.rawValue, for: badge)
            card.addSubview(badgeLabel)
            NSLayoutConstraint.activate([
                badgeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
                badgeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            ])
        }

        NSLayoutConstraint.activate([
            gradientView.topAnchor.constraint(equalTo: card.topAnchor),
            gradientView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: card.bottomAnchor),

            circle.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            circle.topAnchor.constraint(equalTo: card.topAnchor, constant: 36),
            circle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -36),
            circle.widthAnchor.constraint(equalToConstant: 112),
            circle.heightAnchor.constraint(equalToConstant: 112),

            emojiLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            emojiLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
        ])

        return card
    }

    private func makePriceSection() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let nameLabel = UILabel()
        nameLabel.text = product.name
        nameLabel.font = .systemFont(ofSize: 20, weight: .bold)
        nameLabel.numberOfLines = 0
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let priceStack = UIStackView()
        priceStack.axis = .vertical
        priceStack.spacing = 4
        priceStack.translatesAutoresizingMaskIntoConstraints = false

        if let originalPrice = product.formattedOriginalPrice,
           let rate = product.discountRate {
            // 정가 취소선
            let origLabel = UILabel()
            let attrs: [NSAttributedString.Key: Any] = [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: UIColor.tertiaryLabel
            ]
            origLabel.attributedText = NSAttributedString(string: originalPrice, attributes: attrs)
            origLabel.font = .systemFont(ofSize: 14)
            priceStack.addArrangedSubview(origLabel)

            // 할인가 + 할인율
            let priceRow = UIStackView()
            priceRow.axis = .horizontal
            priceRow.spacing = 8
            priceRow.alignment = .bottom

            let priceLabel = UILabel()
            priceLabel.text = product.formattedPrice
            priceLabel.font = .systemFont(ofSize: 26, weight: .black)

            let rateLabel = makeBadgeLabel(text: "\(rate)%", color: .systemRed)
            priceRow.addArrangedSubview(priceLabel)
            priceRow.addArrangedSubview(rateLabel)
            priceRow.addArrangedSubview(UIView()) // spacer
            priceStack.addArrangedSubview(priceRow)
        } else {
            let priceLabel = UILabel()
            priceLabel.text = product.formattedPrice
            priceLabel.font = .systemFont(ofSize: 26, weight: .black)
            priceStack.addArrangedSubview(priceLabel)
        }

        container.addSubview(nameLabel)
        container.addSubview(priceStack)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            priceStack.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 14),
            priceStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            priceStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            priceStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
        return container
    }

    private func makeRatingSection() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let stars = UILabel()
        stars.text = "★★★★☆"
        stars.font = .systemFont(ofSize: 15)
        stars.textColor = .systemOrange
        stars.translatesAutoresizingMaskIntoConstraints = false

        let score = UILabel()
        score.text = "4.5 (1,247개 리뷰)"
        score.font = .systemFont(ofSize: 14)
        score.textColor = .secondaryLabel
        score.translatesAutoresizingMaskIntoConstraints = false

        let dot = UILabel()
        dot.text = "•"
        dot.textColor = .separator
        dot.translatesAutoresizingMaskIntoConstraints = false

        let soldLabel = UILabel()
        soldLabel.text = "3,500+ 판매"
        soldLabel.font = .systemFont(ofSize: 14)
        soldLabel.textColor = .secondaryLabel
        soldLabel.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [stars, score, dot, soldLabel, UIView()])
        row.axis = .horizontal
        row.spacing = 6
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        return container
    }

    private func makeDescriptionSection() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let header = makeSectionHeader("상품 설명")
        let body = UILabel()
        body.text = product.description
        body.font = .systemFont(ofSize: 15)
        body.textColor = .secondaryLabel
        body.numberOfLines = 0
        body.lineBreakMode = .byWordWrapping
        body.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(header)
        container.addSubview(body)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            body.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 12),
            body.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            body.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
        return container
    }

    private func makeDeliverySection() -> UIView {
        let container = UIView()
        container.backgroundColor = .systemBackground

        let header = makeSectionHeader("배송 안내")

        let rows: [(String, String)] = [
            ("배송", "무료배송"),
            ("도착 예정", "오늘 주문 시 내일 도착"),
            ("판매자", "ATK MALL 공식스토어"),
            ("원산지", "대한민국"),
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (label, value) in rows {
            let row = makeInfoRow(label: label, value: value)
            stack.addArrangedSubview(row)
        }

        container.addSubview(header)
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),

            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
        ])
        return container
    }

    // MARK: - Helpers

    private func makeSectionHeader(_ title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12

        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 14)
        labelView.textColor = .secondaryLabel
        labelView.setContentHuggingPriority(.required, for: .horizontal)

        let valueView = UILabel()
        valueView.text = value
        valueView.font = .systemFont(ofSize: 14, weight: .medium)
        valueView.textAlignment = .right

        row.addArrangedSubview(labelView)
        row.addArrangedSubview(UIView()) // spacer
        row.addArrangedSubview(valueView)
        return row
    }

    private func makeBadgeLabel(text: String, for badge: Product.Badge) -> UILabel {
        let color: UIColor
        switch badge {
        case .best: color = .systemOrange
        case .new:  color = .systemGreen
        case .sale: color = .systemRed
        }
        return makeBadgeLabel(text: text, color: color)
    }

    private func makeBadgeLabel(text: String, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = " \(text) "
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.backgroundColor = color
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeDivider() -> UIView {
        let spacer = UIView()
        spacer.backgroundColor = .systemGroupedBackground
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return spacer
    }

    private func makeBottomPadding() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 20).isActive = true
        return v
    }

    // MARK: - Actions

    @objc
    private func buyTapped() {
        ATKTracker.shared.logEvent("begin_checkout", properties: [
            "product_id":   product.id,
            "product_name": product.name,
            "price":        "\(product.price)"
        ])
        let paymentVC = InicisPaymentViewController(product: product)
        navigationController?.pushViewController(paymentVC, animated: true)
    }

    @objc
    private func cartTapped() {
        ATKTracker.shared.logEvent("add_to_cart", properties: [
            "product_id":   product.id,
            "product_name": product.name,
            "price":        "\(product.price)"
        ])
        showToast("장바구니에 담았습니다.")
    }

    @objc
    private func heartTapped() {
        ATKTracker.shared.logEvent("add_to_wishlist", properties: [
            "product_id": product.id
        ])
        navigationItem.rightBarButtonItems?.last?.image = UIImage(systemName: "heart.fill")
        showToast("찜 목록에 추가되었습니다.")
    }

    @objc
    private func shareTapped() {
        let text = "\(product.name) - \(product.formattedPrice)\nATK MALL에서 확인하세요!"
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(vc, animated: true)
    }

    private func showToast(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { alert.dismiss(animated: true) }
    }
}
