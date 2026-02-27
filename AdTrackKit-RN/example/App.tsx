/**
 * AdTrackKit RN 브릿지 예제 앱
 *
 * 실제 React Native 쇼핑 앱에서 AdTrackKit을 사용하는 예시입니다.
 * "장바구니 담기" 버튼 → logEvent('add_to_cart') → iOS ATKTracker 호출 흐름을 보여줍니다.
 */

import React, { useEffect, useCallback } from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  StyleSheet,
  Alert,
  AppState,
  SafeAreaView,
  ScrollView,
} from 'react-native';

// npm install 후 'adtrackkit-rn' 으로 import
// 개발 중에는 상대 경로 사용
import AdTrackKit from '../js/AdTrackKit';

// ─── 가상 상품 데이터 ─────────────────────────────────────────────────────────
const PRODUCT = {
  id: 'P001',
  name: '프리미엄 무선 이어폰',
  emoji: '🎧',
  price: 89_000,
  category: 'electronics',
};

// ─── 앱 컴포넌트 ─────────────────────────────────────────────────────────────
export default function App() {

  // 1. 앱 시작 시 SDK 초기화
  useEffect(() => {
    AdTrackKit.initialize({
      appKey: 'demo-rn-key-456',
      environment: 'development',   // 개발 중에는 'development' (디버그 로그 출력)
    }).then(() => {
      console.log('[App] AdTrackKit 초기화 완료');
    });
  }, []);

  // 2. 앱이 백그라운드로 전환될 때 flush
  useEffect(() => {
    const sub = AppState.addEventListener('change', (nextState) => {
      if (nextState === 'background') {
        AdTrackKit.flush();
        console.log('[App] 백그라운드 전환 → flush() 호출');
      }
    });
    return () => sub.remove();
  }, []);

  // ─── 이벤트 핸들러 ──────────────────────────────────────────────────────────

  // 화면 진입 이벤트
  useEffect(() => {
    AdTrackKit.logEvent('screen_view', { screen_name: 'ProductDetail' });
  }, []);

  // 장바구니 담기 — 브릿지 데모의 핵심
  const handleAddToCart = useCallback(async () => {
    try {
      /**
       * 이 한 줄이 전체 브릿지를 통과합니다:
       *
       * JS (여기)
       *  → NativeModules.AdTrackKit.logEvent(...)  [RCT_EXPORT_METHOD 등록 메서드]
       *    → AdTrackKitModule.m  -[AdTrackKitModule logEvent:properties:resolver:rejecter:]
       *      → [AdTrackKitImpl shared] logEvent:properties:resolver:rejecter:
       *        → ATKTracker.shared.logEvent("add_to_cart", properties:...)  ← iOS SDK 호출
       */
      await AdTrackKit.logEvent('add_to_cart', {
        product_id:   PRODUCT.id,
        product_name: PRODUCT.name,
        price:        String(PRODUCT.price),
        category:     PRODUCT.category,
      });

      Alert.alert(
        '✅ 이벤트 전송',
        'add_to_cart 이벤트가 AdTrackKit iOS SDK에 기록되었습니다.\n\nXcode 콘솔에서 로그를 확인하세요.',
      );
    } catch (error) {
      Alert.alert('오류', String(error));
    }
  }, []);

  // 구매 완료
  const handlePurchase = useCallback(async () => {
    await AdTrackKit.logEvent('purchase', {
      product_id:   PRODUCT.id,
      price:        String(PRODUCT.price),
      order_id:     `ORD${Date.now()}`,
      payment_pg:   'inicis',
    });
    Alert.alert('✅ 이벤트 전송', 'purchase 이벤트가 기록되었습니다.');
  }, []);

  // 즉시 전송 테스트
  const handleFlush = useCallback(() => {
    AdTrackKit.flush();
    Alert.alert('✅ flush()', '미전송 이벤트를 즉시 서버로 전송했습니다.');
  }, []);

  // ─── UI ─────────────────────────────────────────────────────────────────────
  return (
    <SafeAreaView style={styles.safe}>
      <ScrollView contentContainerStyle={styles.container}>

        {/* 헤더 */}
        <Text style={styles.headerTitle}>ATK MALL</Text>
        <Text style={styles.headerSub}>AdTrackKit RN 브릿지 데모</Text>

        {/* 상품 카드 */}
        <View style={styles.card}>
          <Text style={styles.emoji}>{PRODUCT.emoji}</Text>
          <Text style={styles.productName}>{PRODUCT.name}</Text>
          <Text style={styles.productPrice}>
            {PRODUCT.price.toLocaleString()}원
          </Text>
        </View>

        {/* 브릿지 흐름 안내 */}
        <View style={styles.flowBox}>
          <Text style={styles.flowTitle}>브릿지 호출 흐름</Text>
          <Text style={styles.flowText}>
            {'JS logEvent()\n  → RCT_EXPORT_METHOD (.m)\n    → AdTrackKitImpl.swift\n      → ATKTracker.shared'}
          </Text>
        </View>

        {/* 버튼 */}
        <TouchableOpacity style={[styles.btn, styles.btnCart]} onPress={handleAddToCart}>
          <Text style={styles.btnText}>🛒 장바구니 담기</Text>
          <Text style={styles.btnSub}>logEvent("add_to_cart")</Text>
        </TouchableOpacity>

        <TouchableOpacity style={[styles.btn, styles.btnBuy]} onPress={handlePurchase}>
          <Text style={styles.btnText}>💳 구매하기</Text>
          <Text style={styles.btnSub}>logEvent("purchase")</Text>
        </TouchableOpacity>

        <TouchableOpacity style={[styles.btn, styles.btnFlush]} onPress={handleFlush}>
          <Text style={styles.btnText}>📡 flush()</Text>
          <Text style={styles.btnSub}>미전송 이벤트 즉시 전송</Text>
        </TouchableOpacity>

        <Text style={styles.hint}>
          Xcode 콘솔에서 "[AdTrackKit]" 로그를 확인하세요.
        </Text>
      </ScrollView>
    </SafeAreaView>
  );
}

