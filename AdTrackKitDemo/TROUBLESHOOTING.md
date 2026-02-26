# AdTrackKitDemo 빌드 트러블슈팅

Xcode 26 / iOS 26 SDK 환경에서 발생한 빌드 에러 원인 분석 및 해결 기록.

---

## 에러 1 · `Unable to find module dependency: 'AdTrackKit'`

### 에러 메시지

```
error: Unable to find module dependency: 'AdTrackKit'
AppDelegate.swift:9:8: a dependency of main module 'AdTrackKitDemo'
```

### 원인

`AdTrackKit.xcworkspace/contents.xcworkspacedata` 에 AdTrackKitDemo 프로젝트가 포함되어
있지 않았습니다. 데모 앱의 `AdTrackKit.framework` 참조가 `sourceTree = BUILT_PRODUCTS_DIR`
기반이기 때문에, 반드시 같은 워크스페이스 안에서 두 프로젝트를 함께 빌드해야 합니다.

### 해결

`contents.xcworkspacedata` 에 데모 앱 프로젝트를 추가합니다.

```xml
<!-- Before -->
<Workspace version="1.0">
  <FileRef location="group:AdTrackKit.xcodeproj"/>
</Workspace>

<!-- After -->
<Workspace version="1.0">
  <FileRef location="group:AdTrackKit.xcodeproj"/>
  <FileRef location="group:../AdTrackKitDemo/AdTrackKitDemo.xcodeproj"/>
</Workspace>
```

이후 빌드는 워크스페이스 단위로 실행합니다.

```bash
xcodebuild \
  -workspace "AdTrackKit/AdTrackKit.xcworkspace" \
  -scheme "AdTrackKitDemo" \
  -destination "platform=iOS Simulator,id=<UDID>" \
  build
```

---

## 에러 2 · `main actor-isolated conformance of 'ShopItem' to 'Hashable'`

### 에러 메시지

```
ViewController.swift:53:29: error:
  main actor-isolated conformance of 'ShopItem' to 'Hashable' cannot satisfy
  conformance requirement for a 'Sendable' type parameter 'ItemIdentifierType'
```

문제가 된 코드:

```swift
// ViewController.swift:53
private var dataSource: UICollectionViewDiffableDataSource<ShopSection, ShopItem>!
```

---

### 시도 1 — 별도 파일로 분리 ❌

Swift 6 관련 글에서 자주 나오는 "nested type 을 @MainActor 클래스 밖으로 꺼내라" 패턴을 적용했습니다.

```swift
// ShopDiffableTypes.swift (별도 파일 생성)
enum ShopSection: Int, CaseIterable, Hashable, Sendable { ... }
enum ShopItem: Hashable, Sendable { case banner; case product(Product) }
```

**결과: 동일한 에러.**
`-default-isolation=MainActor` 는 파일 단위가 아닌 **모듈 전체** 에 적용되기 때문에
파일을 분리해도 격리(isolation) 추론은 그대로입니다.

---

### 시도 2 — `Product` 에 `Sendable` 추가 ❌

`ShopItem.product(Product)` associated value 타입인 `Product` 가 `Sendable` 하지 않아
`ShopItem.Hashable` 컨포먼스가 오염됐다고 판단했습니다.

```swift
struct Product: Hashable, Sendable { ... }   // Sendable 추가
enum Category: String, CaseIterable, Sendable { ... }
enum Badge: String, Sendable { ... }
```

**결과: 동일한 에러.**
`Product.Sendable` 여부는 이 에러의 원인이 아니었습니다.

---

### 시도 3 — associated value 를 `String` 으로 교체 ❌

`Product` 자체가 문제라고 보고 associated value 를 경량 ID(String) 로 교체했습니다.

```swift
enum ShopItem: Hashable, Sendable {
    case banner
    case product(id: String)   // Product → String
}
```

**결과: 동일한 에러.**
`String` 도 동일하게 실패했습니다. `Product` 가 원인이 아니라는 것이 확인됐습니다.

