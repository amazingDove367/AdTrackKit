# 내가 만든 iOS SDK를 React Native에서 쓰는 법 — Native Module 브릿지 완전 분석

> **이 글에서 다루는 것**
> - React Native Bridge 아키텍처 개요
> - `RCT_EXPORT_MODULE` / `RCT_EXPORT_METHOD` 매크로가 하는 일
> - Objective-C ↔ Swift 상호 호출 원리
> - 직접 만든 AdTrackKit SDK를 RN에서 호출하기까지 전 과정

---

## 1. 왜 Native Module이 필요한가?

React Native는 JavaScript로 iOS/Android 앱을 만들 수 있게 해주지만,
**플랫폼 고유 기능**(카메라, 블루투스, 사내 SDK 등)은 JavaScript API로 접근할 수 없습니다.

이럴 때 사용하는 것이 **Native Module**입니다.
Native Module은 iOS/Android 네이티브 코드를 JavaScript에서 호출할 수 있는 "다리(Bridge)" 역할을 합니다.

```
┌─────────────────────────────────────────────────────┐
│                  React Native 앱                     │
│                                                     │
│   JavaScript                                        │
│   AdTrackKit.logEvent('add_to_cart', {...})         │
│          │                                          │
│          │  ← 이 경계가 Bridge (직렬화/역직렬화)     │
│          │                                          │
│   Native Module (iOS)                               │
│   ATKTracker.shared.logEvent(...)                   │
└─────────────────────────────────────────────────────┘
```

이 글에서는 제가 직접 만든 **AdTrackKit iOS SDK**를 React Native에서 사용할 수 있도록
Native Module 브릿지를 만드는 전 과정을 기록합니다.

---

## 2. 전체 파일 구조와 각 파일의 역할

```
AdTrackKit-RN/
├── ios/
│   ├── AdTrackKitModule.h              ① ObjC 인터페이스 선언
│   ├── AdTrackKitModule.m              ② RN 브릿지 (RCT 매크로)   ← 핵심
│   ├── AdTrackKitModule.swift          ③ Swift 구현체 (실제 SDK 호출)
│   └── AdTrackKitRN-Bridging-Header.h  ④ ObjC↔Swift 연결 헤더
├── js/
│   ├── AdTrackKit.ts                   ⑤ TypeScript 래퍼
│   └── index.ts                        ⑥ 패키지 진입점
└── example/
    └── App.tsx                         ⑦ 실제 사용 예제
```

각 파일이 서로 어떻게 연결되는지 먼저 큰 그림을 보겠습니다:

```
[⑥ index.ts]
    └── re-export → [⑤ AdTrackKit.ts]
                          │
                          │ NativeModules.AdTrackKit
                          ▼
                   [② AdTrackKitModule.m]   ← RCT_EXPORT_MODULE 등록
                          │
                          │ [AdTrackKitImpl shared] logEvent:...
                          ▼
                   [③ AdTrackKitModule.swift] ← @objc(AdTrackKitImpl)
                          │
                          │ ATKTracker.shared.logEvent(...)
                          ▼
                   AdTrackKit iOS SDK
```

---

## 3. ① AdTrackKitModule.h — ObjC 인터페이스 선언

```objc
#import <React/RCTBridgeModule.h>

@interface AdTrackKitModule : NSObject <RCTBridgeModule>
@end
```

**포인트:**
- `RCTBridgeModule` 프로토콜을 채택하는 것이 핵심입니다.
- 이 프로토콜을 채택한 클래스만 RN 브릿지에 등록될 수 있습니다.
- 실제로 `.m` 파일에서 `RCT_EXPORT_MODULE` 매크로가 이 프로토콜의 필수 메서드들을 자동 구현합니다.

---

## 4. ② AdTrackKitModule.m — RCT 매크로의 동작 원리

이 파일이 브릿지의 핵심입니다.

### RCT_EXPORT_MODULE

```objc
RCT_EXPORT_MODULE(AdTrackKit);
```

