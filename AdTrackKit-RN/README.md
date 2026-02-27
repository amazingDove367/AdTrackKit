# adtrackkit-rn

AdTrackKit iOS SDK를 React Native에서 사용하기 위한 **Native Module 브릿지** 패키지입니다.

Objective-C `RCT_EXPORT_MODULE` / `RCT_EXPORT_METHOD` 매크로와 Swift 구현체를 조합한 구조로,
JavaScript에서 단 한 줄로 iOS 네이티브 SDK를 호출할 수 있습니다.

---

## 파일 구조

```
AdTrackKit-RN/
├── ios/
│   ├── AdTrackKitModule.h              ObjC 헤더 (인터페이스 선언)
│   ├── AdTrackKitModule.m              ObjC 브릿지 (RCT_EXPORT_MODULE/METHOD)
│   ├── AdTrackKitModule.swift          Swift 구현체 (ATKTracker 호출)
│   └── AdTrackKitRN-Bridging-Header.h  ObjC↔Swift 브릿지 헤더
├── js/
│   ├── AdTrackKit.ts                   TypeScript 래퍼 (공개 API)
│   └── index.ts                        패키지 진입점
├── example/
│   └── App.tsx                         사용 예제
├── AdTrackKitRN.podspec               CocoaPods 스펙
└── package.json
```

---

## 브릿지 작동 흐름

```
JavaScript
  AdTrackKit.logEvent('add_to_cart', { ... })
      │
      │  NativeModules.AdTrackKit  (RCT_EXPORT_MODULE 로 등록된 이름)
      ▼
AdTrackKitModule.m                  ← RCT_EXPORT_METHOD 선언
  -[AdTrackKitModule logEvent:properties:resolver:rejecter:]
      │
      │  [AdTrackKitImpl shared]    (Swift 클래스, @objc(AdTrackKitImpl))
      ▼
AdTrackKitModule.swift
  ATKTracker.shared.logEvent("add_to_cart", properties: [...])
      │
      ▼
AdTrackKit iOS SDK (이벤트 저장 → 배치 전송)
```

---

## 설치

### 1. iOS 프로젝트에 파일 추가

`ios/` 디렉토리 4개 파일을 RN 앱 Xcode 프로젝트의 iOS 타겟에 추가합니다.

### 2. Bridging Header 설정

Xcode → `Build Settings` → `Swift Compiler - General`
→ `Objective-C Bridging Header`: `ios/AdTrackKitRN-Bridging-Header.h`

### 3. Swift 헤더 import 이름 확인

`AdTrackKitModule.m` 상단의 import를 Xcode 타겟명에 맞게 수정합니다:

```objc
// "{Xcode 타겟명}-Swift.h" 형식
#import "MyAwesomeApp-Swift.h"   // ← 타겟명으로 변경
```

### 4. AdTrackKit.framework 연결

Xcode → `Build Phases` → `Link Binary With Libraries` → `AdTrackKit.framework` 추가

### 5. (옵션) CocoaPods 사용

```ruby
# ios/Podfile
pod 'AdTrackKitRN', :path => '../AdTrackKit-RN'
```

---

## 사용법

### 초기화

```typescript
import AdTrackKit from 'adtrackkit-rn';

// App.tsx 또는 앱 진입점
await AdTrackKit.initialize({
  appKey: 'your-app-key',
  environment: 'development',  // 'production' | 'development'
});
```

### 이벤트 기록

```typescript
// 장바구니 담기
await AdTrackKit.logEvent('add_to_cart', {
  product_id:   'P001',
  product_name: '프리미엄 무선 이어폰',
  price:        '89000',
  category:     'electronics',
});

// 결제 완료
await AdTrackKit.logEvent('purchase', {
  order_id:   'ORD20260226001',
  price:      '89000',
  payment_pg: 'inicis',
});

// 화면 조회
await AdTrackKit.logEvent('screen_view', { screen_name: 'Home' });
```

### 즉시 전송 (앱 백그라운드 전환 시)

```typescript
import { AppState } from 'react-native';

AppState.addEventListener('change', (state) => {
  if (state === 'background') {
    AdTrackKit.flush();
  }
});
```

---

## 주요 이벤트 이름 권장 목록

| 이벤트 이름     | 설명                     | 주요 properties                        |
|----------------|--------------------------|----------------------------------------|
| `screen_view`  | 화면 조회                | `screen_name`                          |
| `view_item`    | 상품 상세 조회           | `product_id`, `product_name`, `price`  |
| `add_to_cart`  | 장바구니 담기            | `product_id`, `price`, `category`      |
| `begin_checkout` | 결제 시작              | `product_id`, `price`                  |
| `purchase`     | 결제 완료                | `order_id`, `price`, `payment_pg`      |
| `search`       | 검색                     | `query`                                |
| `login`        | 로그인                   | `method` (kakao / apple / email)       |

---

## 지원 환경

| 항목           | 버전           |
|----------------|----------------|
| iOS            | 15.0+          |
| React Native   | 0.73+          |
| Swift          | 5.9+           |
| Xcode          | 15+            |
| Android        | ❌ 미지원 (iOS 전용) |
