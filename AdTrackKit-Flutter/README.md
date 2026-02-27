# adtrackkit_flutter

AdTrackKit iOS SDK를 Flutter에서 사용하기 위한 **Flutter Plugin** 패키지입니다.

`FlutterMethodChannel`을 통해 Dart ↔ Swift가 통신하며,
`handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)` 델리게이트가
Dart의 모든 호출을 수신합니다.

---

## 통신 흐름

```
┌────────────────────────────────────────────────────┐
│  Dart (Flutter)                                    │
│  AdTrackKit.logEvent('add_to_cart', {...})         │
│    ↓ _channel.invokeMethod('logEvent', {...})      │
└──────────────────────┬─────────────────────────────┘
                       │ MethodChannel
                       │ 'adtrackkit_flutter'
┌──────────────────────▼─────────────────────────────┐
│  Swift (iOS)                                       │
│  AdTrackKitFlutterPlugin                           │
│    func handle(_ call:FlutterMethodCall,           │
│                result: @escaping FlutterResult)    │
│      ↓                                             │
│  ATKTracker.shared.logEvent(...)                   │
│      ↓                                             │
│  result(nil)  →  Dart Future<void> 완료            │
└────────────────────────────────────────────────────┘
```

---

## 파일 구조

```
adtrackkit_flutter/
├── lib/
│   └── adtrackkit_flutter.dart         Dart 공개 API (MethodChannel 래퍼)
├── ios/
│   └── Classes/
│       └── AdTrackKitFlutterPlugin.swift  FlutterPlugin + handle() 구현
├── example/
│   └── lib/main.dart                   예제 앱 (장바구니 담기 데모)
├── adtrackkit_flutter.podspec          CocoaPods 스펙
└── pubspec.yaml
```

---

## 설치

### 1. pubspec.yaml에 의존성 추가

```yaml
# pubspec.yaml
dependencies:
  adtrackkit_flutter:
    path: ../AdTrackKit-Flutter   # 로컬 경로
    # 배포 후: adtrackkit_flutter: ^0.1.0
```

### 2. iOS 설정

```bash
cd ios && pod install
```

### 3. AdTrackKit.framework 연결

Xcode → **Build Phases** → **Link Binary With Libraries**
→ `AdTrackKit.framework` 추가

---

## 사용법

### 초기화 (앱 시작 시 1회)

```dart
import 'package:adtrackkit_flutter/adtrackkit_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AdTrackKit.initialize(
    appKey: 'your-app-key',
    environment: 'development',   // 'production' | 'development'
  );

  runApp(const MyApp());
}
```

### 이벤트 기록

```dart
// 장바구니 담기
await AdTrackKit.logEvent('add_to_cart', properties: {
  'product_id':   'P001',
  'product_name': '프리미엄 무선 이어폰',
  'price':        '89000',
  'category':     'electronics',
});

// 화면 조회 (properties 생략 가능)
await AdTrackKit.logEvent('screen_view', properties: {'screen_name': 'Home'});

// 결제 완료
await AdTrackKit.logEvent('purchase', properties: {
  'order_id':   'ORD20260226001',
  'price':      '89000',
  'payment_pg': 'inicis',
});
```

### 즉시 전송

```dart
// AppLifecycleState.inactive 감지 시 호출 권장
await AdTrackKit.flush();
```

### 앱 생명주기 연동

```dart
class _MyState extends State<MyWidget> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      AdTrackKit.flush();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
```

### 에러 처리

```dart
import 'package:flutter/services.dart';

try {
  await AdTrackKit.logEvent('add_to_cart', properties: {...});
} on PlatformException catch (e) {
  // FlutterError(code:message:) → PlatformException(code:message:)
  print('Error: ${e.code} - ${e.message}');
}
```

---

## 주요 이벤트 이름 가이드

| 이벤트        | 설명          | 권장 properties                           |
|--------------|--------------|-------------------------------------------|
| `screen_view`  | 화면 조회    | `screen_name`                             |
| `view_item`    | 상품 상세    | `product_id`, `product_name`, `price`     |
| `add_to_cart`  | 장바구니     | `product_id`, `price`, `category`         |
| `begin_checkout` | 결제 시작  | `product_id`, `price`                     |
| `purchase`     | 결제 완료    | `order_id`, `price`, `payment_pg`         |
| `login`        | 로그인       | `method` (kakao / apple / email)          |

---

## 지원 환경

| 항목           | 버전        |
|----------------|-------------|
| iOS            | 15.0+       |
| Flutter        | 3.10+       |
| Dart           | 3.0+        |
| Swift          | 5.9+        |
| Android        | ❌ 미지원   |
