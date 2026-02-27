//
//  ATKPaymentConfiguration.swift
//  AdTrackKit
//
//  KG이니시스 결제를 SDK에서 직접 호출하기 위한 설정 객체.
//  외부 앱에서 ATKTracker.shared.presentPayment(configuration:from:completion:) 호출 시 전달합니다.
//

import Foundation

// MARK: - ATKPaymentConfiguration

/// KG이니시스 결제 요청에 필요한 설정을 담는 값 타입.
///
/// 사용 예시:
/// ```swift
/// let config = ATKPaymentConfiguration(
///     productId:    "P001",
///     productName:  "프리미엄 무선 이어폰",
///     productEmoji: "🎧",
///     price:        89_000,
///     returnScheme: "myapp"   // Info.plist CFBundleURLTypes 등록 필요
/// )
/// ATKTracker.shared.presentPayment(configuration: config, from: self) { result in ... }
/// ```
public struct ATKPaymentConfiguration {

    // MARK: - 상품 정보

    /// 상품 고유 ID (트래킹 이벤트에 기록)
    public let productId: String

    /// 결제창에 표시될 상품명 (이니시스 제한: 최대 40자)
    public let productName: String

    /// 결제 UI에 표시될 이모지 아이콘 (예: "🎧")
    public let productEmoji: String

    /// 결제 금액 (원화, 정수)
    public let price: Int

    // MARK: - PG 설정

    /// 이니시스 상점 ID (테스트: "INIpayTest" / 운영: 실제 MID 교체)
    public let mid: String

    /// 결제 완료 후 이니시스가 리디렉션할 앱 URL 스킴.
    /// `Info.plist`의 `CFBundleURLTypes`에 반드시 등록되어 있어야 합니다.
    public let returnScheme: String

    // MARK: - 구매자 정보

    /// 주문자 이름
    public let buyerName: String

    /// 주문자 휴대폰 번호 (하이픈 없이, 예: "01012345678")
    public let buyerTel: String

    /// 주문자 이메일
    public let buyerEmail: String

    // MARK: - Init

    public init(
        productId: String,
        productName: String,
        productEmoji: String = "",
        price: Int,
        mid: String = "INIpayTest",
        returnScheme: String,
        buyerName: String = "홍길동",
        buyerTel: String = "01012345678",
        buyerEmail: String = "buyer@example.com"
    ) {
        self.productId    = productId
        self.productName  = productName
        self.productEmoji = productEmoji
        self.price        = price
        self.mid          = mid
        self.returnScheme = returnScheme
        self.buyerName    = buyerName
        self.buyerTel     = buyerTel
        self.buyerEmail   = buyerEmail
    }
}
