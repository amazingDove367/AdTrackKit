//
//  AdTrackKitFlutterPlugin.swift
//  adtrackkit_flutter
//
//  ■ 이 파일의 역할
//    Flutter Dart ↔ iOS Swift 사이의 통신 핸들러입니다.
//    FlutterPlugin 프로토콜을 채택하여 Flutter 엔진에 등록되고,
//    Dart의 invokeMethod 호출을 handle(_:result:) 로 수신합니다.
//
//  ■ 통신 흐름
//    Dart: _channel.invokeMethod('logEvent', {...})
//      → Flutter Engine (직렬화 / 역직렬화)
//        → 이 파일: handle(_ call: FlutterMethodCall, result: @escaping FlutterResult)
//          → ATKTracker.shared.logEvent(...)
//            → result(nil)  →  Dart Future 완료
//
//  ■ FlutterResult 응답 종류
//    result(nil)                          → Dart: Future<void> 완료
//    result("someString")                 → Dart: Future<String?> 완료
//    result(FlutterError(...))            → Dart: PlatformException throw
//    result(FlutterMethodNotImplemented)  → Dart: MissingPluginException throw

import Flutter
import AdTrackKit

// @objc: Flutter 엔진(ObjC 런타임 기반)에서 이 클래스를 인식하게 합니다.
// NSObject: ObjC 메시지 패싱 호환을 위해 필수 상속
// FlutterPlugin: Flutter가 플러그인으로 인식하기 위한 프로토콜
@objc(AdTrackKitFlutterPlugin)
public final class AdTrackKitFlutterPlugin: NSObject, FlutterPlugin {

    // MARK: - FlutterPlugin 등록

    /// Flutter 엔진 초기화 시 자동 호출됩니다.
    /// MethodChannel을 생성하고, 이 인스턴스를 델리게이트로 등록합니다.
    ///
    /// - channel name: Dart 파일의 MethodChannel 이름과 반드시 일치해야 합니다.
    ///   Dart:  MethodChannel('adtrackkit_flutter')
    ///   Swift: FlutterMethodChannel(name: "adtrackkit_flutter", ...)
    public static func register(with registrar: any FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "adtrackkit_flutter",       // ← Dart와 동일한 채널 이름
            binaryMessenger: registrar.messenger()
        )
        let instance = AdTrackKitFlutterPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - MethodCall 핸들러

    /// Dart에서 invokeMethod() 를 호출하면 이 메서드가 실행됩니다.
    ///
    /// - Parameter call: 호출 정보
    ///   - call.method: Dart에서 전달한 메서드 이름 (예: "logEvent")
    ///   - call.arguments: Dart에서 전달한 인자 (JSON → Any로 역직렬화됨)
    ///
    /// - Parameter result: 응답 콜백 (반드시 1회 호출해야 합니다)
    ///   - result(nil)                         → Dart Future 정상 완료
    ///   - result("value")                     → Dart Future에 값 반환
    ///   - result(FlutterError(...))            → Dart PlatformException 발생
    ///   - result(FlutterMethodNotImplemented) → 미구현 메서드 알림
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            handleInitialize(call: call, result: result)

        case "logEvent":
            handleLogEvent(call: call, result: result)

        case "flush":
            handleFlush(result: result)

        default:
            // 구현되지 않은 메서드 이름이 호출된 경우
            // Dart에서 MissingPluginException이 발생합니다.
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - 개별 핸들러

    /// SDK 초기화 핸들러
    ///
    /// Dart 호출:
    /// ```dart
    /// await _channel.invokeMethod('initialize', {
    ///   'appKey': 'my-key',
    ///   'environment': 'development',
    /// });
    /// ```
    private func handleInitialize(call: FlutterMethodCall, result: @escaping FlutterResult) {
        // call.arguments 는 Any? 타입 → [String: Any]로 안전하게 캐스팅
        guard let args = call.arguments as? [String: Any],
              let appKey = args["appKey"] as? String,
              !appKey.isEmpty
        else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "appKey는 필수이며 빈 문자열일 수 없습니다.",
                details: call.arguments
            ))
            return
        }

        let environment = args["environment"] as? String ?? "production"
        let env: ATKEnvironment = (environment == "production") ? .production : .development

        let config = ATKConfiguration.builder(appKey: appKey)
            .setEnvironment(env)
            .setLogLevel(env == .production ? .none : .debug)
            .setBatchSize(10)
            .setBatchInterval(30.0)
            .build()

        ATKTracker.shared.initialize(with: config)

        // nil → Dart의 Future<void> 가 정상 완료됨
        result(nil)
    }

    /// 이벤트 기록 핸들러 (핵심 메서드)
    ///
    /// Dart 호출:
    /// ```dart
    /// await _channel.invokeMethod('logEvent', {
    ///   'name': 'add_to_cart',
    ///   'properties': { 'product_id': 'P001', 'price': '89000' },
    /// });
    /// ```
    ///
    /// 타입 변환 흐름:
    ///   Dart Map<String, String>
    ///     → Flutter Engine (MessageCodec)
    ///       → ObjC NSDictionary *
    ///         → Swift [String: Any]  (call.arguments)
    ///           → [String: String]   (compactMapValues)
    ///             → ATKTracker.shared.logEvent(...)
    private func handleLogEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let name = args["name"] as? String,
              !name.isEmpty
        else {
            result(FlutterError(
                code: "INVALID_ARGUMENT",
                message: "이벤트 name은 필수이며 빈 문자열일 수 없습니다.",
                details: call.arguments
            ))
            return
        }

        // Dart Map<String, String> → Swift [String: Any] → [String: String]
        // compactMapValues: String으로 캐스팅 불가한 값은 제거
        let rawProps = args["properties"] as? [String: Any]
        let properties: [String: String]? = rawProps?.compactMapValues { $0 as? String }

        ATKTracker.shared.logEvent(name, properties: properties)
        result(nil)
    }

    /// 즉시 전송 핸들러
    ///
    /// Dart 호출:
    /// ```dart
    /// await _channel.invokeMethod('flush');
    /// ```
    private func handleFlush(result: @escaping FlutterResult) {
        ATKTracker.shared.flush()
        result(nil)
    }
}

// MARK: - 설계 메모
//
//  RN 브릿지와의 차이점:
//
//  React Native               │  Flutter
//  ─────────────────────────────────────────────────────────────
//  RCT_EXPORT_MODULE          │  FlutterPlugin.register(with:) 에서 채널 등록
//  RCT_EXPORT_METHOD          │  handle(_:result:) 의 switch case
//  ObjC .m + Swift .swift     │  Swift 단일 파일로 구현 가능
//  Promise (resolve/reject)   │  FlutterResult (nil / value / FlutterError)
//  NativeModules.AdTrackKit   │  MethodChannel('adtrackkit_flutter')
//
//  공통점:
//  - 채널/모듈 이름이 양쪽에서 반드시 일치해야 함
//  - 타입 변환: JS/Dart 객체 → ObjC 타입 → Swift 타입
//  - 비동기 처리: Promise / Future
