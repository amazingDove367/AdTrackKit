//
//  BannerCell.swift
//  AdTrackKitDemo

import UIKit

final class BannerCell: UICollectionViewCell {
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

