# ``AdTrackKit``

광고 및 사용자 행동 이벤트를 수집·배치 전송하는 경량 iOS 트래킹 SDK.

## Overview

AdTrackKit은 앱 내 사용자 행동(화면 조회, 장바구니 담기, 결제 완료 등)을
구조화된 이벤트로 수집하고, 서버로 효율적으로 전송하기 위해 설계된 iOS SDK입니다.

단 세 가지 공개 API — ``ATKTracker/initialize(with:)``, ``ATKTracker/logEvent(_:properties:)``,
``ATKTracker/flush()`` — 만 알면 즉시 사용할 수 있으며, 복잡한 내부 로직은
모두 SDK 내부에 캡슐화되어 있습니다.

### 아키텍처

```
외부 개발자 인터페이스
        │
        ▼
  ATKTracker (Facade)         ← 단일 진입점, Singleton
        │
   ┌────┴─────────────────┐
   │                       │
ATKEventStore         ATKBatchUploader
(이벤트 큐)           (주기적 배치 전송)
   │                       │
   └───────────────────────┤
                           │
                    ATKNetworkClient
                    (URLSession HTTP POST)
```

- **Facade 패턴**: ``ATKTracker``가 내부 서브시스템을 숨기고 단순한 API만 노출합니다.
- **Builder 패턴**: ``ATKConfiguration/Builder``로 설정값을 체이닝 방식으로 구성합니다.
- **배치 전송**: 이벤트를 즉시 보내지 않고 큐에 모아 설정된 크기·주기 기준으로 일괄 전송합니다.
- **지수 백오프**: 전송 실패 시 1초 → 2초 → 4초 간격으로 최대 `maxRetryCount`회 재시도합니다.
- **영속성**: 미전송 이벤트는 `UserDefaults`에 저장되어 앱 재시작 후에도 전송됩니다.

### 빠른 시작

**1단계: SDK 초기화**

`AppDelegate`의 `application(_:didFinishLaunchingWithOptions:)` 에서 1회 호출합니다.
``ATKConfiguration/Builder`` 로 설정을 구성하고 ``ATKTracker/initialize(with:)`` 에 전달합니다.

```swift
import AdTrackKit

func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    let config = ATKConfiguration.builder(appKey: "your-app-key")
        .setEnvironment(.development)
        .setLogLevel(.debug)
        .setBatchSize(10)
        .setBatchInterval(30.0)
        .build()

    ATKTracker.shared.initialize(with: config)
    return true
}
```

**2단계: 이벤트 기록**

앱의 어느 위치에서든 ``ATKTracker/shared`` 를 통해 이벤트를 기록합니다.

```swift
// 속성 없이 기록
ATKTracker.shared.logEvent("session_start")

// 속성과 함께 기록
ATKTracker.shared.logEvent("add_to_cart", properties: [
    "product_id":   "P001",
    "product_name": "프리미엄 무선 이어폰",
    "price":        "89000",
    "category":     "electronics",
])

// 결제 완료
ATKTracker.shared.logEvent("purchase", properties: [
    "order_id":   "ORD20260226001",
    "price":      "89000",
    "payment_pg": "inicis",
])
```

**3단계: 즉시 전송**

앱이 백그라운드로 전환되거나 종료되기 직전에 `flush()`를 호출해
큐에 남아 있는 이벤트를 즉시 서버로 전송합니다.

```swift
// SceneDelegate
func sceneDidEnterBackground(_ scene: UIScene) {
    ATKTracker.shared.flush()
}

// 또는 AppDelegate
func applicationWillTerminate(_ application: UIApplication) {
    ATKTracker.shared.flush()
}
```

### 배치 전송 동작 방식

``ATKConfiguration/Builder/setBatchSize(_:)`` 와 ``ATKConfiguration/Builder/setBatchInterval(_:)`` 의
**두 조건 중 하나라도 충족**되면 배치가 자동으로 전송됩니다.

| 조건 | 설명 |
|------|------|
| 크기 기준 | 큐에 `batchSize` 개 이상 쌓이면 전송 |
| 시간 기준 | `batchInterval` 초마다 큐를 확인하여 전송 |

전송 실패 시 재시도 간격(지수 백오프):

| 재시도 횟수 | 대기 시간 |
|------------|---------|
| 1회        | 1초     |
| 2회        | 2초     |
| 3회        | 4초     |
| `maxRetryCount` 초과 | 다음 배치 주기에 재시도 |

### 서버 전송 페이로드 구조

``ATKTracker/logEvent(_:properties:)`` 로 기록된 이벤트는 아래 JSON 형태로 서버에 전송됩니다.

```json
{
  "app_key": "your-app-key",
  "sent_at": "2026-02-26T10:30:45Z",
  "events": [
    {
      "id":         "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
      "name":       "purchase",
      "timestamp":  "2026-02-26T10:30:40Z",
      "session_id": "F1E2D3C4-B5A6-...",
      "properties": {
        "order_id": "ORD20260226001",
        "price":    "89000"
      }
    }
  ],
  "device": {
    "os":          "iOS",
    "os_version":  "Version 18.3 (Build 22D60)",
    "sdk_version": "1.0.0"
  }
}
```

### 방어적 코딩 보장

SDK는 잘못된 사용에도 크래시가 발생하지 않도록 설계되어 있습니다.

| 상황 | 동작 |
|------|------|
| ``ATKTracker/initialize(with:)`` 를 2회 이상 호출 | 두 번째 호출을 무시하고 경고 로그 출력 |
| ``ATKTracker/initialize(with:)`` 호출 전에 ``ATKTracker/logEvent(_:properties:)`` 호출 | 이벤트를 무시하고 에러 로그 출력 |
| ``ATKConfiguration/Builder/build()`` 에 빈 `appKey` 전달 | `precondition` 으로 개발 단계에서 즉시 인지 |

### 크로스플랫폼 지원

AdTrackKit은 네이티브 iOS 외에도 React Native와 Flutter 환경에서 브릿지를 통해 사용할 수 있습니다.

| 환경 | 브릿지 방식 | 위치 |
|------|------------|------|
| iOS Native | `ATKTracker.shared` 직접 호출 | 이 SDK |
| React Native | `RCT_EXPORT_MODULE` / `RCT_EXPORT_METHOD` (ObjC/Swift) | `AdTrackKit-RN/` |
| Flutter | `FlutterMethodChannel` + `FlutterPlugin` (Swift) | `AdTrackKit-Flutter/` |

## Topics

### 핵심 트래커

SDK의 유일한 진입점입니다. 앱 전체에서 ``ATKTracker/shared`` 싱글턴을 통해 접근합니다.

- ``ATKTracker``

### 초기화 설정

SDK 초기화에 필요한 설정 객체입니다. 반드시 ``ATKConfiguration/Builder`` 를 통해 생성합니다.

- ``ATKConfiguration``
- ``ATKConfiguration/Builder``

### 열거형

SDK 동작 방식을 제어하는 열거형 타입입니다.

- ``ATKEnvironment``
- ``ATKLogLevel``
