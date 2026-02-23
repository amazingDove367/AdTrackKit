//
//  ViewController.swift
//  AdTrackKitDemo
//
//  Created by kingj on 2/16/26.
//

import UIKit
import AdTrackKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    // 화면이 나타날 때마다 screen_view 이벤트 기록
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ATKTracker.shared.logEvent(
            "screen_view",
            properties: ["screen_name": "MainViewController"]
        )
    }

    // MARK: - UI 구성
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "AdTrackKit Demo"

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])

        let buttons: [(title: String, color: UIColor, action: Selector)] = [
            ("🛒 구매 이벤트", .systemBlue, #selector(purchaseTapped)),
            ("📝 회원가입 이벤트", .systemGreen, #selector(signUpTapped)),
            ("🔍 검색 이벤트", .systemOrange, #selector(searchTapped)),
            ("📤 Flush (즉시 전송)", .systemRed, #selector(flushTapped)),
        ]

        for info in buttons {
            let button = UIButton(type: .system)
            button.setTitle(info.title, for: .normal)
            button.backgroundColor = info.color
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .boldSystemFont(ofSize: 16)
            button.layer.cornerRadius = 12
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
            button.addTarget(self, action: info.action, for: .touchUpInside)
            stackView.addArrangedSubview(button)
        }
    }

    // MARK: - Button Action

    @objc
    private func purchaseTapped() {
        ATKTracker.shared.logEvent("purchase", properties: [
            "product_id": "SKU-001",
            "price": "29900",
            "currency": "KRW"
        ])
        showAlert("구매 이벤트 기록됨!")
    }

    @objc
    private func signUpTapped() {
        ATKTracker.shared.logEvent("sign_up", properties: [
            "method": "apple_login"
        ])
        showAlert("회원가입 이벤트 기록됨!")
    }

    @objc
    private func searchTapped() {
        ATKTracker.shared.logEvent("search", properties: [
            "query": "아이폰 케이스"
        ])
        showAlert("검색 이벤트 기록됨!")
    }

    @objc
    private func flushTapped() {
        ATKTracker.shared.flush()
        showAlert("Flush 호출됨! (콘솔 확인)")
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(
            title: "AdTrackKit",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

