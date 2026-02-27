//
//  ATKEvent.swift
//  AdTrackKit

/// **필요한 이유**
///   --> 사용자가 뭘 했는지 기록하는 데이터 구조
///   --> 이벤트 이름, 시간, 추가 속성 등을 담는 "설계도"

import Foundation

// MARK: - 이벤트 모델

struct ATKEvent: Codable {
    let id: String
    let name: String
    let properties: [String: String]?
    let timestamp: Date
    let sessionId: String

    // MARK: 초기화
    init(
        name: String,
        properties: [String: String]? = nil,
        sessionId: String
    ) {
        self.id = UUID().uuidString
        self.name = name
        self.properties = properties
        self.timestamp = Date()
        self.sessionId = sessionId
    }
}

/// struct 사용 이유 (not class)
///   --> 이벤트는 한번 만들어지면 변하지 않는 "값(value)"
///   --> 값 타입이 참조 타입 보다 안전하고 가벼움
///   --> 멀티스래딩에서도 복사되니까 동시 접근 문제가 적용
/// Codable 사용 이유
///   Encodable: (struct -> JSON/Data), Codable: (JSON/Data -> struct)
///   --> UserDefaults에 저장하려면 Data로 변환해야하니 & 서버에 보낼 때 JSON으로 변환해야 하니

/// ─────────────────────────────────────────
/// 이 struct가 JSON으로 변환되면 이런 모양:
/// {
///  "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
///  "name": "purchase",
///  "properties": {
///   "price": "29900",
///   "product_id": "SKU-001"
///  },
///  "timestamp": "2026-02-16T10:30:45Z",
///  "session_id": "F1E2D3C4-B5A6-..."
/// }