이 한 줄이 실제로 전개(expand)되면 다음과 같습니다:

```objc
// 매크로 전개 결과 (실제 코드 아님, 설명용)
+ (NSString *)moduleName {
    return @"AdTrackKit";   // JS에서 NativeModules.AdTrackKit 으로 접근
}

// 앱 시작 시 RCTBridge에 자동 등록
+ (void)load {
    [RCTBridge registerModuleClass:self];
}
```

**핵심 요점:**
- 매개변수에 지정한 문자열이 **JavaScript에서 접근하는 키**가 됩니다.
- `RCT_EXPORT_MODULE()` (괄호 비움) → `NativeModules.AdTrackKitModule` (클래스명 사용)
- `RCT_EXPORT_MODULE(AdTrackKit)` → `NativeModules.AdTrackKit` (명시적 지정)
- 앱이 시작될 때 `+load` 메서드를 통해 자동 등록됩니다 — 개발자가 직접 등록할 필요 없음.

### RCT_EXPORT_METHOD

```objc
RCT_EXPORT_METHOD(logEvent:(NSString *)name
                  properties:(NSDictionary *)properties
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    [[AdTrackKitImpl shared] logEvent:name
                           properties:properties
                             resolver:resolve
                             rejecter:reject];
}
```

**매크로 전개 결과 (설명용):**

```objc
// 1. 실제 구현 메서드 (RN 내부에서 호출)
- (void)logEvent:(NSString *)name
      properties:(NSDictionary *)properties
        resolver:(RCTPromiseResolveBlock)resolve
        rejecter:(RCTPromiseRejectBlock)reject
{
    // 개발자가 작성한 코드
    [[AdTrackKitImpl shared] logEvent:name ...];
}

// 2. JS 호출 이름 등록
// RN 브릿지가 "logEvent" 라는 이름으로 이 메서드를 JS에 노출
```

**타입 자동 변환 (Bridge가 처리):**

| JavaScript 타입 | Objective-C 타입    | 설명                         |
|-----------------|---------------------|------------------------------|
| `string`        | `NSString *`        |                              |
| `number`        | `NSInteger` / `double` |                           |
| `boolean`       | `BOOL`              |                              |
| `object`        | `NSDictionary *`    | `{ key: string }` → 딕셔너리 |
| `array`         | `NSArray *`         |                              |
| `null` / `undefined` | `nil` / `NSNull` |                         |

**Promise 처리:**

```objc
// 성공
resolve(nil);          // JS: Promise.resolve(undefined)
resolve(@"success");   // JS: Promise.resolve("success")

// 실패
reject(@"ERROR_CODE", @"에러 메시지", error);  // JS: Promise.reject(error)
```

---

## 5. ③ AdTrackKitModule.swift — Swift에서 @objc 어노테이션

```swift
@objc(AdTrackKitImpl)
public final class AdTrackKitImpl: NSObject {

    @objc public static let shared = AdTrackKitImpl()

    @objc
    public func logEvent(
        _ name: String,
        properties: [String: Any]?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let stringProps = properties?.compactMapValues { $0 as? String }
        ATKTracker.shared.logEvent(name, properties: stringProps)
        resolve(nil)
    }
}
```

### @objc 어노테이션이 필요한 이유

Swift는 기본적으로 ObjC 런타임에 노출되지 않습니다.
`@objc`를 붙이면 Xcode가 빌드 시 `{타겟명}-Swift.h` 헤더를 자동 생성합니다.
ObjC 파일(`.m`)에서 `#import "MyApp-Swift.h"` 로 이 헤더를 가져오면
Swift 클래스를 ObjC에서 호출할 수 있게 됩니다.

```
AdTrackKitModule.swift
    @objc(AdTrackKitImpl) class AdTrackKitImpl
         │
         │ Xcode 빌드 시 자동 생성
         ▼
"{타겟명}-Swift.h"   (예: MyApp-Swift.h)
         │
         │ #import
         ▼
AdTrackKitModule.m
    [[AdTrackKitImpl shared] logEvent:...]
```

