# AdTrackKit iOS SDK

광고 및 사용자 행동 이벤트를 수집·전송하는 **iOS 전용 트래킹 SDK**입니다.

Builder 패턴 초기화, 배치 전송, 지수 백오프 재시도를 내장하며,
**React Native**와 **Flutter** 브릿지를 통해 크로스플랫폼 환경에서도 사용할 수 있습니다.

---

## 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│                    외부 개발자 인터페이스                      │
│                                                             │
│   iOS Native     React Native        Flutter                │
│   ATKTracker     NativeModules       MethodChannel          │
│   .shared        .AdTrackKit         .invokeMethod()        │
└────────────┬─────────────┬───────────────┬──────────────────┘
             │             │               │
             └─────────────▼───────────────┘
                     ATKTracker.shared
                           │
          ┌────────────────┼────────────────┐
          │                │                │
     ATKConfiguration  ATKEventStore   ATKBatchUploader
     (Builder 패턴)    (이벤트 큐)     (주기적 배치 전송)
                                            │
                                     ATKNetworkClient
                                     (URLSession HTTP POST)
```

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **이벤트 수집** | `logEvent(_:properties:)` 로 커스텀 이벤트 기록 |
| **배치 전송** | 설정한 개수/시간 기준으로 자동 배치 전송 |
| **지수 백오프 재시도** | 전송 실패 시 1s → 2s → 4s 대기 후 재시도 |
| **세션 자동 관리** | SDK 초기화 시 세션 시작 이벤트 자동 기록 |
| **즉시 전송** | `flush()` 로 앱 종료 전 즉시 업로드 |

---

## 설치

### Swift Package Manager

```swift
// Package.swift
.package(url: "https://github.com/yourname/AdTrackKit", from: "1.0.0")
```

### CocoaPods

```ruby
pod 'AdTrackKit', :path => '../AdTrackKit'
```

### 직접 추가 (Xcode)

Xcode → **Build Phases** → **Link Binary With Libraries** → `AdTrackKit.framework`

---

## 사용법

### 1. 초기화 (AppDelegate)

```swift
import AdTrackKit

func application(_ application: UIApplication,
                 didFinishLaunchingWithOptions ...) -> Bool {
    let config = ATKConfiguration.builder(appKey: "your-app-key")
        .setEnvironment(.development)   // .development | .production
        .setLogLevel(.debug)            // .debug | .info | .none
        .setBatchSize(10)               // 이벤트 10개마다 전송
        .setBatchInterval(30.0)         // 30초마다 전송 시도
        .build()

    ATKTracker.shared.initialize(with: config)
    return true
}
```

### 2. 이벤트 기록

```swift
// 기본
ATKTracker.shared.logEvent("screen_view")

// 속성 포함
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

### 3. 즉시 전송 (SceneDelegate)

```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    ATKTracker.shared.flush()
}
```

---

## 공개 API

### ATKTracker

| 메서드 | 설명 |
|--------|------|
| `initialize(with config: ATKConfiguration)` | SDK 초기화 (1회 호출) |
| `logEvent(_ name: String, properties: [String: String]?)` | 이벤트 기록 |
| `flush()` | 미전송 이벤트 즉시 전송 |

### ATKConfiguration.Builder

| 메서드 | 기본값 | 설명 |
|--------|--------|------|
| `setEnvironment(_ env: ATKEnvironment)` | `.production` | 실행 환경 설정 |
| `setLogLevel(_ level: ATKLogLevel)` | `.none` | 로그 출력 레벨 |
| `setBatchSize(_ size: Int)` | `10` | 배치 전송 임계값 |
| `setBatchInterval(_ interval: TimeInterval)` | `30.0` | 배치 전송 주기(초) |
| `setMaxRetryCount(_ count: Int)` | `3` | 최대 재시도 횟수 |

---

## 크로스플랫폼 브릿지

AdTrackKit은 React Native와 Flutter에서도 사용할 수 있습니다.

### React Native 브릿지 → `AdTrackKit-RN/`

`RCT_EXPORT_MODULE` / `RCT_EXPORT_METHOD` 매크로 기반 ObjC/Swift 브릿지

```javascript
import { NativeModules } from 'react-native';
const { AdTrackKit } = NativeModules;

await AdTrackKit.logEvent('add_to_cart', { product_id: 'P001', price: '89000' });
```

### Flutter 플러그인 → `AdTrackKit-Flutter/`

`FlutterMethodChannel` 기반 Dart/Swift 플러그인

```dart
import 'package:adtrackkit_flutter/adtrackkit_flutter.dart';

await AdTrackKit.logEvent('add_to_cart', properties: {
  'product_id': 'P001',
  'price': '89000',
});
```

---

## 프로젝트 구조

```
AdTrackKit/
└── AdTrackKit/
    ├── Core/
    │   ├── ATKTracker.swift        싱글턴 Facade (공개 API 진입점)
    │   ├── ATKConfiguration.swift  Builder 패턴 설정 객체
    │   └── ATKLogger.swift         내부 로거
    ├── Event/
    │   ├── ATKEvent.swift          이벤트 데이터 모델
    │   └── ATKEventStore.swift     인메모리 이벤트 큐
    └── Network/
        ├── ATKNetworkClient.swift  URLSession HTTP POST 클라이언트
        └── ATKBatchUploader.swift  배치 전송 + 지수 백오프 재시도
```

---

## 설계 원칙

- **Facade 패턴**: `ATKTracker`가 모든 내부 복잡성을 숨기고 단순한 API만 노출
- **Builder 패턴**: `ATKConfiguration.Builder`로 설정 유연성 + 유효성 검사
- **방어적 코딩**: 초기화 전 호출, 중복 초기화 → 크래시 없이 경고 로그 처리

---

## 지원 환경

| 항목    | 버전   |
|---------|--------|
| iOS     | 15.0+  |
| Swift   | 5.9+   |
| Xcode   | 15+    |
