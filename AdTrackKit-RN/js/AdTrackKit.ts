/**
 * AdTrackKit React Native SDK — JavaScript/TypeScript 래퍼
 *
 * NativeModules.AdTrackKit (ObjC에서 RCT_EXPORT_MODULE(AdTrackKit)으로 등록된 모듈)을
 * 타입 안전하고 사용하기 편한 인터페이스로 감쌉니다.
 *
 * 직접 NativeModules를 쓰지 않고 이 래퍼를 쓰는 이유:
 *  1. TypeScript 타입 추론 → 자동완성 + 컴파일 오류 조기 발견
 *  2. Platform.OS 분기 → Android 에서도 앱이 크래시 없이 실행
 *  3. 기본값 처리 → properties 없이 logEvent("screen_view") 호출 가능
 */

import { NativeModules, Platform } from 'react-native';

// ─── 네이티브 모듈 타입 ────────────────────────────────────────────────────
// ObjC .m 파일에서 RCT_EXPORT_METHOD로 선언한 메서드들의 타입을 정의합니다.
// 이 타입은 내부 전용 (export 안 함)
interface _NativeAdTrackKit {
  initialize(appKey: string, environment: string): Promise<void>;
  logEvent(name: string, properties: Record<string, string>): Promise<void>;
  flush(): Promise<void>;
}

// RCT_EXPORT_MODULE(AdTrackKit) 으로 등록된 이름과 일치해야 합니다.
const { AdTrackKit: _Native } = NativeModules as {
  AdTrackKit: _NativeAdTrackKit;
};

// 개발 중 모듈 미연결 경고 (pod install 미실행, 재빌드 필요 등)
if (__DEV__ && !_Native) {
  console.warn(
    '[AdTrackKit] 네이티브 모듈을 찾을 수 없습니다.\n' +
      '  • iOS: cd ios && pod install 후 앱을 재빌드하세요.\n' +
      '  • 현재 AdTrackKit은 iOS 전용입니다.'
  );
}

// ─── 공개 타입 정의 ─────────────────────────────────────────────────────────

/** SDK 초기화 옵션 */
export interface AdTrackKitConfig {
  /** 앱 식별 키 (서비스별 발급) */
  appKey: string;
  /**
   * 실행 환경
   * - 'development': 디버그 로그 활성화, 개발 서버 사용
   * - 'production' : 로그 비활성화, 운영 서버 사용 (기본값)
   */
  environment?: 'production' | 'development';
}

/** AdTrackKit SDK 공개 인터페이스 */
export interface AdTrackKitInterface {
  /**
   * SDK를 초기화합니다. 앱 시작 시 1회 호출하세요.
   * @example
   * // App.tsx useEffect 또는 앱 진입점에서
   * await AdTrackKit.initialize({ appKey: 'my-key', environment: 'development' });
   */
  initialize(config: AdTrackKitConfig): Promise<void>;

  /**
   * 이벤트를 기록합니다.
   * @param name    이벤트 이름 (snake_case 권장: 'add_to_cart', 'purchase')
   * @param properties 이벤트 속성 { key: string, value: string } 형태
   * @example
   * // 장바구니 담기
   * await AdTrackKit.logEvent('add_to_cart', {
   *   product_id: 'P001',
   *   product_name: '프리미엄 무선 이어폰',
   *   price: '89000',
   *   category: 'electronics',
   * });
   *
   * // 화면 조회
   * await AdTrackKit.logEvent('screen_view', { screen_name: 'ProductDetail' });
   */
  logEvent(name: string, properties?: Record<string, string>): Promise<void>;

  /**
   * 미전송 이벤트를 즉시 서버로 전송합니다.
   * AppState 'background' 감지 시 호출을 권장합니다.
   * @example
   * AppState.addEventListener('change', state => {
   *   if (state === 'background') AdTrackKit.flush();
   * });
   */
  flush(): Promise<void>;
}

// ─── SDK 구현체 ──────────────────────────────────────────────────────────────

const AdTrackKit: AdTrackKitInterface = {
  initialize({ appKey, environment = 'production' }: AdTrackKitConfig): Promise<void> {
    if (Platform.OS !== 'ios') {
      // 현재 iOS 전용 SDK. Android 지원 추가 시 이 분기를 확장하세요.
      return Promise.resolve();
    }
    return _Native.initialize(appKey, environment);
  },

  logEvent(name: string, properties: Record<string, string> = {}): Promise<void> {
    if (Platform.OS !== 'ios') {
      return Promise.resolve();
    }
    return _Native.logEvent(name, properties);
  },

  flush(): Promise<void> {
    if (Platform.OS !== 'ios') {
      return Promise.resolve();
    }
    return _Native.flush();
  },
};

export default AdTrackKit;
