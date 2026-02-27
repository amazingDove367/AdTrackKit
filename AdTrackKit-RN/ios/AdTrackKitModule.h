//
//  AdTrackKitModule.h
//  AdTrackKit-RN
//
//  React Native ↔ iOS 네이티브 브릿지 인터페이스 선언
//
//  ┌──────────────────────────────────────────────────┐
//  │  JavaScript (RN)                                 │
//  │    NativeModules.AdTrackKit.logEvent(...)        │
//  └───────────────────┬──────────────────────────────┘
//                      │ React Native Bridge (JSON 직렬화)
//  ┌───────────────────▼──────────────────────────────┐
//  │  AdTrackKitModule.m  (이 파일에서 선언)           │
//  │    RCT_EXPORT_MODULE + RCT_EXPORT_METHOD          │
//  └───────────────────┬──────────────────────────────┘
//                      │ ObjC → Swift 호출
//  ┌───────────────────▼──────────────────────────────┐
//  │  AdTrackKitModule.swift (AdTrackKitImpl)          │
//  │    ATKTracker.shared.logEvent(...)                │
//  └──────────────────────────────────────────────────┘

#import <React/RCTBridgeModule.h>

/// React Native 네이티브 모듈 선언.
/// RCTBridgeModule 프로토콜을 채택함으로써
/// RN 브릿지가 이 클래스를 네이티브 모듈로 인식합니다.
NS_ASSUME_NONNULL_BEGIN

@interface AdTrackKitModule : NSObject <RCTBridgeModule>

@end

NS_ASSUME_NONNULL_END
