//
//  AdTrackKitModule.m
//  AdTrackKit-RN
//
//  ■ 이 파일의 역할
//    React Native JavaScript ↔ iOS Native 사이의 "관문(Gateway)".
//    RCT_EXPORT_MODULE 로 모듈을 등록하고,
//    RCT_EXPORT_METHOD 로 JS에서 호출 가능한 메서드를 선언합니다.
//    실제 비즈니스 로직은 AdTrackKitModule.swift (AdTrackKitImpl) 에 위임합니다.
//
//  ■ 아키텍처
//    JS 호출 → [RN Bridge: JSON 직렬화] → 이 파일(.m) → AdTrackKitImpl(.swift) → ATKTracker

#import "AdTrackKitModule.h"

// Xcode 빌드 시 자동 생성되는 Swift 헤더.
// 이 헤더를 통해 ObjC에서 Swift 클래스(AdTrackKitImpl)를 호출합니다.
// 파일명 규칙: "{Xcode 타겟명}-Swift.h"
// ↓ 실제 앱에서는 RN 앱의 타겟명으로 변경하세요 (예: "MyAwesomeApp-Swift.h")
#import "AdTrackKitRN-Swift.h"

@implementation AdTrackKitModule

// ─────────────────────────────────────────────────────────────────────────────
// RCT_EXPORT_MODULE(name)
//
// ■ 하는 일
//   1. +moduleName 클래스 메서드를 자동 구현 → 지정한 이름("AdTrackKit") 반환
//   2. +load 를 통해 앱 시작 시 RCTBridge에 이 클래스를 자동 등록
//   3. JS에서 NativeModules.AdTrackKit 으로 접근 가능하게 만듦
//
// ■ 매개변수
//   RCT_EXPORT_MODULE()            → JS 이름: NativeModules.AdTrackKitModule (클래스명)
//   RCT_EXPORT_MODULE(AdTrackKit)  → JS 이름: NativeModules.AdTrackKit       (명시적 지정)
//
// ■ 내부 구현 (매크로 전개 결과)
//   + (NSString *)moduleName { return @"AdTrackKit"; }
//   + (void)load { [RCTBridge registerModuleClass:self]; }
// ─────────────────────────────────────────────────────────────────────────────
RCT_EXPORT_MODULE(AdTrackKit);


// requiresMainQueueSetup
// YES → 메인 스레드에서 모듈 초기화 (UIKit 접근이 필요한 경우)
// NO  → 백그라운드 스레드에서 초기화 가능 (퍼포먼스 향상)
// AdTrackKit은 UI 없이 동작하므로 NO
+ (BOOL)requiresMainQueueSetup {
    return NO;
}


// ─────────────────────────────────────────────────────────────────────────────
// RCT_EXPORT_METHOD(signature)
//
// ■ 하는 일
//   1. 이 메서드를 JS에서 호출 가능한 목록에 등록
//   2. JS → ObjC 타입 자동 변환 (JSON 역직렬화):
//      JS string    → NSString *
//      JS number    → NSInteger / double / NSNumber *
//      JS boolean   → BOOL
//      JS object    → NSDictionary *
//      JS array     → NSArray *
//      JS null      → NSNull / nil
//   3. 반환값 없음 → 결과는 Promise 또는 Callback으로 전달
//
// ■ Promise 콜백 타입
//   RCTPromiseResolveBlock: typedef void (^)(id result)    → JS Promise.resolve(result)
//   RCTPromiseRejectBlock:  typedef void (^)(NSString *code, NSString *message, NSError *error)
//                                                          → JS Promise.reject(error)
// ─────────────────────────────────────────────────────────────────────────────


/// AdTrackKit SDK 초기화
/// JS: await NativeModules.AdTrackKit.initialize('my-app-key', 'development')
RCT_EXPORT_METHOD(initialize:(NSString *)appKey
                  environment:(NSString *)environment
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    // ObjC 브릿지 역할만 하고, 실제 로직은 Swift 구현체에 위임
    [[AdTrackKitImpl shared] initializeWithAppKey:appKey
                                      environment:environment
                                         resolver:resolve
                                         rejecter:reject];
}


/// 이벤트 기록 (가장 핵심 메서드)
///
/// JS 호출 예시:
///   // 장바구니 담기
///   await NativeModules.AdTrackKit.logEvent('add_to_cart', {
///     product_id: 'P001',
///     product_name: '프리미엄 무선 이어폰',
///     price: '89000'
///   });
///
///   // 결제 완료
///   await NativeModules.AdTrackKit.logEvent('purchase', {
///     order_id: 'ORD20260226001',
///     total_price: '89000'
///   });
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


/// 미전송 이벤트 즉시 전송
/// 앱이 백그라운드로 전환되거나 종료되기 직전에 호출하세요.
/// JS: NativeModules.AdTrackKit.flush()
/// (반환값 없으므로 Promise 불필요 → RCT_EXPORT_METHOD 파라미터 없음)
RCT_EXPORT_METHOD(flush)
{
    [[AdTrackKitImpl shared] flush];
}

@end


// ─────────────────────────────────────────────────────────────────────────────
// 참고: RCT_EXTERN_MODULE vs RCT_EXPORT_MODULE
//
// RCT_EXPORT_MODULE  : ObjC 클래스가 직접 구현체인 경우 사용 (이 파일처럼)
// RCT_EXTERN_MODULE  : Swift 클래스를 ObjC .m 에서 "선언만" 할 때 사용
//                      이 경우 .m 파일에는 구현이 없고,
//                      Swift 파일에 @objc(ModuleName) 클래스가 실제 구현
//
// 마찬가지로:
// RCT_EXPORT_METHOD  : ObjC 구현 메서드에 사용
// RCT_EXTERN_METHOD  : Swift 구현 메서드를 ObjC에서 선언할 때 사용
// ─────────────────────────────────────────────────────────────────────────────
