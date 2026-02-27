# 내가 만든 iOS SDK를 Flutter에서 쓰는 법 — MethodChannel 완전 분석

> **이 글에서 다루는 것**
> - Flutter Plugin 아키텍처와 MethodChannel 작동 원리
> - `handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)` 상세 분석
> - Dart ↔ Swift 타입 변환 흐름
> - AdTrackKit SDK를 Flutter에서 호출하기까지 전 과정
> - React Native 브릿지와의 비교

---

## 1. 왜 Flutter Plugin이 필요한가?

Flutter는 Dart로 iOS/Android 앱을 만들지만,
**플랫폼 고유 기능** (GPS, 카메라, 사내 SDK 등)은 Dart API로 직접 접근할 수 없습니다.

Flutter는 이를 해결하기 위해 **Platform Channel** 이라는 통신 메커니즘을 제공합니다.

```
Dart (Flutter UI)
      │
      │  Platform Channel (직렬화/역직렬화)
      │
iOS Native (Swift / ObjC)  또는  Android (Kotlin / Java)
```

Platform Channel에는 세 가지 종류가 있습니다:

| 채널 종류           | 방향            | 용도                               |
|--------------------|-----------------|-----------------------------------|
| **MethodChannel**  | 양방향 (RPC 방식) | 함수 호출, 데이터 요청 (이 글에서 사용) |
| BasicMessageChannel | 양방향 스트리밍 | 지속적 데이터 교환                 |
| EventChannel       | 단방향 (Native→Dart) | 이벤트 스트림 (GPS, 센서 등)    |

이 글에서는 **MethodChannel**을 사용해 AdTrackKit SDK를 Flutter에 연결합니다.

---

## 2. 전체 파일 구조와 역할

```
adtrackkit_flutter/
├── lib/
│   └── adtrackkit_flutter.dart      ① Dart 공개 API  ← 개발자가 사용하는 인터페이스
├── ios/
│   └── Classes/
│       └── AdTrackKitFlutterPlugin.swift  ② Swift 구현체  ← 핵심
├── adtrackkit_flutter.podspec       ③ CocoaPods 스펙
└── pubspec.yaml                     ④ Flutter 패키지 선언
```

통신 흐름:

```
① Dart: AdTrackKit.logEvent('add_to_cart', {...})
         ↓ _channel.invokeMethod('logEvent', {...})

      ──────────── MethodChannel ────────────
      채널 이름: 'adtrackkit_flutter'
      코덱: StandardMessageCodec (JSON-like 직렬화)
      ──────────────────────────────────────

② Swift: func handle(_ call: FlutterMethodCall,
                      result: @escaping FlutterResult)
           → call.method == "logEvent"
             → ATKTracker.shared.logEvent(...)
               → result(nil)  →  Dart Future 완료
```

---

## 3. ① Dart 측 — MethodChannel과 invokeMethod

```dart
// 채널 이름: Swift와 반드시 동일해야 합니다.
const MethodChannel _channel = MethodChannel('adtrackkit_flutter');

class AdTrackKit {
  // invokeMethod의 첫 번째 인자 = Swift의 call.method
  // 두 번째 인자 = Swift의 call.arguments (Map<String, dynamic>)
  static Future<void> logEvent(String name, {Map<String, String>? properties}) async {
    await _channel.invokeMethod<void>('logEvent', {
      'name': name,
      'properties': properties ?? {},
    });
  }
}
```

### invokeMethod 제네릭 타입

```dart
// void: 반환값 없음 (Swift에서 result(nil))
await _channel.invokeMethod<void>('flush');

// String: Swift에서 result("some string") 시 반환
final String? version = await _channel.invokeMethod<String>('getVersion');

// Map: Swift에서 result(["key": "value"]) 시 반환
final Map? data = await _channel.invokeMethod<Map>('getData');
```

### PlatformException 처리

```dart
// Swift에서 result(FlutterError(...)) 를 호출하면
// Dart에서 PlatformException 이 throw됩니다.
try {
  await AdTrackKit.logEvent('');   // 빈 이름 → FlutterError
} on PlatformException catch (e) {
  print('${e.code}: ${e.message}');  // INVALID_ARGUMENT: 이벤트 name은...
}
```

