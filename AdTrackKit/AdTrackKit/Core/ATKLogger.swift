//
//  ATKLogger.swift
//  AdTrackKit
//
//  Created by kingj on 2/16/26.
//

/// **필요한 이유**
/// -> SDK가 내부에서 뭘 하는지 개발자가 볼 수 있게 로그를 출력하는 도구
/// -> 프로덕션에서는 끄고, 개발 중에만 켤 수 있어야 함

// Foundation: Swift의 기본 프레임워크. String, Date, URL 등 기본 타입 제공.
import Foundation

// MARK: - 로그 레벨 정의

// SDK의 모든 타입/함수 중 외부에서 쓸 수 있게 할 것만 public으로 표시
// public이 없으면 -> Framework 내부에만 접근 가능 (internal이 기본값)
public enum ATKLogLevel: Int {
    case none = 0     // 로그 끔 (프로덕션 용)
    case error = 1    // 에러만 (심각한 문제)
    case warning = 2  // 경고 (잠재적 문제)
    case info = 3     // 정보 (주요 동작 알림)
    case debug = 4    // 디버그 (모든 것 출력, 개발용)
}

// MARK: - 로거

// Logger은 유틸리티 클래스라서 상속할 이유가 없음 (ATKLogger는 SDK 내부에서만 쓰는 유틸리티)
// final을 붙이면 컴파일러가 최적화를 더 잘함 (성능 약간 향상) ⭐️
final class ATKLogger {
    static var logLevel: ATKLogLevel = .none

    // 각 로그 레벨별 출력 함수
    static func error(_ message: String) {
        guard logLevel.rawValue >= ATKLogLevel.error.rawValue else { return }
        print("❌ [ATK:ERROR] \(message)")
    }

    static func warning(_ message: String) {
        guard logLevel.rawValue >= ATKLogLevel.warning.rawValue else { return }
        print("⚠️ [ ATK:WARN] \(message)")
    }

    static func info(_ message: String) {
        guard logLevel.rawValue >= ATKLogLevel.info.rawValue else { return }
        print("ℹ️ [ATK:INFO] \(message)")
    }

    static func debug(_ message: String) {
        guard logLevel.rawValue >= ATKLogLevel.debug.rawValue else { return }
        print("🔍 [ATK:DEBUG] \(message)")
    }
}
