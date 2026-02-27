//
//  CategoryBarView.swift
//  AdTrackKitDemo

import UIKit

final class CategoryBarView: UIView {

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
