//
//  ATKConfiguration.swift
//  AdTrackKit

/// **필요한 이유**
/// SDK를 초기화할 때 여러 설정값을 넘겨야 함
/// 설정값이 많으면 함수 파라미터가 너무 길어짐:
/// Builder 패턴으로 해결: 체이닝 방식으로 설정
///
/// ─────────────────────────────────────────
/// 사용 예시 (데모 앱에서: AppDelegate 에서):
///
/// let config = ATKConfiguration.builder(appKey: "my-app-123")
///       .setEnvironment(.development)
///       .setLogLevel(.debug)
///       .setBatchSize(5)
///       .setBatchInterval(10.0)
///       .build()
///
///  --> 이 config 객체를 SDK 초기화에 전달
///  ─────────────────────────────────────────

import Foundation

// MARK: - 환경 설정

public enum ATKEnvironment {
    case development  // 개발 환경 (테스트 서버 사용)
    case production   // 운영 환경 (실제 서버 사용)
}

// MARK: - Configuration (설정 객체)

// 이 클래스는 한번 만들어지면 값이 바뀌면 안 됨
// -> 그래서 모든 프로퍼티가 let
// -> 초기화 이후 변경 불가

public final class ATKConfiguration {

    // MARK: Public 프로퍼티 (읽기 전용)

    public let appKey: String
    public let environment: ATKEnvironment
    public let logLevel: ATKLogLevel
    public let batchSize: Int
    public let batchInterval: TimeInterval
    // TimeInterval = Double의 타입 별칭 (단위: 초)
    // 10.0 =. 0초
    public let maxRetryCount: Int

    // MARK: Private 초기화

    // 외부에서 ATKConfiguration()으로 직접 생성 못하게 막음
    // 반드시 Builder를 통해서만 생성하도록 강제
    // 왜? Builder에서 유효성 검사 (appKey가 비어있는지 등)를 하니까
    private init(builder: Builder) {
        self.appKey = builder.appKey
        self.environment = builder.environment
        self.logLevel = builder.logLevel
        self.batchSize = builder.batchSize
        self.batchInterval = builder.batchInterval
        self.maxRetryCount = builder.maxRetryCount
    }

    // MARK: Builder 진입점

    // ATKConfiguration.builder(appKey:)로 호출 (= 여기서 appKey로 객체 생성)
    // appKey를 필수 파라미터로 받는 이유:
    //  appKey 없이는 SDK가 동작할 수 없으니까
    //  나머지는 선택적 (기본값이 있음)
    public static func builder(appKey: String) -> Builder {
        Builder(appKey: appKey)
    }

    // MARK: - Builder 클래스

    // Builder가 Configuration 안에 중첩된 이유:
    // ATKConfiguration.Builder 로 접근 - 소속이 명확
    // Builder가 Configuration의 private init에 접근 가능
    public final class Builder {

        // Configuration의 init에서 builder.appKey로 읽을 수 있지만
        //  다른 파일에서는 접근 불가
        //  appKey 이외 값들은, 기본값이 있기 땜에 -> 개발자가 설정 안하면 이 값이 쓰임
        fileprivate let appKey: String
        fileprivate var environment: ATKEnvironment = .production
        fileprivate var logLevel: ATKLogLevel = .none
        fileprivate var batchSize: Int = 10
        fileprivate var batchInterval: TimeInterval = 10.0
        fileprivate var maxRetryCount: Int = 3

        fileprivate init(appKey: String) {
            self.appKey = appKey
        }

        // MARK: 체이닝 메서드들

        // @discardableResult: 반환값을 안 써도 경고가 안 뜨게 함
        //  -> Builder를 반환하지만, 마지막 호출에서는 안 쓸 수도 있으니까
        @discardableResult
        public func setEnvironment(_ env: ATKEnvironment) -> Builder {
            self.environment = env
            return self
        }

        @discardableResult
        public func setLogLevel(_ level: ATKLogLevel) -> Builder {
            self.logLevel = level
            return self
        }

        @discardableResult
        public func setBatchSize(_ size: Int) -> Builder {
            // 방어적 코딩: 터무니없는 값 방지
            // max(1, ...): 최소 1개
            // min(..., 10): 최대 100개
            self.batchSize = max(1, min(size, 100))
            return self
        }

        @discardableResult
        public func setBatchInterval(_ interval: TimeInterval) -> Builder {
            // 최소 1초 - 1초 미만으로 전송하면 서버에 부담
            self.batchInterval = max(1.0, interval)
            return self
        }

        @discardableResult
        public func setMaxRetryCount(_ count: Int) -> Builder {
            self.maxRetryCount = max(0, min(count, 10))
            return self
        }

        // build(): Builder --> Configuration 변환 (최종 객체 생성)
        public func build() -> ATKConfiguration {
            // precondition: 조건이 false면 앱이 크래시남
            //  -> appKey가 빈 문자열이면 SDK가 동작할 수 없으니, 개발 단계에서 잡음 (SDK 연동하는 개발자를 위함)
            // - assert: 개발 중에만 잡으면 되는 가벼운 검증에 씀 (Debug에만 동작, Release에서 무시)
            // - precondition: 이게 틀리면 앱 아예 동작 안되는 치명적인 조건에 씀 (Debug에도 동작, Release에도 동작)
            precondition(!appKey.isEmpty, "[AdTrackKit] appKey는 필수입니다")
            return ATKConfiguration(builder: self)
        }
    }
}
