/// AdTrackKit Flutter Plugin — Dart 공개 API
///
/// FlutterMethodChannel을 통해 iOS Swift 코드와 통신합니다.
///
/// 통신 흐름:
///   Dart  invokeMethod('logEvent', {...})
///     → MethodChannel (adtrackkit_flutter)
///       → Swift handle(_ call:result:)
///         → ATKTracker.shared.logEvent(...)
///
/// 사용 예시:
/// ```dart
/// await AdTrackKit.initialize(appKey: 'my-key', environment: 'development');
/// await AdTrackKit.logEvent('add_to_cart', properties: {
///   'product_id': 'P001',
///   'price': '89000',
/// });
/// ```
library adtrackkit_flutter;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ─── MethodChannel ────────────────────────────────────────────────────────────
//
// MethodChannel의 이름은 Dart와 Swift 양쪽에서 반드시 동일해야 합니다.
//
// Dart  : MethodChannel('adtrackkit_flutter')
// Swift : FlutterMethodChannel(name: "adtrackkit_flutter", ...)
//
// 이름 충돌을 피하기 위해 도메인-역순 패턴을 권장합니다:
// 예: 'com.atkmall.adtrackkit/tracker'
// ─────────────────────────────────────────────────────────────────────────────
const MethodChannel _channel = MethodChannel('adtrackkit_flutter');

// ─── 공개 API ─────────────────────────────────────────────────────────────────

/// AdTrackKit iOS SDK Flutter 인터페이스
///
/// 모든 메서드는 static이며 싱글턴처럼 사용합니다.
class AdTrackKit {
  AdTrackKit._(); // 인스턴스 생성 방지

  // ── Initialize ──────────────────────────────────────────────────────────────

  /// SDK를 초기화합니다. 앱 시작 시 1회 호출하세요.
  ///
  /// [appKey] 앱 식별 키 (서비스별 발급)
  /// [environment] 'production' (기본) 또는 'development'
  ///
  /// ```dart
  /// // main.dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await AdTrackKit.initialize(appKey: 'your-key', environment: 'development');
  ///   runApp(const MyApp());
  /// }
  /// ```
  static Future<void> initialize({
    required String appKey,
    String environment = 'production',
  }) async {
    // iOS 전용 SDK. 다른 플랫폼에서는 no-op으로 처리.
    if (!_isPlatformSupported) return;

    await _channel.invokeMethod<void>('initialize', <String, dynamic>{
      'appKey': appKey,
      'environment': environment,
    });
  }

  // ── Log Event ────────────────────────────────────────────────────────────────

  /// 이벤트를 기록합니다.
  ///
  /// [name] 이벤트 이름 (snake_case 권장: 'add_to_cart', 'purchase')
  /// [properties] 이벤트 속성. 모든 값은 String이어야 합니다.
  ///
  /// ```dart
  /// // 장바구니 담기
  /// await AdTrackKit.logEvent('add_to_cart', properties: {
  ///   'product_id':   'P001',
  ///   'product_name': '프리미엄 무선 이어폰',
  ///   'price':        '89000',
  ///   'category':     'electronics',
  /// });
  ///
  /// // 화면 조회 (properties 생략 가능)
  /// await AdTrackKit.logEvent('screen_view');
  /// ```
  static Future<void> logEvent(
    String name, {
    Map<String, String>? properties,
  }) async {
    if (!_isPlatformSupported) return;

    await _channel.invokeMethod<void>('logEvent', <String, dynamic>{
      'name': name,
      'properties': properties ?? <String, String>{},
    });
  }

  // ── Flush ────────────────────────────────────────────────────────────────────

  /// 미전송 이벤트를 즉시 서버로 전송합니다.
  ///
  /// 앱 생명주기 변화(백그라운드 전환) 시 호출을 권장합니다.
  ///
  /// ```dart
  /// // AppLifecycleListener (Flutter 3.13+)
  /// AppLifecycleListener(
  ///   onInactive: () => AdTrackKit.flush(),
  /// );
  /// ```
  static Future<void> flush() async {
    if (!_isPlatformSupported) return;
    await _channel.invokeMethod<void>('flush');
  }

  // ── 내부 유틸리티 ─────────────────────────────────────────────────────────────

  /// 현재 플랫폼이 지원되는지 확인 (iOS 전용 SDK)
  static bool get _isPlatformSupported {
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    debugPrint('[AdTrackKit] 현재 AdTrackKit은 iOS 전용입니다. '
        '플랫폼: $defaultTargetPlatform');
    return false;
  }
}
