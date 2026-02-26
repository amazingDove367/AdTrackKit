//
//  Product.swift
//  AdTrackKitDemo
//

import Foundation

struct Product: Hashable, Sendable {
    let id: String
    let name: String
    let description: String
    let price: Int
    let originalPrice: Int?
    let category: Category
    let emoji: String
    let badge: Badge?

    enum Category: String, CaseIterable, Sendable {
        case all        = "전체"
        case electronics = "전자기기"
        case accessories = "액세서리"
        case lifestyle   = "생활용품"
    }

    enum Badge: String, Sendable {
        case best = "BEST"
        case new  = "NEW"
        case sale = "SALE"
    }

    var discountRate: Int? {
        guard let original = originalPrice, original > price else { return nil }
        return Int((1.0 - Double(price) / Double(original)) * 100)
    }

    var formattedPrice: String {
        formatted(price) + "원"
    }

    var formattedOriginalPrice: String? {
        originalPrice.map { formatted($0) + "원" }
    }

    private func formatted(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    // MARK: - Sample Data

    static let samples: [Product] = [
        Product(
            id: "P001",
            name: "프리미엄 무선 이어폰",
            description: "액티브 노이즈 캔슬링으로 완벽한 몰입감\n최대 30시간 연속 재생, 하이파이 사운드 지원",
            price: 89_000, originalPrice: 129_000,
            category: .electronics, emoji: "🎧", badge: .best
        ),
        Product(
            id: "P002",
            name: "스마트 피트니스 밴드",
            description: "심박수·혈중산소 실시간 측정\n수면 분석 및 14종 운동 모드 자동 인식",
            price: 59_000, originalPrice: nil,
            category: .electronics, emoji: "⌚️", badge: .new
        ),
        Product(
            id: "P003",
            name: "접이식 스마트폰 스탠드",
            description: "항공 알루미늄 합금 소재, 360도 회전 지지대\n4~13인치 기기 호환, 미끄럼 방지 실리콘 패드",
            price: 29_000, originalPrice: nil,
            category: .accessories, emoji: "📱", badge: nil
        ),
        Product(
            id: "P004",
            name: "USB-C 멀티포트 허브 7-in-1",
            description: "HDMI 4K 출력·USB 3.0 ×3·SD/MicroSD\nPD 100W 충전 패스스루 지원",
            price: 45_000, originalPrice: 65_000,
            category: .electronics, emoji: "🔌", badge: .sale
        ),
        Product(
            id: "P005",
            name: "노트북 파우치 15인치",
            description: "고밀도 방수 소재, 내부 충격 흡수 레이어\n액세서리 수납 포켓 2개 내장",
            price: 39_000, originalPrice: nil,
            category: .lifestyle, emoji: "💼", badge: nil
        ),
        Product(
            id: "P006",
            name: "무선 고속 충전 패드",
            description: "15W 고속 충전, Qi 표준 완벽 호환\n이물질 감지·과열 방지 안전 설계",
            price: 25_000, originalPrice: nil,
            category: .accessories, emoji: "🔋", badge: nil
        ),
        Product(
            id: "P007",
            name: "슬림 블루투스 키보드",
            description: "멀티 디바이스 3대 즉시 전환 연결\n맥·윈도우·안드로이드 호환, 배터리 3개월",
            price: 79_000, originalPrice: nil,
            category: .electronics, emoji: "⌨️", badge: .new
        ),
        Product(
            id: "P008",
            name: "미니 빔프로젝터",
            description: "1080P FHD·밝기 1000 ANSI 루멘\nWi-Fi 스크린 미러링, 자동 키스톤 보정",
            price: 199_000, originalPrice: 249_000,
            category: .electronics, emoji: "📽️", badge: .best
        ),
    ]
}
