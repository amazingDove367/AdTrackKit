//
//  ATKBatchUploader.swift
//  AdTrackKit
//
//  Created by kingj on 2/16/26.
//

/// **필요한 이유**
///   --> 언제, 얼마나 모아서, 어떻게 보낼지를 관리
///   --> Timer로 주기적 체크 + 배치 전송 + 실패시 재시도

import Foundation

final class ATKBatchUploader {

    // MARK: - 의존성

    // 이벤트 저장 창고
    private let eventStore: ATKEventStore

    // 실제로 서버에 보내주는 우체부
    private let networkClient: ATKNetworkClient

    // batchSize, batchInterval, maxRetryCount 등 설정값
    private let configuration: ATKConfiguration

    // MARK: - 내부 상태

    // 초기화 시점에 타이머 없고, start()할 때 만듦, 타이머 멈출때 nil로 설정
    private var timer: Timer?

    // 현재 재시도 횟수 (실패할 때마다 +1, 성공하면 0으로 리셋)
    private var retryCount: Int = 0

    // 현재 전송 중인지 플래그
    // -> true; 타이머가 울려도 전송 시작하지 않음 (중복 전송 방지)
    private var isUploading: Bool = false

    // MARK: - 초기화

    init(
        eventStore: ATKEventStore,
        networkClient: ATKNetworkClient,
        configuration: ATKConfiguration,
    ) {
        self.eventStore = eventStore
        self.networkClient = networkClient
        self.configuration = configuration
    }

    // MARK: 타이머 시작/중지

    /// SDK 초기화 시 호출 - 주기적 배치 전송 시작
    func start() {
        // 기존 타이머 중지
        stop()

        ATKLogger.debug("배치 업로더 시작 (간격: \(configuration.batchInterval)초)")

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.timer = Timer.scheduledTimer(
                withTimeInterval: self.configuration.batchInterval,
                repeats: true,
                block: { [weak self] _ in
                    ATKLogger.debug("⏳ 타이머 \(self?.configuration.batchInterval) 경과 ⏳")
                    // Timer 객체가 넘어오지만, 안쓸예정이라서 _ 처리
                    self?.uploadIfNeeded() // 타이머 울릴때마다 보낼게 있는지 확인
                })
        }
    }

    /// SDK 종료 시 호출 - 타이머 중지
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// flush() 호출 시 - 타이머 기다리지 않고 즉시 전송
    func uploadImmediately() {
        ATKLogger.debug("즉시 전송 요청")
        uploadIfNeeded()
    }

    // MARK: - 핵심 로직: 배치 전송

    func uploadIfNeeded() {
        // 이미 전송 중이면 건너뜀
        guard !isUploading else {
            ATKLogger.debug("이전 전송이 아직 진행 중 - 건너뜀")
            return
        }

        // 보낼 이벤트 없으면 건너뜀
        guard eventStore.pendingCount > 0 else {
            ATKLogger.debug("X 보낼 이벤트 없음 X")
            return
        }

        // 배치 꺼내기
        let batch: [ATKEvent] = eventStore.dequeue(count: configuration.batchSize)

        guard !batch.isEmpty else { return }

        isUploading = true

        ATKLogger.info("배치 전송 시작: \(batch.count)개")

        // 서버 전송
        networkClient.sendEvents(batch, appKey: configuration.appKey) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success:
                let eventIds = Set(batch.map { $0.id })
                self.eventStore.remove(eventIds: eventIds)
                self.retryCount = 0
                self.isUploading = false

                ATKLogger.info("(배치 전송) 배치 전송 성공: \(batch.count)개 (남은 대기: \(self.eventStore.pendingCount)개)")

                // 아직 대기 중인 이벤트가 있으면 바로 다음 배치 전송
                // batchSize는 한번에 보내는 최대 개수! 5개이면 5개 모일때까지 기다리는거 X
                if self.eventStore.pendingCount > 0 {
                    self.uploadIfNeeded()
                }

            case .failure(let error):
                self.isUploading = false
                self.retryCount += 1

                if self.retryCount <= self.configuration.maxRetryCount {
                    // 재시도 (지수 백오프)
                    // pow(2.0, n): 2의 n제곱
                    // retryCount 1 -> 2^0 = 1초
                    // retryCount 2 -> 2^1 = 2초
                    // retryCount 3 -> 2^2 = 4초
                    // retryCount 4 -> 2^3 = 8초
                    let delay = pow(2.0, Double(self.retryCount - 1))

                    ATKLogger.warning("전송 실패 (\(self.retryCount)/\(self.configuration.maxRetryCount)) - \(delay)초 후 재시도: \(error.localizedDescription)")

                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                        self?.uploadIfNeeded()
                    }
                } else {
                    // 최대 재시도 횟수 초과 -> 포기
                    ATKLogger.error("전송 실패: 최대 재시도 횟수(\(self.configuration.maxRetryCount) 초과. 다음 주기에 다시 시도합니다.")
                    self.retryCount = 0
                }
            }
        }
    }

    // MARK: - 메모리 해제 시 타이머 정리

    deinit {
        // 타이머가 살아있으면 메모리 누수가 생길 수 있으니 정리
        stop()
    }
}

/// ─────────────────────────────────────────
/// 동작 흐름 정리:
///
/// start() -> 타이머 시작 (10초마다 uploadIfNeeded 호출)
///
/// uploadIfNeeded():
///  isUploading? -> yes -> 건너뜀
///  pendingCount? -> 0 ->  건너뜀
///  -> batch 꺼냄 (최대 batchSize개)
///  -> networkClient.sendEvents() 호출
///    -> 성공: 큐에서 삭제, retryCount 리셋, 남은거 있으면 또 전송 (?????)
///    -> 실패: retryCount < max ? -> 지수 백오프 후 재 시도
///                          -> 아니면 포기 (다음 주기에 다시)
///
/// flush() -> uploadImmediatly() -> 타이머 안 가리고 바로 uploadIfNeeded()