---

### 근본 원인 파악 — `-default-isolation=MainActor`

세 번의 시도가 모두 실패한 뒤 실제 컴파일러 플래그를 확인했습니다.

```bash
xcodebuild ... build 2>&1 | grep "swift-frontend"
```

출력에서 핵심 플래그 발견:

```
-default-isolation=MainActor
-enable-upcoming-feature InferIsolatedConformances
```

**`-default-isolation=MainActor`** 는 Xcode 26 이 모든 타겟에 자동으로 추가하는 플래그로,
**모듈 안의 모든 타입이 암묵적으로 `@MainActor` 격리** 됩니다.

`InferIsolatedConformances` 기능이 함께 활성화되면 프로토콜 **컨포먼스 자체에도 격리가 전파** 됩니다.
그 결과 `ShopItem.Hashable` 컨포먼스가 `@MainActor`-isolated 로 표시되고,
`Sendable` 타입 파라미터를 요구하는 `UICollectionViewDiffableDataSource` 에서 타입 오류가 발생합니다.

```
UICollectionViewDiffableDataSource<S: Hashable & Sendable, I: Hashable & Sendable>
                                                                    ↑
                                    @MainActor-isolated Hashable 는 Sendable 제약 불충족
```

---

### 해결 — `nonisolated` 키워드 ✅

SE-0449 에서 도입된 `nonisolated` 키워드를 타입 선언에 붙이면
`-default-isolation=MainActor` 추론에서 **명시적으로 제외** 됩니다.

```swift
// ShopDiffableTypes.swift

nonisolated enum ShopSection: Int, CaseIterable, Hashable, Sendable {
    case banner
    case products
}

nonisolated enum ShopItem: Hashable, Sendable {
    case banner
    case product(id: String)
}
```

빌드 결과:

```
** BUILD SUCCEEDED **
```

---

### 추가 — DiffableDataSource 식별자 설계 원칙

시도 3에서 `Product` → `String` 으로 변경한 것은 에러를 해결하지 못했지만,
올바른 설계 방향이기는 합니다. DiffableDataSource 의 식별자 타입은
**모델 전체가 아닌 경량 ID** 여야 합니다.

```swift
// ❌ 모델 전체를 식별자로 — 가격이 바뀌면 같은 상품도 다른 아이템으로 처리됨
case product(Product)

// ✅ 경량 ID만 식별자로 — 변경 감지 정확, Sendable 처리 단순
case product(id: String)
```

셀 구성 시에는 ID 로 실제 모델을 조회합니다.

```swift
case .product(let id):
    let cell = cv.dequeueReusableCell(...) as! ProductCell
    if let product = self?.allProducts.first(where: { $0.id == id }) {
        cell.configure(with: product)
    }
    return cell
```

---

## 에러 요약

| 에러 | 원인 | 해결 |
|------|------|------|
| `Unable to find module 'AdTrackKit'` | xcworkspace 에 데모 앱 누락 | `contents.xcworkspacedata` 에 프로젝트 추가 |
| `main actor-isolated conformance ... 'Sendable'` | Xcode 26 의 `-default-isolation=MainActor` 가 모든 타입에 `@MainActor` 적용 | DiffableDataSource 식별자 타입에 `nonisolated` 추가 |

---

## Xcode 26 에서 DiffableDataSource 사용 시 체크리스트

```
□ 식별자 타입 선언에 nonisolated 추가
     nonisolated enum MySection: Hashable, Sendable { ... }
     nonisolated enum MyItem: Hashable, Sendable { ... }

□ 식별자 타입은 경량 ID (String / Int) 만 사용
     case product(id: String)  ← O
     case product(Product)     ← X

□ xcworkspace 에 의존 프로젝트가 모두 포함되어 있는지 확인

□ 원인 불명 actor isolation 에러 → 빌드 로그에서 swift-frontend 플래그 확인
     xcodebuild ... 2>&1 | grep "swift-frontend"
```
