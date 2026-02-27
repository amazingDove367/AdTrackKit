//
//  ATKTracker+Payment.swift
//  AdTrackKit
//
//  ATKTracker에 결제 기능을 추가하는 UIKit extension.
//  Core 파일(ATKTracker.swift)은 Foundation만 사용하고,
//  UIKit 의존성은 이 파일에서만 가져갑니다.
//
//  외부 개발자가 사용하는 코드:
//  ```swift
//  let config = ATKPaymentConfiguration(
//      productId:    "P001",
//      productName:  "프리미엄 무선 이어폰",
//      productEmoji: "🎧",
//      price:        89_000,
//      returnScheme: "myapp"
//  )
//
//  ATKTracker.shared.presentPayment(configuration: config, from: self) { result in
//      switch result {
//      case .success(let orderId, let tid): print("성공 \(orderId)")
//      case .failure(let message):          print("실패 \(message)")
//      case .cancelled:                     print("취소")
//      }
//  }
//  ```

import UIKit

// MARK: - ATKTracker + Payment

public extension ATKTracker {

    /// KG이니시스 결제창을 SDK 내부 WKWebView로 제시합니다.
    ///
    /// - Parameters:
    ///   - configuration: 결제에 필요한 상품·PG·구매자 정보
    ///   - viewController: 결제창을 present할 뷰 컨트롤러
    ///   - completion: 결제 완료 후 호출되는 클로저 (`ATKPaymentResult`)
    ///
    /// - Note: 결제 성공 시 `purchase` 이벤트가 자동으로 `ATKTracker.logEvent()` 에 기록됩니다.
    ///         `Info.plist`에 `configuration.returnScheme`이 `CFBundleURLTypes`로 등록되어 있어야 합니다.
    func presentPayment(
        configuration: ATKPaymentConfiguration,
        from viewController: UIViewController,
        completion: @escaping (ATKPaymentResult) -> Void
    ) {
        guard isInitialized else {
            ATKLogger.error("SDK가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.")
            completion(.failure(message: "SDK가 초기화되지 않았습니다."))
            return
        }

        ATKLogger.info("결제 시작 - 상품: \(configuration.productName), 금액: \(configuration.price)원")

        let paymentVC = ATKPaymentViewController(
            configuration: configuration,
            completion: completion
        )
        let nav = UINavigationController(rootViewController: paymentVC)
        nav.modalPresentationStyle = .fullScreen
        viewController.present(nav, animated: true)
    }
}
