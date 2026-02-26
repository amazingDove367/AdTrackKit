# Xcode 26 + Swift 6.2 빌드 트러블슈팅: DiffableDataSource & -default-isolation=MainActor

> **이 글에서 다루는 것**
> - Xcode 26이 모든 타겟에 자동으로 적용하는 `-default-isolation=MainActor` 플래그
> - `UICollectionViewDiffableDataSource`의 `Sendable` 타입 파라미터 요구사항
> - `main actor-isolated conformance` 에러의 근본 원인과 해결 과정
> - DiffableDataSource 식별자 타입 설계 베스트 프랙티스

---

## 배경

AdTrackKit Demo 앱을 실제 쇼핑몰처럼 구성하면서 `UICollectionViewCompositionalLayout` +
`UICollectionViewDiffableDataSource` 조합으로 배너·상품 그리드를 구현했습니다.
Xcode 26(iOS 26 SDK)에서 빌드하자 한 번도 본 적 없는 에러가 나타났습니다.

---

## 에러 1 — xcworkspace에 데모 앱이 빠져 있음

### 증상

```
error: Unable to find module dependency: 'AdTrackKit'
```

AdTrackKitDemo 타겟이 AdTrackKit 프레임워크를 찾지 못해 빌드 자체가 시작되지 않았습니다.

### 원인

`AdTrackKit.xcworkspace/contents.xcworkspacedata`에 프레임워크 프로젝트만 들어 있고
데모 앱 프로젝트가 누락되어 있었습니다.

```xml
<!-- 수정 전: 프레임워크만 있음 -->
<Workspace version="1.0">
  <FileRef location="group:AdTrackKit.xcodeproj"/>
</Workspace>
```

### 해결

데모 앱 프로젝트를 워크스페이스에 추가합니다.
두 프로젝트가 같은 워크스페이스 안에 있어야 `BUILT_PRODUCTS_DIR`을 공유하고
프레임워크 참조가 올바르게 해소됩니다.

```xml
<!-- 수정 후: 두 프로젝트 모두 포함 -->
<Workspace version="1.0">
  <FileRef location="group:AdTrackKit.xcodeproj"/>
  <FileRef location="group:../AdTrackKitDemo/AdTrackKitDemo.xcodeproj"/>
</Workspace>
```

> **핵심**: `BUILT_PRODUCTS_DIR` 기반 프레임워크 참조는 워크스페이스가 두 프로젝트를
> 함께 빌드해야 동작합니다. 개별 프로젝트로 빌드하면 항상 "module not found" 에러가
> 발생합니다.

---

## 에러 2 — main actor-isolated conformance 에러

### 증상

```
ViewController.swift:53:29: error: main actor-isolated conformance of 'ShopItem'
to 'Hashable' cannot satisfy conformance requirement for a 'Sendable' type
parameter 'ItemIdentifierType'
```

빌드 대상 라인:

```swift
private var dataSource: UICollectionViewDiffableDataSource<ShopSection, ShopItem>!
```

### 잘못된 첫 번째 접근 — 타입을 별도 파일로 분리

Swift 6 공식 문서에서 자주 언급되는 해결책인 "별도 파일로 분리"를 먼저 시도했습니다.

```swift
// ShopDiffableTypes.swift (별도 파일)
enum ShopSection: Int, CaseIterable, Hashable, Sendable { ... }
enum ShopItem: Hashable, Sendable { case banner; case product(Product) }
```

**결과: 여전히 동일한 에러.** 별도 파일로 분리해도 해결되지 않았습니다.

### 잘못된 두 번째 접근 — Product에 Sendable 추가

`ShopItem.product(Product)`의 associated value 타입인 `Product`가 `Sendable`하지 않아
`ShopItem.Hashable` 컨포먼스가 오염된 것으로 추정했습니다.

```swift
struct Product: Hashable, Sendable { ... }   // Sendable 추가
enum Category: String, CaseIterable, Sendable { ... }
enum Badge: String, Sendable { ... }
```

**결과: 여전히 동일한 에러.** `Product.Sendable`이 문제가 아니었습니다.

### 잘못된 세 번째 접근 — associated value를 String으로 변경

`Product` 자체가 문제라고 보고 associated value를 `String` ID로 교체했습니다.

```swift
enum ShopItem: Hashable, Sendable {
    case banner
    case product(id: String)   // Product → String
}
```

**결과: 여전히 동일한 에러.** `String`도 동일하게 실패했습니다.

---

## 근본 원인 분석 — -default-isolation=MainActor

세 번의 시도가 모두 실패한 뒤 실제 컴파일러 플래그를 확인했습니다.

```bash
xcodebuild ... build 2>&1 | grep "swift-frontend"
```

출력에서 핵심 플래그가 발견되었습니다:

```
-default-isolation=MainActor
-enable-upcoming-feature InferIsolatedConformances
```

### 이게 무슨 의미인가?

`-default-isolation=MainActor`는 **모듈의 모든 타입에 암묵적으로 `@MainActor` 격리를 적용**하는
Xcode 26의 신규 기본 동작입니다 (SE-0466 관련).

```
Xcode 26 이전:
  enum ShopItem: Hashable, Sendable { ... }
  → ShopItem.Hashable 컨포먼스: nonisolated ✅

Xcode 26 이후 (-default-isolation=MainActor):
  enum ShopItem: Hashable, Sendable { ... }
  → ShopItem.Hashable 컨포먼스: @MainActor-isolated ❌
```