### NSObject 상속이 필요한 이유

ObjC는 메시지 기반 런타임(message-passing runtime)을 사용합니다.
Swift 클래스가 ObjC에서 `[[obj method:arg]]` 형태로 호출되려면
ObjC 런타임의 객체 모델을 따르는 `NSObject`를 상속해야 합니다.

### 타입 변환: [String: Any] → [String: String]

ObjC `NSDictionary *`가 Swift로 건너올 때 `[String: Any]`로 변환됩니다.
ATKTracker는 `[String: String]`을 기대하므로 변환이 필요합니다:

```swift
// NSDictionary의 값이 NSString일 때만 포함 (NSNumber 등은 제외)
let stringProps = properties?.compactMapValues { $0 as? String }
```

---

## 6. ④ Bridging Header — ObjC와 Swift를 연결하는 접착제

```objc
// AdTrackKitRN-Bridging-Header.h
#import <React/RCTBridgeModule.h>
```

**역할:**
- 이 헤더에 선언된 ObjC 타입들이 **Swift 코드에서 자동으로 사용 가능**해집니다.
- `AdTrackKitModule.swift`에서 `RCTPromiseResolveBlock`, `RCTPromiseRejectBlock`을
  별도 import 없이 쓸 수 있는 것은 이 브릿지 헤더 덕분입니다.

**설정 방법:**
```
Xcode → Build Settings → Swift Compiler - General
→ Objective-C Bridging Header: ios/AdTrackKitRN-Bridging-Header.h
```

---

## 7. ⑤ JavaScript 래퍼 — TypeScript로 타입 안전하게

```typescript
import { NativeModules, Platform } from 'react-native';

// RCT_EXPORT_MODULE(AdTrackKit) 으로 등록된 이름과 반드시 일치해야 합니다.
const { AdTrackKit: _Native } = NativeModules;

const AdTrackKit = {
  logEvent(name: string, properties: Record<string, string> = {}): Promise<void> {
    if (Platform.OS !== 'ios') return Promise.resolve();
    return _Native.logEvent(name, properties);
  },
};
```

**직접 `NativeModules`를 쓰지 않고 래퍼를 만드는 이유:**

1. **타입 안전성**: TypeScript 타입 정의로 자동완성 + 컴파일 오류 조기 발견
2. **플랫폼 분기**: Android에서 호출해도 크래시 없이 no-op 처리
3. **기본값 처리**: `logEvent('screen_view')` — properties 생략 가능
4. **모듈 교체 용이**: 내부 구현 변경 시 JS 호출 코드는 수정 불필요

---

## 8. 실제 사용 — 장바구니 담기 전체 흐름

```typescript
// App.tsx
import AdTrackKit from 'adtrackkit-rn';

// 1. 초기화 (앱 시작 시 1회)
await AdTrackKit.initialize({
  appKey: 'my-app-key',
  environment: 'development',
});

// 2. 장바구니 담기 버튼
const handleAddToCart = async () => {
  await AdTrackKit.logEvent('add_to_cart', {
    product_id:   'P001',
    product_name: '프리미엄 무선 이어폰',
    price:        '89000',
  });
  // Xcode 콘솔에서 "[AdTrackKit] 이벤트 기록: add_to_cart" 확인 가능
};

// 3. 앱 백그라운드 전환 시 즉시 전송
AppState.addEventListener('change', (state) => {
  if (state === 'background') AdTrackKit.flush();
});
```

---

## 9. RCT_EXPORT_MODULE vs RCT_EXTERN_MODULE 차이

React Native에서 Swift 모듈을 연결하는 방법은 두 가지입니다:

### 방법 A: 이 프로젝트의 방식 (ObjC .m이 구현체)

```
AdTrackKitModule.m  → RCT_EXPORT_MODULE + RCT_EXPORT_METHOD (구현 존재)
                         ↓ ObjC에서 Swift 호출
AdTrackKitModule.swift → @objc(AdTrackKitImpl) (헬퍼 역할)
```

