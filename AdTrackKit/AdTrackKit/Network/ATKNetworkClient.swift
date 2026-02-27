//
//  ATKNetworkClient.swift
//  AdTrackKit

/// **필요한 이유**
/// --> 이벤트 데이터를 실제로 서버에 HTTP POST로 보내는 역할
/// --> URLSession을 감싸서 SDK에 맞게 사용하기 쉽게 만든 것

import Foundation

final class ATKNetworkClient {

    // MARK: - 서버 URL

    // 테스트 서버: httpbin.org는 보낸 데이터를 그대로 돌려주는 공개 서버
    // 실제 회사에서는 이 URL만 진짜 서버 주소로 바꾸면 됨
    private let baseURL: URL
    private let session: URLSession

    // MARK: -  초기화

    init(
        baseURL: URL = URL(string: "https://httpbin.org")!,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - 이벤트 전송 메서드

    /// events: 보낼 이벤트 배열
    /// appKey: 앱 식별 키
    /// completion: 전송결과 알려주는 콜백
    func sendEvents(
        _ events: [ATKEvent],
        appKey: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        // MARK: 1. URL

        let url = baseURL.appending(path: "post")

        // MARK: 2. URLRequet

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        // MARK: 3. Body
        // 서버에 보낼 JSON 구조

        let requestBody: [String: Any] = [
            "app_key": appKey,
            "sent_at": ISO8601DateFormatter().string(from: Date()),
            "events": events.map({ event -> [String: Any] in
                // map: 배열의 각 요소를 변환하는 함수
                // [ATKEvent] -> [[String: Any]] 딕셔너리 배열로 변환
                //
                // 왜 JSONEncoder 안쓰고 수동변환?
                //  --> requestBody 전체가 [String: Any] 딕셔너리 타입이라서
                //      JSONSerialization(= 딕셔너리 -> JSON) 으로 한번에 Data로 만들려고
                var dict: [String: Any] = [
                    "id": event.id,
                    "name": event.name,
                    "timestamp": ISO8601DateFormatter().string(from: event.timestamp),
                    "session_id": event.sessionId
                ]

                if let props = event.properties {
                    dict["properties"] = props
                }

                return dict
            }),
            "device": collectionDeviceInfo()
        ]
        /// 우리가 서버에 보내고 싶은 JSON 모양:
        /// {
        ///   "app_key": "demo-123",          ← String
        ///   "sent_at": "2026-02-20T...",    ← String
        ///   "events": [...],                          ← 배열
        ///   "device": {...}                          ← 딕셔너리
        /// }
        ///
        /// 이 구조를 하나의 Struct 로 만들면, JSONEncoder 사용 가능!
        /// 예)
        ///  let payload = Payload(appKey: "demo", sentAt: "...", events: events, device: ...)
        ///  let data = try JSONEncoder().encode(payload)  // 깔끔!

        // Dictionary -> JSON Data로 변환
        guard let httpBody = try? JSONSerialization.data(
            withJSONObject: requestBody,
            options: []
            // options: [] -> 압축된 JSON (줄바꿈 없음, 네트워크 전송에 적합)
            // options: [.prettyPrinted] -> 보기 좋게 들여쓰기 (디버깅용)
        ) else {
            ATKLogger.error("JSON 직렬화 실패")
            completion(.failure(ATKError.serializationFailed))
            return
        }

        request.httpBody = httpBody

        ATKLogger.debug("(서버 전송 1) 전송 요청: \(events.count)개 이벤트, \(httpBody.count) bytes")

        // MARK: 4. URLSession (실제 전송)

        let task = session.dataTask(with: request) { data, response, error in
            // Error 체크
            if let error {
                ATKLogger.error("(서버 전송 1) 네트워크 에러: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // HTTP 상태 코드 체크
            guard let httpResponse = response as? HTTPURLResponse else {
                ATKLogger.error("(서버 전송 2) 응답 형식 에러")
                completion(.failure(ATKError.invalidResponse))
                return
            }
            let statusCode = httpResponse.statusCode
            ATKLogger.debug("(서버 전송 2) 서버 응답: HTTP \(statusCode)")

            // 성공/실패
            switch statusCode {
            case 200...299:
                // 디버깅용: 서버가 돌려준 데이터 출력
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    ATKLogger.debug("😊 서버 응답:\n\(prettyString)")
                }

                ATKLogger.info("(서버 전송 3) 전송 성공: \(events.count)개 이벤트")
                completion(.success(()))

            default:
                ATKLogger.error("(서버 전송 3) 서버 에러: HTTP \(statusCode)")
                completion(.failure(ATKError.serverError(statusCode: statusCode)))
            }
        }
        task.resume()
    }

    // MARK: - 디바이스 정보 수집

    private func collectionDeviceInfo() -> [String: String] {
        [
            "os": "iOS",
            "os_version": ProcessInfo.processInfo.operatingSystemVersionString,
            "sdk_version": "1.0.0"
        ]
    }

    // MARK: - SDK 에러 정의

    enum ATKError: Error {
        case serializationFailed // JSON 변환 실패
        case invalidResponse // 서버 응답 형식 이상함
        case serverError(statusCode: Int)
    }
}

/// ─────────────────────────────────────────
/// 서버에 실제로 전송되는 JSON 예시:
///
/// {
///   "app_key": "demo-app-key-123",
///   "sent_at": "2026-02-20T10:30:45Z",
///   "events" : [
///    {
///      "id": "A1B2C3D4-...",
///      "name": "purchase",
///      "timestamp": "2026-02-20T10:30:40Z",
///      "session_id": "F1E2D3C4-...",
///      "properties": {
///       "price": "29900",
///       "product_id": "SKU-001"
///    },
///    {
///      "id": "A1B2C3D4-...",
///      "name": "purchase",
///      "timestamp": "2026-02-20T10:30:40Z",
///      "session_id": "F1E2D3C4-...",
///      "properties": {
///       "price": "29900",
///       "product_id": "SKU-001"
///    }
///   ],
///   "device": {
///     "os: "iOS",
///     "os_version": "Version 18.3 (Build 22D60)",
///     "sdk_version": "1.0.0"
///   }
/// }
/// ─────────────────────────────────────────
