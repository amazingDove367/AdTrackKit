//
//  ProductCell.swift
//  AdTrackKitDemo

import UIKit

final class ProductCell: UICollectionViewCell {
    static let reuseID = "ProductCell"

    private let emojiLabel = UILabel()
    private let badgeLabel = UILabel()
    private let nameLabel = UILabel()
    private let originalPriceLabel = UILabel()
    private let priceLabel = UILabel()
    private let discountLabel = UILabel()

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