### 방법 B: RCT_EXTERN 패턴 (Swift가 직접 RN 모듈)

```
SomeModule.m       → RCT_EXTERN_MODULE + RCT_EXTERN_METHOD (선언만)
SomeModule.swift   → @objc(SomeModule) (직접 구현)
```

```objc
// 방법 B의 .m 파일 (선언만, 구현 없음)
RCT_EXTERN_MODULE(SomeModule, NSObject)
RCT_EXTERN_METHOD(logEvent:(NSString *)name)
```

```swift
// 방법 B의 .swift 파일 (직접 구현)
@objc(SomeModule)
class SomeModule: NSObject {
  @objc func logEvent(_ name: String) { ... }
}
```

**이 프로젝트에서 방법 A를 선택한 이유:**
- `RCT_EXPORT_MODULE`/`RCT_EXPORT_METHOD`가 .m 파일에 명시적으로 보여 이해하기 쉬움
- ObjC와 Swift 각자의 역할이 명확하게 분리됨

---

## 10. Xcode 설정 체크리스트

RN 앱에 이 브릿지를 추가할 때 확인해야 할 항목들입니다:

```
□ 1. ios/ 파일 4개를 Xcode 프로젝트 iOS 타겟에 추가
□ 2. Build Settings → Objective-C Bridging Header 설정
      값: ios/AdTrackKitRN-Bridging-Header.h
□ 3. AdTrackKitModule.m 의 #import "{타겟명}-Swift.h" 를 실제 타겟명으로 수정
      예: MyApp → #import "MyApp-Swift.h"
□ 4. Build Phases → Link Binary With Libraries → AdTrackKit.framework 추가
□ 5. (CocoaPods 사용 시) Podfile에 pod 추가 후 pod install
```

---

## 11. 디버깅 팁

### 네이티브 모듈이 undefined인 경우

```typescript
import { NativeModules } from 'react-native';
console.log(NativeModules.AdTrackKit);  // undefined 이면 문제

// 원인:
// 1. pod install 미실행 → cd ios && pod install && cd .. && npx react-native run-ios
// 2. 앱 재빌드 필요 (Metro 캐시 삭제) → npx react-native start --reset-cache
// 3. RCT_EXPORT_MODULE 이름과 NativeModules 접근 키 불일치
```

### Xcode 콘솔 로그 확인

```
# AdTrackKit 관련 로그 필터
[AdTrackKit] 이벤트 기록: add_to_cart (대기중: 1개)
[AdTrackKit] 배치 전송 시도: 1개 이벤트
```

### 타입 변환 오류 (NSNumber가 String으로 안 변환될 때)

```typescript
// ❌ number 타입은 [String: String]으로 변환 안됨
logEvent('test', { price: 89000 });       // number

// ✅ 모든 값은 string으로
logEvent('test', { price: '89000' });     // string
```

---

## 12. 마치며

이 작업을 통해 배운 것들:

1. **React Native의 Bridge 아키텍처**: JS ↔ Native 사이의 직렬화/역직렬화 흐름
2. **RCT_EXPORT_MODULE 매크로**: 앱 시작 시 자동 등록되는 ObjC 런타임 훅
3. **RCT_EXPORT_METHOD 매크로**: 타입 변환을 자동화해주는 Bridge 등록
4. **ObjC ↔ Swift 브릿지**: `@objc`, Bridging Header, 자동 생성 Swift 헤더
5. **TypeScript 래퍼의 가치**: 타입 안전성 + 플랫폼 분기 + 추상화

React Native Native Module은 복잡해 보이지만, 핵심은 단순합니다:
**ObjC 매크로로 등록 → Swift에서 구현 → JS에서 호출**.

---

*작성: AdTrackKit Portfolio Project*
*스택: Swift 6.2, Objective-C, React Native 0.73+, TypeScript*
