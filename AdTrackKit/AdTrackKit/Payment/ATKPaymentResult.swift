//
//  ATKPaymentResult.swift
//  AdTrackKit
//
//  ATKTracker.shared.presentPayment(configuration:from:completion:) 의 결과 열거형.
//

import Foundation

// MARK: - ATKPaymentResult

/// 결제 시도의 최종 결과.
///
/// ```swift
/// ATKTracker.shared.presentPayment(configuration: config, from: self) { result in
///     switch result {
///     case .success(let orderId, let transactionId):
///         print("결제 성공 - 주문번호: \(orderId), TID: \(transactionId)")
///
///     case .failure(let message):
///         print("결제 실패: \(message)")
///
///     case .cancelled:
///         print("결제 취소됨")
///     }
/// }
/// ```
public enum ATKPaymentResult {

    /// 결제 성공.
    /// - Parameters:
    ///   - orderId: SDK가 생성한 주문번호 (예: `"ORD20260227153045"`)
    ///   - transactionId: 이니시스가 발급한 거래 ID (P_TID)
    case success(orderId: String, transactionId: String)

    /// 결제 실패 (카드 한도 초과, 비밀번호 오류 등 PG사가 반환한 사유)
    case failure(message: String)

    /// 사용자가 결제창을 닫거나 취소 버튼을 눌러 결제를 중단한 경우
    case cancelled
}