`InferIsolatedConformances` 기능이 활성화되면 컨포먼스 자체에도 격리가 전파됩니다.
그 결과 `@MainActor`-isolated `Hashable` 컨포먼스는 `Sendable` 타입 파라미터 제약을
충족할 수 없게 됩니다.

```
UICollectionViewDiffableDataSource<S, I>
  where S: Hashable & Sendable, I: Hashable & Sendable
                                               ↑
                           @MainActor-isolated Hashable는 여기서 실패
```

### 왜 별도 파일로 분리해도 안 됐는가?

별도 파일이어도 `-default-isolation=MainActor`는 **모듈 전체**에 적용됩니다.
파일 단위가 아니라 모듈 단위 플래그이기 때문에 파일 분리는 효과가 없습니다.

---

## 해결 — nonisolated 키워드

Swift 6.2 / SE-0449 (`nonisolated` to prevent global actor inference)에 따르면
타입 선언에 `nonisolated`를 붙이면 기본 격리 추론에서 명시적으로 제외됩니다.

```swift
// ShopDiffableTypes.swift

// ✅ nonisolated: -default-isolation=MainActor 환경에서도
//    Hashable 컨포먼스가 non-isolated임을 보장
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

## 추가 개선 — DiffableDataSource 식별자 설계

에러를 수정하는 과정에서 `ShopItem.product(Product)`를 `ShopItem.product(id: String)`로
변경했는데, 이는 단순히 에러 회피가 아니라 DiffableDataSource 베스트 프랙티스이기도 합니다.

### 잘못된 설계 (수정 전)

```swift
enum ShopItem: Hashable, Sendable {
    case banner
    case product(Product)   // ❌ 모델 전체를 식별자로 사용
}
```

| 문제점 | 설명 |
|--------|------|
| 무거운 식별자 | `Product`의 모든 프로퍼티가 해싱에 참여 |
| 변경 감지 오류 | 가격이 바뀌면 같은 상품도 다른 아이템으로 처리됨 |
| Sendable 문제 | 모델이 복잡해질수록 Sendable 충족이 어려워짐 |

### 올바른 설계 (수정 후)

```swift
nonisolated enum ShopItem: Hashable, Sendable {
    case banner
    case product(id: String)   // ✅ 경량 ID만 식별자로 사용
}
```

셀 구성 시 ID로 실제 모델을 조회합니다:

```swift
dataSource = UICollectionViewDiffableDataSource(collectionView: cv) { [weak self] cv, indexPath, item in
    switch item {
    case .banner:
        return cv.dequeueReusableCell(...)

    case .product(let id):
        let cell = cv.dequeueReusableCell(...) as! ProductCell
        // ID로 실제 Product 조회
        if let product = self?.allProducts.first(where: { $0.id == id }) {
            cell.configure(with: product)
        }
        return cell
    }
}
```

---

## 전체 에러 해결 흐름

```
에러: Unable to find module dependency: 'AdTrackKit'
  └─ 원인: xcworkspace에 데모 앱 프로젝트 누락
     └─ 해결: contents.xcworkspacedata에 AdTrackKitDemo.xcodeproj 추가

에러: main actor-isolated conformance of 'ShopItem' to 'Hashable'
  ├─ 시도 1: ShopSection/ShopItem 별도 파일 분리 → 실패 (모듈 전체 적용이므로)
  ├─ 시도 2: Product에 Sendable 추가 → 실패 (Product가 원인이 아님)
  ├─ 시도 3: associated value를 Product → String으로 변경 → 실패 (근본 원인 아님)
  └─ 해결: 컴파일러 플래그 확인 → -default-isolation=MainActor 발견
           → nonisolated enum ShopSection, ShopItem으로 해결
```

---

## Xcode 26 신규 프로젝트에서 DiffableDataSource 쓰기 — 체크리스트

```
□ DiffableDataSource 식별자 타입을 선언할 때 nonisolated 추가
□ 식별자 타입은 경량 ID (String / Int) 만 사용, 모델 전체 X
□ xcworkspace에 의존 프로젝트가 모두 포함되어 있는지 확인
□ 알 수 없는 actor isolation 에러 → 빌드 로그에서 swift-frontend 플래그 확인
```

---

## 배운 점

1. **에러 메시지가 가리키는 위치를 믿지 말고 컴파일러 플래그를 확인하라**
   — 에러는 `ViewController.swift`를 가리켰지만 실제 원인은 프로젝트 전체에 적용된
   `-default-isolation=MainActor` 플래그였습니다.

2. **Xcode 26은 `-default-isolation=MainActor`를 기본으로 켠다**
   — 새 프로젝트를 만들면 모든 타입이 암묵적으로 `@MainActor`입니다.
   비격리 타입이 필요하면 `nonisolated`를 명시해야 합니다.

3. **DiffableDataSource 식별자는 가능한 한 작고 단순하게**
   — `String` / `Int` 같은 기본 타입이나 ID 전용 구조체를 사용합니다.
   모델 전체를 식별자로 쓰면 변경 감지가 부정확해지고 Sendable 문제가 생깁니다.

4. **별도 파일 분리는 만능이 아니다**
   — Swift 5 시대의 "nested type → 별도 파일 분리" 패턴은 Xcode 26에서 더 이상
   충분하지 않습니다. 격리(isolation) 개념을 명시적으로 다뤄야 합니다.

---

*작성: AdTrackKit Portfolio Project*
*스택: Swift 6.2 (language mode 5), Xcode 26, iOS 26 SDK*
