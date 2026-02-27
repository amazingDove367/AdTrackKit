//
//  ShopDiffableTypes.swift
//  AdTrackKitDemo
//
//  UICollectionViewDiffableDataSource 식별자 타입 정의.
//
//  Swift 6.2 에서 @MainActor 클래스와 같은 파일에 선언된 타입의
//  Hashable conformance 는 main actor-isolated 로 추론되어
//  Sendable 파라미터 제약을 충족하지 못합니다.
//  별도 파일로 분리해 non-isolated conformance 를 보장합니다.
//

// MARK: - DiffableDataSource 식별자
//
// -default-isolation=MainActor (Xcode 26 기본값) 환경에서
// UICollectionViewDiffableDataSource 의 Sendable 타입 파라미터 요구를 충족하려면
// 이 타입들을 nonisolated 로 선언해야 합니다.

nonisolated enum ShopSection: Int, CaseIterable, Hashable, Sendable {
    case banner
    case products
}

nonisolated enum ShopItem: Hashable, Sendable {
    case banner
    case product(id: String)
}
