/// AdTrackKit Flutter Plugin 예제 앱
///
/// "장바구니 담기" 버튼 클릭 → Dart invokeMethod →
/// Swift handle(_:result:) → ATKTracker.shared.logEvent() 흐름을 보여줍니다.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:adtrackkit_flutter/adtrackkit_flutter.dart';

// ─── 가상 상품 데이터 ─────────────────────────────────────────────────────────
const _product = (
  id: 'P001',
  name: '프리미엄 무선 이어폰',
  emoji: '🎧',
  price: 89000,
  category: 'electronics',
);

// ─── 진입점 ──────────────────────────────────────────────────────────────────
void main() async {
  // Flutter 엔진 초기화 완료 후 SDK 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SDK 초기화 (앱 시작 시 1회)
  await AdTrackKit.initialize(
    appKey: 'demo-flutter-key-789',
    environment: 'development', // Xcode 콘솔에 디버그 로그 출력
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'ATK MALL',
      debugShowCheckedModeBanner: false,
      home: ShopPage(),
    );
  }
}

// ─── 쇼핑몰 메인 화면 ────────────────────────────────────────────────────────
class ShopPage extends StatefulWidget {
  const ShopPage({super.key});

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> with WidgetsBindingObserver {
  String _lastEvent = '(없음)';

  @override
  void initState() {
    super.initState();
    // 앱 생명주기 감시 등록 (백그라운드 전환 시 flush)
    WidgetsBinding.instance.addObserver(this);
    // 화면 진입 이벤트
    AdTrackKit.logEvent('screen_view', properties: {'screen_name': 'ShopMain'});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 2. 앱이 백그라운드로 전환될 때 flush
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      AdTrackKit.flush();
      debugPrint('[App] 백그라운드 전환 → flush() 호출');
    }
  }

  // ─── 이벤트 핸들러 ────────────────────────────────────────────────────────

  Future<void> _handleAddToCart() async {
    try {
      /// 이 한 줄이 Flutter 브릿지 전체를 통과합니다:
      ///
      /// Dart: AdTrackKit.logEvent('add_to_cart', properties: {...})
      ///   → MethodChannel.invokeMethod('logEvent', {'name': ..., 'properties': ...})
      ///     → Flutter Engine (StandardMessageCodec 직렬화)
      ///       → AdTrackKitFlutterPlugin.handle(_ call:result:)
      ///         → ATKTracker.shared.logEvent("add_to_cart", properties: [...])
      ///           → result(nil) → Future<void> 완료
      await AdTrackKit.logEvent('add_to_cart', properties: {
        'product_id': _product.id,
        'product_name': _product.name,
        'price': _product.price.toString(),
        'category': _product.category,
      });

      setState(() => _lastEvent = 'add_to_cart');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ add_to_cart 이벤트가 AdTrackKit에 기록되었습니다.'),
            backgroundColor: Color(0xFF007AFF),
          ),
        );
      }
    } on PlatformException catch (e) {
      // FlutterError → PlatformException 으로 변환되어 전달됨
      debugPrint('[AdTrackKit Error] ${e.code}: ${e.message}');
    }
  }

  Future<void> _handlePurchase() async {
    await AdTrackKit.logEvent('purchase', properties: {
      'product_id': _product.id,
      'price': _product.price.toString(),
      'order_id': 'ORD${DateTime.now().millisecondsSinceEpoch}',
      'payment_pg': 'inicis',
    });
    setState(() => _lastEvent = 'purchase');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ purchase 이벤트가 기록되었습니다.')),
      );
    }
  }

  Future<void> _handleFlush() async {
    await AdTrackKit.flush();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('📡 미전송 이벤트를 즉시 전송했습니다.')),
      );
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text(
          'ATK MALL',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF007AFF),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상품 카드
            _ProductCard(
              emoji: _product.emoji,
              name: _product.name,
              price: _product.price,
            ),
            const SizedBox(height: 16),

            // 브릿지 흐름 패널
            _FlowPanel(lastEvent: _lastEvent),
            const SizedBox(height: 16),

            // 버튼들
            _EventButton(
              label: '🛒 장바구니 담기',
              subtitle: "logEvent('add_to_cart')",
              color: const Color(0xFF007AFF),
              onTap: _handleAddToCart,
            ),
            const SizedBox(height: 10),
            _EventButton(
              label: '💳 구매하기',
              subtitle: "logEvent('purchase')",
              color: const Color(0xFF34C759),
              onTap: _handlePurchase,
            ),
            const SizedBox(height: 10),
            _EventButton(
              label: '📡 flush()',
              subtitle: '미전송 이벤트 즉시 전송',
              color: const Color(0xFFFF9F0A),
              onTap: _handleFlush,
            ),

            const SizedBox(height: 20),
            Text(
              'Xcode 콘솔에서 [AdTrackKit] 로그를 확인하세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 위젯 컴포넌트 ─────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.emoji, required this.name, required this.price});
  final String emoji, name;
  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          '${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF007AFF)),
        ),
      ]),
    );
  }
}

class _FlowPanel extends StatelessWidget {
  const _FlowPanel({required this.lastEvent});
  final String lastEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF1C1C1E), borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('브릿지 흐름', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Dart invokeMethod()\n  → MethodChannel\n    → FlutterPlugin.handle()\n      → ATKTracker.shared',
          style: TextStyle(color: Color(0xFF30D158), fontFamily: 'Courier New', fontSize: 12, height: 1.8),
        ),
        const Divider(color: Color(0xFF3A3A3C), height: 20),
        Text('마지막 이벤트: $lastEvent',
            style: const TextStyle(color: Color(0xFFFFD60A), fontSize: 12, fontFamily: 'Courier New')),
      ]),
    );
  }
}

class _EventButton extends StatelessWidget {
  const _EventButton({required this.label, required this.subtitle, required this.color, required this.onTap});
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Column(children: [
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 12, fontFamily: 'Courier New')),
          ]),
        ),
      ),
    );
  }
}
