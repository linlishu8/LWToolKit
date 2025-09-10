/*
  作用：最小化 SwiftUI 示例视图，内嵌 WKWebView 并注册 YXTBridge 与 UserPlugin。
  使用示例：
    struct ContentView: View { var body: some View { BridgeDemoView() } }
  特点/注意事项：
    - 为演示方便，加载本地 index.html；替换为你的 http://192.168.0.15:5173/facilityCategory 也可。
*/
import SwiftUI
import WebKit
import LWToolKit

struct BridgeDemoView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject { var bridge: LWWebBridge? }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: config)

        // Bridge
        let bridge = LWWebBridge(webView: web, config: .init(
            allowedHosts: ["localhost", "127.0.0.1", "192.168.0.15"],
            logger: .print
        ))
        context.coordinator.bridge = bridge   // ← 关键：强引用保存
        let providers = LWUserPlugin.Providers(
            accessToken: { "yourAccessToken" },
            refreshToken: { "yourRefreshToken" },
            userId: { "u_123" },
            userType: { "member" },
            deviceOS: { "iOS" },
            appVersion: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" },
            acceptLanguage: { Locale.preferredLanguages.first ?? "zh-CN" }
        )
        bridge.register(plugin: LWUserPlugin(providers: providers))

        // Load local demo html
        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
