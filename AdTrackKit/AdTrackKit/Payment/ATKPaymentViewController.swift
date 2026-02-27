//
//  ATKPaymentViewController.swift
//  AdTrackKit
//
//  KG이니시스 결제 화면 (SDK 내부 전용 — external: ATKTracker.presentPayment()).
//
//  ┌── 외부 앱 ─────────────────────────────────────────────────┐
//  │  ATKTracker.shared.presentPayment(config:from:completion:) │
//  └──────────────────────────┬─────────────────────────────────┘
//                             │ SDK가 내부적으로 생성
//                             ▼
//  ┌── ATKPaymentViewController (internal) ─────────────────────┐
//  │  WKWebView + WKNavigationDelegate + WKUIDelegate           │
//  │  ┌────────────────────────────────────────────────────┐    │
//  │  │  decidePolicyFor(navigationAction:)                │    │
//  │  │  http/https  → .allow                             │    │
//  │  │  {returnScheme}:// → .cancel + handleCallback()   │    │
//  │  │  그 외 커스텀 스킴  → .cancel + UIApplication.open │    │
//  │  └────────────────────────────────────────────────────┘    │
//  └───────────────────────────────────────────────────────────-┘

import UIKit
import WebKit

// MARK: - ATKPaymentViewController

/// KG이니시스 결제를 처리하는 SDK 내부 WKWebView 컨트롤러.
/// 외부에서 직접 사용하지 않고, `ATKTracker.shared.presentPayment()`를 통해 간접 사용합니다.
final class ATKPaymentViewController: UIViewController {

    // MARK: - Properties

    private let configuration: ATKPaymentConfiguration
    private let completion: (ATKPaymentResult) -> Void

    private let orderId: String

    /// WKWebView 팝업(새 창) 처리용 하위 WebView
    private var popupWebView: WKWebView?

    // MARK: - Views