---

## 4. ② Swift 측 — FlutterPlugin 프로토콜과 handle()

이 파일이 Flutter 브릿지의 핵심입니다.

### FlutterPlugin 등록

```swift
@objc(AdTrackKitFlutterPlugin)
public final class AdTrackKitFlutterPlugin: NSObject, FlutterPlugin {

    // Flutter 앱 시작 시 자동 호출
    // MethodChannel을 생성하고 이 인스턴스를 델리게이트로 등록
    public static func register(with registrar: any FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "adtrackkit_flutter",    // Dart의 MethodChannel 이름과 동일
            binaryMessenger: registrar.messenger()
        )
        let instance = AdTrackKitFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
}
```

**`register(with:)` 가 자동 호출되는 이유:**
- `pubspec.yaml`의 `flutter.plugin.platforms.ios.pluginClass: AdTrackKitFlutterPlugin` 선언
- Flutter 빌드 시스템이 이를 읽고, 앱의 `GeneratedPluginRegistrant.m` 파일을 자동 생성
- 앱 시작 시 `GeneratedPluginRegistrant.registerWithRegistry(registry)` 가 호출되면
  모든 플러그인의 `register(with:)` 가 실행됨

```objc
// 자동 생성 파일: ios/Runner/GeneratedPluginRegistrant.m
// (개발자가 직접 수정하지 않음)
[AdTrackKitFlutterPlugin registerWithRegistrar:
    [registry registrarForPlugin:@"AdTrackKitFlutterPlugin"]];
```

### handle() — 모든 Dart 호출의 도착지

```swift
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize": handleInitialize(call: call, result: result)
    case "logEvent":   handleLogEvent(call: call, result: result)
    case "flush":      handleFlush(result: result)
    default:           result(FlutterMethodNotImplemented)
    }
}
```

**FlutterMethodCall 구조:**

| 프로퍼티            | 타입    | 내용                                    |
|--------------------|---------|----------------------------------------|
| `call.method`      | String  | Dart `invokeMethod` 첫 번째 인자        |
| `call.arguments`   | Any?    | Dart 두 번째 인자 (역직렬화됨)          |

**FlutterResult 응답 종류:**

```swift
result(nil)                          // Dart: Future<void> 완료 (정상)
result("hello")                      // Dart: Future<String?> == "hello"
result(["key": "value"])             // Dart: Future<Map?> == {"key": "value"}
result(FlutterError(
    code: "ERR_CODE",
    message: "에러 메시지",
    details: nil
))                                   // Dart: PlatformException throw
result(FlutterMethodNotImplemented)  // Dart: MissingPluginException throw
```

> ⚠️ **중요**: `result`는 반드시 정확히 **1번만** 호출해야 합니다.
> 2번 이상 호출하면 Flutter 엔진이 크래시합니다.

### 타입 변환 상세

```swift
private func handleLogEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
    // 1. call.arguments는 Any? → [String: Any]로 캐스팅
    guard let args = call.arguments as? [String: Any],
          let name = args["name"] as? String
    else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "...", details: nil))
        return
    }

    // 2. Dart Map<String, String> → ObjC NSDictionary → Swift [String: Any]
    //    → compactMapValues로 [String: String]으로 변환
    let rawProps = args["properties"] as? [String: Any]
    let properties: [String: String]? = rawProps?.compactMapValues { $0 as? String }

    // 3. AdTrackKit SDK 호출
    ATKTracker.shared.logEvent(name, properties: properties)

    // 4. Dart Future 완료
    result(nil)
}
```

---

## 5. 타입 변환 전체 흐름

Dart ↔ Swift 사이의 타입 변환은 `StandardMessageCodec`이 자동으로 처리합니다.

```
Dart 타입              StandardMessageCodec        Swift 타입
──────────────────────────────────────────────────────────────
String                    →     →     →              String
int                       →     →     →              Int / NSNumber
double                    →     →     →              Double / NSNumber
bool                      →     →     →              Bool
Map<String, dynamic>      →     →     →              [String: Any] (NSDictionary)
List<dynamic>             →     →     →              [Any] (NSArray)
null                      →     →     →              nil / NSNull
```

---

## 6. Flutter Plugin vs React Native Native Module 비교

