//
//  AdTrackKitModule.swift
//  AdTrackKit-RN
//
//  ■ 이 파일의 역할
//    AdTrackKitModule.m (ObjC 브릿지)에서 위임받아
//    실제로 AdTrackKit iOS SDK를 호출하는 Swift 구현체입니다.
//
//  ■ @objc 어노테이션이 필요한 이유
//    Swift 클래스/메서드는 기본적으로 ObjC에서 접근 불가합니다.
//    @objc를 붙이면 Xcode가 "{타겟명}-Swift.h" 헤더를 자동 생성하고,
//    ObjC 코드(AdTrackKitModule.m)에서 #import 로 사용할 수 있게 됩니다.
//
//  ■ RCTPromiseResolveBlock / RCTPromiseRejectBlock
//    브릿지 헤더(AdTrackKitRN-Bridging-Header.h)에서
//    <React/RCTBridgeModule.h>를 import했기 때문에
//    Swift 코드에서도 직접 사용 가능합니다.

import Foundation
import AdTrackKit   // 우리가 만든 iOS SDK

// MARK: - AdTrackKitImpl

/// AdTrackKit React Native 브릿지 Swift 구현체.
///
/// ObjC에서 참조하기 위해 @objc(AdTrackKitImpl) 로 이름을 명시합니다.
/// (AdTrackKitModule은 .m 파일의 ObjC 클래스가 사용하므로 다른 이름 사용)
@objc(AdTrackKitImpl)
public final class AdTrackKitImpl: NSObject {

    // MARK: - Singleton

    /// ObjC에서 [AdTrackKitImpl shared] 로 접근
    @objc public static let shared = AdTrackKitImpl()

    private override init() { super.init() }

    // MARK: - Initialize

    /// AdTrackKit SDK 초기화
    ///
    /// - Parameters:
    ///   - appKey: 앱 식별 키 (서비스별 발급)
    ///   - environment: "production" 또는 "development"
    ///   - resolve: 성공 시 JS Promise.resolve() 호출
    ///   - reject: 실패 시 JS Promise.reject() 호출
    ///
    /// ObjC 호출:
    ///   [[AdTrackKitImpl shared] initializeWithAppKey:@"key"
    ///                                     environment:@"development"
    ///                                        resolver:resolve
    ///                                        rejecter:reject];
    @objc
    public func initialize(
        withAppKey appKey: String,
        environment: String,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard !appKey.isEmpty else {
            reject("ATK_INVALID_KEY", "appKey는 빈 문자열일 수 없습니다.", nil)
            return
        }

        let env: ATKEnvironment = (environment == "production") ? .production : .development

        let config = ATKConfiguration.builder(appKey: appKey)
            .setEnvironment(env)
            .setLogLevel(env == .production ? .none : .debug)
            .setBatchSize(10)
            .setBatchInterval(30.0)
            .build()

        ATKTracker.shared.initialize(with: config)

        // nil을 전달하면 JS에서 Promise가 undefined로 resolve됨
        resolve(nil)
    }

    // MARK: - Log Event

    /// 이벤트 기록 (핵심 메서드)
    ///
    /// - Parameters:
    ///   - name: 이벤트 이름 (예: "add_to_cart", "purchase", "view_item")
    ///   - properties: 이벤트 속성. JS object → ObjC NSDictionary → Swift [String: Any]
    ///   - resolve: 성공 콜백
    ///   - reject: 실패 콜백
    ///
    /// 타입 변환 흐름:
    ///   JS: { product_id: "P001", price: "89000" }
    ///   → ObjC: NSDictionary *  { "product_id": "P001", "price": "89000" }
    ///   → Swift: [String: Any]  (이 메서드의 `properties` 파라미터)
    ///   → ATKTracker: [String: String] (compactMapValues로 변환)
    @objc
    public func logEvent(
        _ name: String,
        properties: [String: Any]?,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard !name.isEmpty else {
            reject("ATK_INVALID_EVENT", "이벤트 이름은 빈 문자열일 수 없습니다.", nil)
            return
        }

        // NSDictionary(Any)를 ATKTracker가 기대하는 [String: String]으로 안전하게 변환.
        // String이 아닌 값(NSNumber 등)은 compactMapValues에 의해 제거됩니다.
        let stringProps: [String: String]? = properties?.compactMapValues { $0 as? String }

        ATKTracker.shared.logEvent(name, properties: stringProps)
        resolve(nil)
    }

    // MARK: - Flush

    /// 내부 큐에 쌓인 이벤트를 즉시 서버로 전송합니다.
    /// 앱 생명주기 (applicationDidEnterBackground 등) 에서 호출하세요.
    @objc
    public func flush() {
        ATKTracker.shared.flush()
    }
}

// MARK: - 설계 메모
//
//  왜 ObjC(.m) + Swift(.swift) 두 파일로 나눴나?
//
//  1. React Native 브릿지 매크로(RCT_EXPORT_MODULE, RCT_EXPORT_METHOD)는
//     Objective-C 매크로이므로, 직접 Swift 파일에서 쓸 수 없습니다.
//
//  2. Swift에서 RCT 매크로를 쓰려면 RCT_EXTERN_MODULE / RCT_EXTERN_METHOD 패턴을 쓰거나
//     (Swift 파일만 있고 .m 에서 선언만 하는 방식),
//     이 프로젝트처럼 .m 이 구현을 갖고 Swift 를 호출하는 방식을 선택할 수 있습니다.
//
//  3. 이 방식의 장점:
//     - ObjC .m 에서 RCT_EXPORT_MODULE/METHOD 가 명확히 보임 (교육적)
//     - Swift 에서 실제 SDK 로직을 타입 안전하게 작성 가능
//     - 향후 Swift로 100% 전환 시 .m 파일만 교체하면 됨