    private lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate         = self
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        return wv
    }()

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

    private var progressObservation: NSKeyValueObservation?

    // MARK: - Init

    init(configuration: ATKPaymentConfiguration, completion: @escaping (ATKPaymentResult) -> Void) {
        self.configuration = configuration
        self.completion    = completion

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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
    }

    private func setupLayout() {
        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(activityIndicator)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: webView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupProgressObservation() {
        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
            guard let self else { return }
            let progress = Float(wv.estimatedProgress)
            self.progressView.setProgress(progress, animated: true)
            if progress >= 1.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.progressView.isHidden = true
                    self.progressView.setProgress(0, animated: false)
                }
            } else {
                self.progressView.isHidden = false
            }
        }
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true) { [weak self] in
            self?.completion(.cancelled)
        }
    }

    // MARK: - Payment Page Load

    private func loadPaymentPage() {
        activityIndicator.startAnimating()
        webView.loadHTMLString(
            buildPaymentHTML(),
            baseURL: URL(string: "https://mobile.inicis.com")
        )
    }

    // MARK: - HTML Builder

    private func buildPaymentHTML() -> String {
        let amount      = configuration.price
        let productName = String(configuration.productName.prefix(40))
        let buyerName   = configuration.buyerName
        let buyerTel    = configuration.buyerTel
        let buyerEmail  = configuration.buyerEmail
        let mid         = configuration.mid
        let returnURL   = "\(configuration.returnScheme)://payment/result"

        return """
        <!DOCTYPE html>
        <html lang="ko">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <title>결제</title>
            <style>
                *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
                body { font-family: -apple-system, 'Apple SD Gothic Neo', sans-serif;
                       background: #f2f2f7; min-height: 100vh; }
                .container { max-width: 480px; margin: 0 auto; padding: 20px 16px 40px; }
                .pg-header { display: flex; align-items: center; justify-content: space-between;
                             background: #fff; border-radius: 16px; padding: 16px 20px;
                             margin-bottom: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
                .pg-logo-text { font-size: 18px; font-weight: 800; color: #E31E24; }
                .pg-logo-sub  { font-size: 11px; color: #aaa; }
                .secure-badge { background: #e8f5e9; color: #2e7d32; font-size: 11px;
                                font-weight: 700; padding: 4px 10px; border-radius: 20px; }
                .card { background: #fff; border-radius: 16px; padding: 20px;
                        margin-bottom: 12px; box-shadow: 0 1px 4px rgba(0,0,0,.06); }
                .card-title { font-size: 13px; font-weight: 600; color: #8e8e93;
                              margin-bottom: 14px; text-transform: uppercase; }
                .product-row { display: flex; align-items: center; gap: 14px; }
                .product-emoji { font-size: 42px; width: 64px; height: 64px;
                                 background: #f2f2f7; border-radius: 14px;
                                 display: flex; align-items: center; justify-content: center; }
                .product-name  { font-size: 16px; font-weight: 600; }
                .product-price { font-size: 22px; font-weight: 800; color: #007AFF; margin-top: 4px; }
                .info-row { display: flex; justify-content: space-between;
                            padding: 10px 0; border-bottom: 1px solid #f2f2f7; }
                .info-row:last-child { border-bottom: none; }
                .info-label { font-size: 14px; color: #8e8e93; }
                .info-value  { font-size: 14px; font-weight: 500; }
                .total-row   { display: flex; justify-content: space-between;
                               padding-top: 14px; margin-top: 4px; border-top: 1px solid #e5e5ea; }
                .total-label { font-size: 16px; font-weight: 700; }
                .total-value { font-size: 24px; font-weight: 900; color: #007AFF; }
                .method-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
                .method-btn  { padding: 12px 8px; background: #f2f2f7;
                               border: 2px solid transparent; border-radius: 12px;
                               font-size: 14px; font-weight: 600; cursor: pointer; text-align: center; }
                .method-btn.selected { border-color: #007AFF; background: #e8f0fe; color: #007AFF; }
                .pay-btn { display: block; width: 100%; padding: 18px; margin-top: 8px;
                           background: #007AFF; color: #fff; border: none; border-radius: 16px;
                           font-size: 18px; font-weight: 800; cursor: pointer; -webkit-appearance: none; }
                .notice { font-size: 12px; color: #aeaeb2; text-align: center;
                          line-height: 1.7; margin-top: 16px; }
            </style>
        </head>
        <body>
        <div class="container">
            <div class="pg-header">
                <div>
                    <div class="pg-logo-text">KG이니시스</div>
                    <div class="pg-logo-sub">안전결제</div>
                </div>
                <div class="secure-badge">🔒 SSL 보안</div>
            </div>

            <div class="card">
                <div class="card-title">주문 상품</div>
                <div class="product-row">
                    <div class="product-emoji">\(configuration.productEmoji)</div>
                    <div>
                        <div class="product-name">\(productName)</div>
                        <div class="product-price">\(formatPrice(amount))원</div>
                    </div>
                </div>
            </div>

            <div class="card">
                <div class="card-title">주문 정보</div>
                <div class="info-row">
                    <span class="info-label">주문번호</span>
                    <span class="info-value">\(orderId)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">주문자</span>
                    <span class="info-value">\(buyerName)</span>
                </div>
                <div class="info-row">
                    <span class="info-label">연락처</span>
                    <span class="info-value">\(formatPhone(buyerTel))</span>
                </div>
                <div class="total-row">
                    <span class="total-label">결제금액</span>
                    <span class="total-value">\(formatPrice(amount))원</span>
                </div>
            </div>

            <div class="card">
                <div class="card-title">결제 수단</div>
                <div class="method-grid">
                    <div class="method-btn selected" onclick="selectMethod(this,'CARD')">💳 신용카드</div>
                    <div class="method-btn" onclick="selectMethod(this,'VBANK')">🏦 가상계좌</div>
                    <div class="method-btn" onclick="selectMethod(this,'BANK')">💸 계좌이체</div>
                    <div class="method-btn" onclick="selectMethod(this,'MOBILE')">📱 휴대폰결제</div>
                </div>
            </div>

            <form id="payForm" method="POST" action="https://mobile.inicis.com/smart/payment/">
                <input type="hidden" name="P_INI_PAYMENT" id="P_INI_PAYMENT" value="CARD">
                <input type="hidden" name="P_MID"      value="\(mid)">
                <input type="hidden" name="P_OID"      value="\(orderId)">
                <input type="hidden" name="P_AMT"      value="\(amount)">
                <input type="hidden" name="P_GOODS"    value="\(productName)">
                <input type="hidden" name="P_UNAME"    value="\(buyerName)">
                <input type="hidden" name="P_MOBILE"   value="\(buyerTel)">
                <input type="hidden" name="P_EMAIL"    value="\(buyerEmail)">
                <input type="hidden" name="P_NEXT_URL" value="\(returnURL)">
                <input type="hidden" name="P_CHARSET"  value="UTF-8">
                <input type="hidden" name="P_RESERVED" value="below1000=Y&vbank_receipt=Y&apprun_check=Y">
                <button type="submit" class="pay-btn">💳 결제하기</button>
            </form>

            <p class="notice">
                결제 정보는 KG이니시스 보안 서버를 통해 암호화 처리됩니다.<br>
                카드사 앱이 설치되어 있지 않으면 앱스토어로 이동합니다.
            </p>
        </div>
        <script>
            function selectMethod(el, type) {
                document.querySelectorAll('.method-btn').forEach(function(b){ b.classList.remove('selected'); });
                el.classList.add('selected');
                document.getElementById('P_INI_PAYMENT').value = type;
            }
        </script>
        </body></html>
        """
    }

    // MARK: - Formatters

    private func formatPrice(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatPhone(_ tel: String) -> String {
        guard tel.count == 11 else { return tel }
        return "\(tel.prefix(3))-\(tel.dropFirst(3).prefix(4))-\(tel.suffix(4))"
    }

    // MARK: - Payment Callback

    private func handlePaymentCallback(url: URL) {
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .reduce(into: [String: String]()) { $0[$1.name] = $1.value ?? "" } ?? [:]

        let statusCode = params["P_STATUS"] ?? ""
        let message    = params["P_RMESG1"] ?? params["P_RMESG2"] ?? ""
        let tid        = params["P_TID"] ?? ""

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if statusCode == "00" {
                // 결제 성공 → ATKTracker에 이벤트 자동 기록
                ATKTracker.shared.logEvent("purchase", properties: [
                    "product_id":     self.configuration.productId,
                    "product_name":   self.configuration.productName,
                    "price":          "\(self.configuration.price)",
                    "order_id":       self.orderId,
                    "transaction_id": tid,
                    "payment_pg":     "inicis"
                ])
                let result = ATKPaymentResult.success(orderId: self.orderId, transactionId: tid)
                self.showSuccessAlert(result: result)
            } else {
                ATKTracker.shared.logEvent("payment_failed", properties: [
                    "product_id": self.configuration.productId,
                    "order_id":   self.orderId,
                    "reason":     message
                ])
                self.showFailureAlert(message: message)
            }
        }
    }

    private func showSuccessAlert(result: ATKPaymentResult) {
        guard case .success(let orderId, _) = result else { return }
        let alert = UIAlertController(
            title: "결제 완료 ✓",
            message: "결제가 완료되었습니다.\n주문번호: \(orderId)",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.completion(result)
            }
        })
        present(alert, animated: true)
    }

    private func showFailureAlert(message: String) {
        let alert = UIAlertController(
            title: "결제 실패",
            message: message.isEmpty ? "결제가 취소되었습니다." : message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
            let result = ATKPaymentResult.failure(message: message)
            self?.completion(result)
        })
        present(alert, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension ATKPaymentViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        let scheme = url.scheme?.lowercased() ?? ""

        // ── 1) 일반 웹 네비게이션 ─────────────────────────
        if scheme == "http" || scheme == "https" { decisionHandler(.allow); return }

        // ── 2) about:blank / about:srcdoc ─────────────────
        if scheme == "about" { decisionHandler(.allow); return }

        // ── 3) 앱 커스텀 스킴 — 결제 결과 수신 ──────────────
        if scheme == configuration.returnScheme {
            decisionHandler(.cancel)
            handlePaymentCallback(url: url)
            return
        }

        // ── 4) 그 외 커스텀 스킴 — 카드사 앱 실행 ────────────
        decisionHandler(.cancel)
        UIApplication.shared.open(url, options: [:]) { success in
            if !success, let storeURL = Self.appStoreURL(for: scheme) {
                UIApplication.shared.open(storeURL, options: [:], completionHandler: nil)
            }
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        let alert = UIAlertController(title: "오류", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        activityIndicator.stopAnimating()
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        let alert = UIAlertController(title: "오류", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - App Store URL 매핑

    private static func appStoreURL(for scheme: String) -> URL? {
        let ids: [String: String] = [
            "kftc-bankpay":              "398456030",
            "ispmobile":                 "369125063",
            "kakaopay":                  "1386763681",
            "supertoss":                 "839333328",
            "naverpaycoin":              "820738831",
            "kb-acp":                    "695436326",
            "shinhan-sr-ansimclick":     "572462317",
            "lottesmartpay":             "668497947",
            "lotteappcard":              "688047200",
            "hanacard-ansimclick":       "847268987",
            "hdcardappcardansimclick":   "702653088",
            "cloudpay":                  "1179654683",
            "lguthepay-xpay":            "668577841",
            "mpocket.online.ansimclick": "441084182",
        ]
        guard let appID = ids[scheme] else { return nil }
        return URL(string: "https://apps.apple.com/kr/app/id\(appID)")
    }
}

// MARK: - WKUIDelegate

extension ATKPaymentViewController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in completionHandler(true) })
        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { _ in completionHandler(false) })
        present(alert, animated: true)
    }
}
