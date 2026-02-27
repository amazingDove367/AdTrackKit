//
//  ATKEventStore.swift
//  AdTrackKit

/// **필요한 이유**
///   --> 이벤트를 즉시 서버에 안 보내고 "잠깐 모아두는 창고"
///   --> 배치 전송을 위해 이벤트를 큐에 저장
///   --> 앱이 꺼져도 이벤트가 사라지지 않게 영구 저장

import Foundation

final class ATKEventStore {

    // MARK: - DispatchQueue (스레드 안전성)

    // 여러 곳에서 동시에 events 배열에 접근하면 충돌이 남
    // 예: 배치 업로더가 읽는 동안 새 이벤트가 추가되면 -> 크래시!
    // DispatchQueue를 만들어서 "한 번에 하나씩만" 접근하게 강제
    //
    // label: 디버깅 시, 이 큐를 식별하기 위한 이름
    private let queue = DispatchQueue(label: "com.adtrackkit.eventstore")

    // MARK: - 이벤트 저장 배열

    // 메모리에 있는 이벤트 목록
    private var events: [ATKEvent] = []

    // MARK: - UserDefaults 키

    // UserDefaults에 저장할 때 사용하는 키 문자열
    // 겹치지 않도록 SDK 이름을 포함시킴
    private let storageKey = "com.adtrackkit.pending_events"

    // MARK: - 초기화
    init() {
        loadPersistedEvents()
    }

    // MARK: - 영구 저장

    // UserDefaults에서 이벤트 복구 (앱 재시작 시)
    private func loadPersistedEvents() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        guard let savedEvents = try? JSONDecoder().decode([ATKEvent].self, from: data) else {
            ATKLogger.error("이벤트 복구 실패: 디코딩 에러")
            return
        }
        // [ATKEvent].self: "ATKEvent 배열 타입"이라고 Decoder에게 알려줌

        events = savedEvents
        ATKLogger.info("미전송 이벤트 \(savedEvents.count)개 복구됨")
    }

    private func persistEvents() {

        // JSONEncoder: Swift 객체 -> Json data 변환
        // ATKEvent가 Codable이니까 자동으로 변환됨
        guard let data = try? JSONEncoder().encode(events) else {
            ATKLogger.error("이벤트 저장 실패: 인코딩 에러")
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Public 메서드들

    // 이벤트를 큐에 추가
    func append(_ event: ATKEvent) {

        // queue.async: 이 블록을 queue에 넣어서 순서대로 실행
        // async: 비동기 - 호출한 쪽은 기다리지 않고 바로 다음 줄 실행
        // [weak self]: 메모리 누수 방지
        queue.async { [weak self] in
            guard let self else { return }
            self.events.append(event) // 메모리에 저장
            self.persistEvents() // UserDefaults에도 저장
        }
    }

    // 전송할 이벤트를 최대 count개 가져오기
    func dequeue(count: Int) -> [ATKEvent] {

        // queue.sync: 동기 - 결과가 나올때까지 기다림
        //  -> dequeue는 결과(이벤트 배열)를 반환해야 하니까 동기
        //. -> append는 반환값 없으니까 비동기
        queue.sync {

            // prefix(count): 배열의 앞에서부터 count개를 가져옴
            let batch = Array(events.prefix(count))
            return batch
        }
    }

    // 전송 성공한 이벤트를 큐에서 삭제
    func remove(eventIds: Set<String>) {

        // Set<String> 쓴 이유 (배열이 아니라):
        //  -> Set은 contains() 검색어 O(1)
        //. -> 배열의 contains()는 O(n)
        //  -> 삭제할 이벤트 많을 때 성능 차이 큼
        queue.async { [weak self] in
            guard let self else { return }
            self.events.removeAll { eventIds.contains($0.id) }
            self.persistEvents()
        }
    }

    // 대기 중인 이벤트 수
    var pendingCount: Int {
        queue.sync { events.count } // sync로 읽는 이유: 다른 스레드가 쓰는 중에 읽으면 안되니까
    }
}

/// ─────────────────────────────────────────
/// 동작 흐름 정리:
///
/// 이벤트 발생
///  -> append() -> events 배열에 추가 + userdefaults 저장
///
/// 배치 전송 시점
///  -> dequeue(count: 10) -> 앞에서 10개 꺼냄
///  -> 서버 전송 시도
///  -> 성공시;
///     remove(eventIds:) -> 큐에서 삭제 + userdefaults 저장
///  -> 실패시;
///     큐에 그대로 남아 있음 -> 다음에 다시 시도
///
/// 앱 종료 후 재시작
///  -> init() -> loadPersistedEvents() -> userdefaults 에서 복구
///  -> 이전에 못 보낸 이벤트가 큐에 다시 들어감
/// ─────────────────────────────────────────
