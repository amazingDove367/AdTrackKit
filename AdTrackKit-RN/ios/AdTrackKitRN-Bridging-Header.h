//
//  AdTrackKitRN-Bridging-Header.h
//  AdTrackKit-RN
//
//  Objective-C ↔ Swift 브릿지 헤더
//
//  ■ 역할
//    이 파일에 선언된 ObjC 헤더들을 Swift 코드에서 자유롭게 import 없이 사용할 수 있습니다.
//    Swift에서 RCTPromiseResolveBlock, RCTPromiseRejectBlock 등
//    React Native 타입을 직접 참조하기 위해 필요합니다.
//
//  ■ Xcode 설정 방법
//    Build Settings → Swift Compiler - General
//    → Objective-C Bridging Header: "ios/AdTrackKitRN-Bridging-Header.h"
//
//  ■ 주의
//    이 파일은 직접 import하지 않습니다.
//    Xcode가 빌드 시 자동으로 Swift 컴파일러에 주입합니다.

// React Native 핵심 브릿지 타입
// - RCTBridgeModule 프로토콜
// - RCTPromiseResolveBlock / RCTPromiseRejectBlock 타입 별칭
// - RCT_EXPORT_MODULE / RCT_EXPORT_METHOD 매크로
#import <React/RCTBridgeModule.h>

// 이벤트 전송 기능이 필요한 경우 (optional)
// iOS → JS 방향으로 이벤트를 push할 때 사용
#import <React/RCTEventEmitter.h>

// 네이티브 로그 유틸리티 (optional)
#import <React/RCTLog.h>