// ─── 스타일 ──────────────────────────────────────────────────────────────────
const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: '#f2f2f7' },
  container: { padding: 24, gap: 16 },

  headerTitle: { fontSize: 28, fontWeight: '900', color: '#007AFF', textAlign: 'center' },
  headerSub:   { fontSize: 13, color: '#8e8e93', textAlign: 'center', marginBottom: 8 },

  card: {
    backgroundColor: '#fff', borderRadius: 20,
    padding: 24, alignItems: 'center',
    shadowColor: '#000', shadowOpacity: 0.06, shadowRadius: 10, shadowOffset: { width: 0, height: 3 },
  },
  emoji:        { fontSize: 56, marginBottom: 12 },
  productName:  { fontSize: 18, fontWeight: '700', color: '#1c1c1e' },
  productPrice: { fontSize: 22, fontWeight: '900', color: '#007AFF', marginTop: 4 },

  flowBox: {
    backgroundColor: '#1c1c1e', borderRadius: 14, padding: 16,
  },
  flowTitle: { color: '#8e8e93', fontSize: 11, fontWeight: '700', marginBottom: 8, textTransform: 'uppercase' },
  flowText:  { color: '#30d158', fontFamily: 'Courier New', fontSize: 13, lineHeight: 22 },

  btn: {
    borderRadius: 16, padding: 18, alignItems: 'center',
    shadowColor: '#000', shadowOpacity: 0.08, shadowRadius: 6, shadowOffset: { width: 0, height: 2 },
  },
  btnCart:  { backgroundColor: '#007AFF' },
  btnBuy:   { backgroundColor: '#34c759' },
  btnFlush: { backgroundColor: '#ff9f0a' },
  btnText:  { color: '#fff', fontSize: 17, fontWeight: '700' },
  btnSub:   { color: 'rgba(255,255,255,0.75)', fontSize: 12, marginTop: 4, fontFamily: 'Courier New' },

  hint: { fontSize: 12, color: '#8e8e93', textAlign: 'center', marginTop: 8 },
});
