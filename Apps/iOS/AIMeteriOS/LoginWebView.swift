import SwiftUI
import WebKit

/// In-app Cursor login. Desktop UA + cookie observer so iOS does not hand the
/// session off to the Cursor app via a universal link.
struct LoginWebView: UIViewRepresentable {
    var onToken: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = Self.desktopUserAgent
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.start(webView: webView)
        webView.load(URLRequest(url: URL(string: "https://cursor.com/dashboard")!))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        coordinator.stop(webView: uiView)
    }

    private static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        let onToken: (String) -> Void
        private var captured = false
        private var poll: Timer?
        private weak var webView: WKWebView?

        init(onToken: @escaping (String) -> Void) {
            self.onToken = onToken
        }

        func start(webView: WKWebView) {
            self.webView = webView
            webView.configuration.websiteDataStore.httpCookieStore.add(self)
            poll = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                guard let webView = self?.webView else { return }
                self?.captureCookie(from: webView)
            }
        }

        func stop(webView: WKWebView) {
            poll?.invalidate()
            poll = nil
            webView.configuration.websiteDataStore.httpCookieStore.remove(self)
            self.webView = nil
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            guard let webView else { return }
            captureCookie(from: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            captureCookie(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            captureCookie(from: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            captureCookie(from: webView)

            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let scheme = url.scheme?.lowercased() ?? ""
            if !Self.inWebViewSchemes.contains(scheme) {
                decisionHandler(.cancel)
                return
            }

            // target=_blank / universal-link handoff — stay in this web view.
            if navigationAction.targetFrame == nil {
                webView.load(URLRequest(url: url))
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        private func captureCookie(from webView: WKWebView) {
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                guard !self.captured,
                      let cookie = cookies.first(where: { $0.name == "WorkosCursorSessionToken" })
                else { return }
                self.captured = true
                self.poll?.invalidate()
                self.poll = nil
                DispatchQueue.main.async {
                    self.onToken(cookie.value)
                }
            }
        }

        private static let inWebViewSchemes: Set<String> = ["http", "https", "about", "blob", "data"]
    }
}
