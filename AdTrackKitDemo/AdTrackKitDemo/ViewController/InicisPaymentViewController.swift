//
//  InicisPaymentViewController.swift
//  AdTrackKitDemo
//
//  KG이니시스 결제 화면
//  - WKWebView 기반 결제 페이지 로드
//  - WKNavigationDelegate: 커스텀 URL 스킴(카드사 앱) 분기 처리
//  - WKUIDelegate: 팝업(새 창) 처리
//

import UIKit
import WebKit
import AdTrackKit

final class InicisPaymentViewController: UIViewController {

    // MARK: - KG이니시스 테스트 설정
    // 실 서비스 전환 시 서버에서 서명(signature) 생성 후 MID(상점 ID)를 교체.
    private enum InicisConfig {
        static let testMID = "INIpayTest"
        static let payURL = "https://mobile.inicis.com/smart/payment/"
        /// 결제 완료 후 이니시스가 리디렉션할 커스텀 URL 스킴 (Info.plist CFBundleURLTypes 에 등록)
        static let returnScheme = "atkmall"
        static let returnURL = "atkmall://payment/result"
    }

    // MARK: - Properties

    private let product: Product
    private let orderId: String

    /// WKWebView 팝업(새 창) 처리용 하위 WebView
    private var popupWebView: WKWebView?