같은 SDK를 두 프레임워크에 연결하며 느낀 차이점입니다.

| 항목              | Flutter (MethodChannel)              | React Native (Bridge)                  |
|------------------|--------------------------------------|----------------------------------------|
| **등록 방식**      | `FlutterPlugin.register(with:)` 자동 | `RCT_EXPORT_MODULE` 매크로             |
| **메서드 노출**    | `handle(_:result:)` switch로 분기    | `RCT_EXPORT_METHOD` 매크로별 선언      |
| **응답 방식**      | `FlutterResult` 콜백 (1회 호출)      | `Promise` (resolve/reject)             |
| **파일 구성**      | Swift 단일 파일                      | ObjC .m + Swift .swift (2파일)         |
| **자동 생성 코드** | `GeneratedPluginRegistrant.m`        | (없음, 수동 설정)                       |
| **에러 전달**      | `FlutterError` → `PlatformException` | `reject(code, message, error)` → catch  |
| **채널 이름**      | 문자열 일치 필수                     | 모듈 이름 일치 필수                     |

---

## 7. pubspec.yaml — Flutter 플러그인 선언

```yaml
flutter:
  plugin:
    platforms:
      ios:
        pluginClass: AdTrackKitFlutterPlugin
        # Swift 클래스를 직접 지정하는 최신 방식 (Flutter 3.x+)
        # swiftPluginClass: AdTrackKitFlutterPlugin
```

이 선언이 있어야 Flutter 빌드 시스템이 이 패키지를 "플러그인"으로 인식하고
`GeneratedPluginRegistrant.m`에 자동으로 등록합니다.

---

## 8. Xcode 설정 체크리스트

```
□ 1. flutter pub get
□ 2. cd ios && pod install
□ 3. AdTrackKit.framework 를 Link Binary With Libraries 에 추가
□ 4. (필요 시) Bridging Header 설정
      Build Settings → Objective-C Bridging Header
```

---

## 9. 디버깅 팁

### MissingPluginException 발생 시

```
MissingPluginException(No implementation found for method logEvent
on channel adtrackkit_flutter)
```

원인 및 해결:
- `pod install` 미실행 → `cd ios && pod install` 재실행
- MethodChannel 이름 불일치 확인
- Dart: `MethodChannel('adtrackkit_flutter')`
- Swift: `FlutterMethodChannel(name: "adtrackkit_flutter", ...)`

### Swift 로그 확인

```swift
// handle() 에 임시 로그 추가
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("[AdTrackKitPlugin] 수신: \(call.method), 인자: \(String(describing: call.arguments))")
    // ...
}
```

### result 중복 호출 방지

```swift
// ❌ 잘못된 예: guard 실패 후 return 없이 result를 또 호출
guard let name = ... else {
    result(FlutterError(...))
    // return 누락! → result가 2번 호출됨 → 크래시
}
result(nil)

// ✅ 올바른 예
guard let name = ... else {
    result(FlutterError(...))
    return  // 반드시 return
}
result(nil)
```

---

## 10. 마치며

이 작업으로 배운 핵심:

1. **MethodChannel의 이름은 양쪽에서 동일해야 한다** — 하드코딩이지만 명확해서 추적하기 쉽다
2. **handle()의 FlutterResult는 반드시 1회만 호출** — 가장 많이 실수하는 부분
3. **타입 변환은 자동** — StandardMessageCodec이 Dart ↔ ObjC 타입을 자동 변환
4. **Flutter는 등록이 자동** — pubspec.yaml 한 줄이면 GeneratedPluginRegistrant가 처리
5. **RN보다 파일이 적다** — Swift 단일 파일로 구현 가능 (RN은 .m + .swift 2파일)

React Native는 ObjC 매크로(`RCT_EXPORT_MODULE`, `RCT_EXPORT_METHOD`)로,
Flutter는 Swift 프로토콜(`FlutterPlugin`)과 `switch` 분기로 — 방식은 다르지만
결국 **"이름을 맞추고, 타입을 변환하고, 결과를 돌려준다"** 는 본질은 같습니다.

---

*작성: AdTrackKit Portfolio Project*
*스택: Swift 6.2, Flutter 3.x, Dart 3.x*
