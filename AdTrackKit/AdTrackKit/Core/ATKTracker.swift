//
//  ATKTracker.swift
//  AdTrackKit

/// **필요한 이유**
/// -> SDK를 사용하는 외부 개발자가 접하는 "유일한 창구"
/// -> 복잡한 내부 구조(EventStore, BatchUploader 등)을 숨기고,
///    간단한 API만 제공 (Facade 패턴)
/// 메인 진입점! ⭐️

/// **외부 개발자가 쓰는 코드:**
///   ATKTracker.shared.initialized(with config:)
///   ATKTracker.shared.logEvent("purchase")
///   ATKTracker.shared.flush()

import Foundation

// MARK: - 메인 트래커 (Singleton)

public final class ATKTracker {

    // MARK: - Singleton 인스턴스

    public static let shared = ATKTracker()

    private init() { }

    // MARK: - 내부 상태

    // initialize() 전에는 설정이 없으니까
    private var configuration: ATKConfiguration?
    private var isInitialized = false
    private var sessionId: String = UUID().uuidString

    private let eventStore = ATKEventStore()

    private var networkClient: ATKNetworkClient?
    private var batchUploader: ATKBatchUploader?

    // MARK: - Public API

    // SDK 초기화 - 앱 시작시 반드시 1번 호출
    // 사용자 입력: config
    public func initialize(with config: ATKConfiguration) {

        guard !isInitialized else {
            ATKLogger.error("AdTrackerKit이 이미 초기화 되었습니다. 중복 호출을 무시합니다.")
            return
        }

        // 설정 저장
        self.configuration = config
        self.isInitialized = true
        self.sessionId = UUID().uuidString

        // 로거 레벨 설정
        ATKLogger.logLevel = config.logLevel

        // 네트워크 클라이언트 생성
        let client = ATKNetworkClient()
        self.networkClient = client

        // 배치 업로더 생성 및 시작
        let uploader = ATKBatchUploader(
            eventStore: eventStore,
            networkClient: client,
            configuration: config
        )
        self.batchUploader = uploader
        uploader.start()
        // 타이머가 시작되어 batchInterval초마다 자동 전송

        ATKLogger.info("AdTrackKit 초기화 완료 (appKey: \(config.appKey), env: \(config.environment))")
        ATKLogger.info("배치 설정 - 크기: \(config.batchSize), 간격: \(config.batchInterval)")

        // 세션 시작 이벤트 자동 기록
        //. -> SDK가 초기화되면 자동으로 "앱이 시작됐다"는 이벤트를 기록
        //. -> 외부 개발자가 수동으로 안 해도 됨
        logEvent("session_start")
    }

    // 이벤트 기록 - 외부 개발자가 가장 많이 호출하는 메서드
    public func logEvent(
        _ name: String,
        properties: [String: String]? = nil
    ) {
        // 초기화 체크
        guard isInitialized else {
            ATKLogger.error("SDK가 초기화되지 않았습니다. initialize()를 먼저 호출하세요.")
            return
        }

        // 이벤트 생성
        let event = ATKEvent(
            name: name,
            properties: properties,
            sessionId: sessionId
        )

        // 저장소에 저장
        eventStore.append(event)

        ATKLogger.debug("이벤트 기록: \(name) (대기중: \(eventStore.pendingCount)개)")
    }

    // 즉시 전송 - 앱이 백그라운드로 갈 때 호출
    public func flush() {
        guard isInitialized else {
            ATKLogger.error("SDK가 초기화 되지 않았습니다.")
            return
        }

        ATKLogger.info("flush() 호출 - 미전송 이벤트 즉시 전송 시도")
        batchUploader?.uploadImmediately()
    }
}

/// ─────────────────────────────────────────
/// 이 파일의 핵심 설계 원칙:
///
///  1. Singleton: 앱 전체에서 하나만 존재
///  2. Facade: 복잡한 내부를 숨기고 간단한 API만 호출
///    - initialize(with:) -> 초기화
///    - logEvent(_:properties:) -> 이벤트 기록
///    - flush() -> 즉시 전송
///  3. 방어적 코딩: 잘못된 사용에도 크래시 안남
///    - 중복 초기화 -> 무시 + 경고 로그
///    - 초기화 전 이벤트 기록 -> 무시 + 에러 로그
///    - Optional + guard 로 안전하게 처리
/// ─────────────────────────────────────────