    // MARK: - Views

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        // 일부 카드사 인증창이 window.open()으로 열리므로 허용
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        // 인라인 미디어 재생 (일부 결제 페이지에서 필요)
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate         = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        return wv
    }()

    // 상단 로딩 프로그레스 바
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .bar)
        pv.progressTintColor = .systemBlue
        pv.trackTintColor    = .clear
        pv.translatesAutoresizingMaskIntoConstraints = false
        return pv
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .large)
        ai.color = .systemBlue
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()

    // KVO 관찰 토큰 (estimatedProgress)
    private var progressObservation: NSKeyValueObservation?

    // MARK: - Init

    init(product: Product) {
        self.product = product
        // 주문번호 생성: ORD + 타임스탬프
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        self.orderId = "ORD\(formatter.string(from: Date()))"
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigation()
        setupLayout()
        setupProgressObservation()
        loadPaymentPage()
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - Setup

    private func setupNavigation() {
        title = "결제하기"
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
    }

    private func setupLayout() {
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            // WebView: safe area 상단 ~ 화면 하단 (결제 페이지는 풀스크린)
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 프로그레스 바: WebView 최상단
            progressView.topAnchor.constraint(equalTo: webView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            // 스피너: 중앙
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupProgressObservation() {
        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] webView, _ in
            guard let self else { return }
            let progress = Float(webView.estimatedProgress)
            self.progressView.setProgress(progress, animated: true)
            self.progressView.isHidden = progress >= 1.0
            if progress >= 1.0 {
                // 잠시 후 숨기며 0으로 리셋 (다음 로딩을 위해)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.progressView.isHidden = true
                    self.progressView.setProgress(0, animated: false)
                }
            }
        }
    }

    // MARK: - Payment Page Load

    private func loadPaymentPage() {
        activityIndicator.startAnimating()
        let html = buildPaymentHTML()
        // baseURL 을 이니시스 도메인으로 설정해 same-origin 제한 완화
        webView.loadHTMLString(html, baseURL: URL(string: "https://mobile.inicis.com"))
    }

    // MARK: - HTML Builder

    private func buildPaymentHTML() -> String {
        let amount      = product.price
        let productName = product.name.prefix(40) // 이니시스 상품명 길이 제한
        let buyerName   = "홍길동"
        let buyerTel    = "01012345678"
        let buyerEmail  = "buyer@atkmall.com"

        return """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <title>결제</title>
            <style>
                *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                    font-family: -apple-system, 'Apple SD Gothic Neo', sans-serif;
                    background: #f2f2f7;
                    min-height: 100vh;
                }
                .container { max-width: 480px; margin: 0 auto; padding: 20px 16px 40px; }

                /* 헤더 */
                .pg-header {
                    display: flex; align-items: center; justify-content: space-between;
                    background: #fff; border-radius: 16px;
                    padding: 16px 20px; margin-bottom: 12px;
                    box-shadow: 0 1px 4px rgba(0,0,0,.06);
                }
                .pg-logo { display: flex; align-items: center; gap: 8px; }
                .pg-logo-text { font-size: 18px; font-weight: 800; color: #E31E24; }
                .pg-logo-sub  { font-size: 11px; color: #aaa; }
                .secure-badge {
                    background: #e8f5e9; color: #2e7d32;
                    font-size: 11px; font-weight: 700;
                    padding: 4px 10px; border-radius: 20px;
                    display: flex; align-items: center; gap: 4px;
                }

                /* 카드 공통 */
                .card {
                    background: #fff; border-radius: 16px;
                    padding: 20px; margin-bottom: 12px;
                    box-shadow: 0 1px 4px rgba(0,0,0,.06);
                }
                .card-title {
                    font-size: 13px; font-weight: 600;
                    color: #8e8e93; margin-bottom: 14px;
                    text-transform: uppercase; letter-spacing: .5px;
                }

                /* 상품 행 */
                .product-row { display: flex; align-items: center; gap: 14px; }
                .product-emoji {
                    font-size: 42px; width: 64px; height: 64px;
                    background: #f2f2f7; border-radius: 14px;
                    display: flex; align-items: center; justify-content: center;
                    flex-shrink: 0;
                }
                .product-name { font-size: 16px; font-weight: 600; color: #1c1c1e; }
                .product-price { font-size: 22px; font-weight: 800; color: #007AFF; margin-top: 4px; }

                /* 주문 정보 행 */
                .info-row {
                    display: flex; justify-content: space-between; align-items: center;
                    padding: 10px 0; border-bottom: 1px solid #f2f2f7;
                }
                .info-row:last-child { border-bottom: none; }
                .info-label { font-size: 14px; color: #8e8e93; }
                .info-value { font-size: 14px; font-weight: 500; color: #1c1c1e; }
                .info-value.mono { font-family: 'Courier New', monospace; font-size: 12px; color: #3c3c43; }

                /* 합계 행 */
                .total-row {
                    display: flex; justify-content: space-between; align-items: center;
                    padding-top: 14px; margin-top: 4px;
                    border-top: 1px solid #e5e5ea;
                }
                .total-label { font-size: 16px; font-weight: 700; }
                .total-value { font-size: 24px; font-weight: 900; color: #007AFF; }

                /* 결제 수단 선택 */
                .method-grid {
                    display: grid; grid-template-columns: 1fr 1fr;
                    gap: 8px; margin-top: 4px;
                }
                .method-btn {
                    padding: 12px 8px; background: #f2f2f7;
                    border: 2px solid transparent; border-radius: 12px;
                    font-size: 14px; font-weight: 600; color: #1c1c1e;
                    cursor: pointer; text-align: center;
                    transition: all .15s;
                }
                .method-btn.selected {
                    border-color: #007AFF; background: #e8f0fe;
                    color: #007AFF;
                }

                /* 결제하기 버튼 */
                .pay-btn {
                    display: block; width: 100%;
                    padding: 18px; margin-top: 8px;
                    background: #007AFF; color: #fff;
                    border: none; border-radius: 16px;
                    font-size: 18px; font-weight: 800;
                    cursor: pointer; letter-spacing: -.3px;
                    -webkit-appearance: none;
                }
                .pay-btn:active { background: #005ecb; transform: scale(0.99); }

                /* 안내 문구 */
                .notice {
                    font-size: 12px; color: #aeaeb2;
                    text-align: center; line-height: 1.7;
                    margin-top: 16px;
                }
                .notice a { color: #007AFF; text-decoration: none; }
            </style>
        </head>
        <body>
        <div class="container">

            <!-- PG사 헤더 -->
            <div class="pg-header">
                <div class="pg-logo">
                    <div class="pg-logo-text">KG이니시스</div>
                    <div class="pg-logo-sub">안전결제</div>
                </div>
                <div class="secure-badge">🔒 SSL 보안</div>
            </div>

            <!-- 주문 상품 -->
            <div class="card">
                <div class="card-title">주문 상품</div>
                <div class="product-row">
                    <div class="product-emoji">\(product.emoji)</div>
                    <div>
                        <div class="product-name">\(productName)</div>
                        <div class="product-price">\(formatPrice(amount))원</div>
                    </div>
                </div>
            </div>

            <!-- 주문 정보 -->
            <div class="card">
                <div class="card-title">주문 정보</div>
                <div class="info-row">
                    <span class="info-label">주문번호</span>
                    <span class="info-value mono">\(orderId)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">주문자</span>
                    <span class="info-value">\(buyerName)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">연락처</span>
                    <span class="info-value">\(formatPhoneNumber(buyerTel))</span>
                </div>
                <div class="info-row">
                    <span class="info-label">이메일</span>
                    <span class="info-value">\(buyerEmail)</span>
                </div>
                <div class="total-row">
                    <span class="total-label">결제금액</span>
                    <span class="total-value">\(formatPrice(amount))원</span>
                </div>
            </div>

            <!-- 결제 수단 -->
            <div class="card">
                <div class="card-title">결제 수단</div>
                <div class="method-grid">
                    <div class="method-btn selected" onclick="selectMethod(this, 'CARD')">💳 신용카드</div>
                    <div class="method-btn" onclick="selectMethod(this, 'VBANK')">🏦 가상계좌</div>
                    <div class="method-btn" onclick="selectMethod(this, 'BANK')">💸 계좌이체</div>
                    <div class="method-btn" onclick="selectMethod(this, 'MOBILE')">📱 휴대폰결제</div>
                </div>
            </div>

            <!-- 결제하기 폼 -->
            <!-- ⚠️ 실 서비스 전환 시: 서버에서 signKey·timestamp·signature 생성 후 교체 필요 -->
            <form id="payForm" method="POST" action="\(InicisConfig.payURL)">
                <input type="hidden" name="P_INI_PAYMENT" id="P_INI_PAYMENT" value="CARD">
                <input type="hidden" name="P_MID"         value="\(InicisConfig.testMID)">
                <input type="hidden" name="P_OID"         value="\(orderId)">
                <input type="hidden" name="P_AMT"         value="\(amount)">
                <input type="hidden" name="P_GOODS"       value="\(productName)">
                <input type="hidden" name="P_UNAME"       value="\(buyerName)">
                <input type="hidden" name="P_MOBILE"      value="\(buyerTel)">
                <input type="hidden" name="P_EMAIL"       value="\(buyerEmail)">
                <input type="hidden" name="P_NEXT_URL"    value="\(InicisConfig.returnURL)">
                <input type="hidden" name="P_NOTI_URL"    value="https://atkmall.example.com/payment/notify">
                <input type="hidden" name="P_CHARSET"     value="UTF-8">
                <!-- apprun_check=Y: 카드사 앱 실행 여부 체크 활성화 -->
                <input type="hidden" name="P_RESERVED"    value="below1000=Y&vbank_receipt=Y&apprun_check=Y">
                <button type="submit" class="pay-btn">💳 결제하기</button>
            </form>

            <p class="notice">
                결제 정보는 KG이니시스 보안 서버를 통해 암호화 처리됩니다.<br>
                카드사 앱이 설치되어 있지 않으면 앱스토어로 이동합니다.<br>
                <a href="#">개인정보 처리방침</a> · <a href="#">이용약관</a>
            </p>
        </div>

        <script>
            var selectedPayment = 'CARD';
            function selectMethod(el, type) {
                document.querySelectorAll('.method-btn').forEach(function(b) {
                    b.classList.remove('selected');
                });
                el.classList.add('selected');
                selectedPayment = type;
                document.getElementById('P_INI_PAYMENT').value = type;
            }
        </script>
        </body>
        </html>
        """
    }

    // MARK: - Formatters

    private func formatPrice(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatPhoneNumber(_ tel: String) -> String {
        guard tel.count == 11 else { return tel }
        return "\(tel.prefix(3))-\(tel.dropFirst(3).prefix(4))-\(tel.suffix(4))"
    }

    // MARK: - Payment Result Handling

    private func handlePaymentCallback(url: URL) {
        // atkmall://payment/result?P_STATUS=00&P_TID=...&P_AMT=...
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = components?.queryItems?.reduce(into: [String: String]()) { dict, item in
            dict[item.name] = item.value ?? ""
        } ?? [:]

        let statusCode = params["P_STATUS"] ?? ""
        let message    = params["P_RMESG1"] ?? params["P_RMESG2"] ?? ""
        let tid        = params["P_TID"] ?? ""

        DispatchQueue.main.async { [weak self] in
            if statusCode == "00" {
                self?.showPaymentSuccess(tid: tid)
            } else {
                self?.showPaymentFailure(message: message)
            }
        }
    }

    private func showPaymentSuccess(tid: String) {
        ATKTracker.shared.logEvent("purchase", properties: [
            "product_id":     product.id,
            "product_name":   product.name,
            "price":          "\(product.price)",
            "order_id":       orderId,
            "transaction_id": tid,
            "payment_pg":     "inicis"
        ])

        let alert = UIAlertController(
            title: "결제 완료 ✓",
            message: "결제가 완료되었습니다.\n주문번호: \(orderId)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "쇼핑 계속하기", style: .default) { [weak self] _ in
            self?.navigationController?.popToRootViewController(animated: true)
        })
        present(alert, animated: true)
    }

    private func showPaymentFailure(message: String) {
        ATKTracker.shared.logEvent("payment_failed", properties: [
            "product_id": product.id,
            "order_id":   orderId,
            "reason":     message
        ])

        let alert = UIAlertController(
            title: "결제 실패",
            message: message.isEmpty ? "결제가 취소되었습니다." : message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "오류", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension InicisPaymentViewController: WKNavigationDelegate {

    /// 네비게이션 정책 결정 (커스텀 URL 스킴 처리 핵심 메서드)
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        let scheme = url.scheme?.lowercased() ?? ""

        // ── 1) 일반 웹 네비게이션: 허용 ───────────────────────────────
        if scheme == "http" || scheme == "https" {
            decisionHandler(.allow)
            return
        }

        // ── 2) about:blank / about:srcdoc: 팝업 초기 로드 허용 ────────
        if scheme == "about" {
            decisionHandler(.allow)
            return
        }

        // ── 3) 자체 앱 커스텀 스킴: 결제 결과 수신 ────────────────────
        if scheme == InicisConfig.returnScheme {
            decisionHandler(.cancel)
            handlePaymentCallback(url: url)
            return
        }

        // ── 4) 그 외 커스텀 URL 스킴: 카드사 앱 / 외부 앱 실행 ────────
        // 웹뷰 네비게이션을 취소하고 UIApplication으로 외부 앱을 실행합니다.
        decisionHandler(.cancel)

        UIApplication.shared.open(url, options: [:]) { [weak self] success in
            if !success {
                // 앱이 설치되어 있지 않을 경우 – App Store 이동 시도
                if let appStoreURL = Self.appStoreURL(for: scheme) {
                    UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                } else {
                    print("[InicisPayment] 처리 불가 URL: \(url.absoluteString)")
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
        progressView.isHidden = false
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        // NSURLErrorCancelled(-999): decidePolicyFor에서 .cancel 반환 시 정상적으로 발생 → 무시
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        showErrorAlert(message: error.localizedDescription)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        showErrorAlert(message: error.localizedDescription)
    }

    // MARK: - App Store URL 매핑

    /// 커스텀 URL 스킴 → App Store URL 매핑 (대표 카드사/간편결제 앱)
    private static func appStoreURL(for scheme: String) -> URL? {
        // key: URL 스킴, value: App Store 앱 ID
        let appStoreIDs: [String: String] = [
            "kftc-bankpay":                "398456030",   // 금융결제원 뱅크페이
            "ispmobile":                   "369125063",   // ISP/페이북
            "kakaopay":                    "1386763681",  // 카카오페이
            "supertoss":                   "839333328",   // 토스
            "naverpaycoin":                "820738831",   // 네이버페이
            "kb-acp":                      "695436326",   // KB국민카드 앱카드
            "shinhan-sr-ansimclick":        "572462317",   // 신한카드 앱카드
            "lottesmartpay":               "668497947",   // 롯데 스마트페이
            "lotteappcard":                "688047200",   // 롯데 앱카드
            "hanacard-ansimclick":         "847268987",   // 하나카드 1Q페이
            "hdcardappcardansimclick":     "702653088",   // 현대카드
            "cloudpay":                    "1179654683",  // 하나카드 클라우드페이
            "lguthepay-xpay":              "668577841",   // LG U+ 페이나우
            "mpocket.online.ansimclick":   "441084182",   // 삼성카드 안심클릭
        ]

        guard let appID = appStoreIDs[scheme] else { return nil }
        return URL(string: "https://apps.apple.com/kr/app/id\(appID)")
    }
}

// MARK: - WKUIDelegate

extension InicisPaymentViewController: WKUIDelegate {

    /// window.open() 등 새 창 요청 처리 (일부 카드사 인증 팝업에서 사용)
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // target="_blank" 등 targetFrame이 nil인 경우 → 현재 WebView에서 로드
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    /// JavaScript alert() 처리
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
            completionHandler()
        })
        present(alert, animated: true)
    }

    /// JavaScript confirm() 처리
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }
}
