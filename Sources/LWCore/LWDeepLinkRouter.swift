import Foundation

/**
 LWDeepLinkRouter
 ----------------
 作用：
 一个**简单可扩展的深链路由器**。按 URL 的 `host` 进行分发，向外暴露统一的
 `Handler` 回调（`(URL, [String:String]) -> Bool`）。支持注册/撤销路由、
 线程安全、便捷的字符串打开与可打开性判断。常用于处理自定义 Scheme 与 Universal Links。

 使用示例：
 ```swift
 // 1) 注册路由（通常在 App 启动时）
 LWDeepLinkRouter.shared.register(host: "user") { url, params in
     // 例如：myapp://user?uid=42&tab=profile
     let uid = params["uid"] ?? ""
     let tab = params["tab"] ?? "profile"
     // pushUserPage(uid: uid, defaultTab: tab)
     return true
 }

 // 2) 在 SceneDelegate / AppDelegate 回调里分发
 func handleIncomingURL(_ url: URL) -> Bool {
     LWDeepLinkRouter.shared.open(url)
 }

 // 3) 也可传字符串
 _ = LWDeepLinkRouter.shared.open("myapp://user?uid=42")
 ```

 注意事项：
 - 路由匹配维度为 **host**（不含 path）。如需更细粒度（path、正则、通配），
   可在 `register` 的 handler 内自行解析 `url.path`，或拓展本类的数据结构。
 - 参数解析来自 URL 的 **query items**。若存在重复键，后项会覆盖前项。
 - Universal Links 需在工程里配置 Associated Domains；自定义 Scheme 需在 Info.plist 中注册。
 */
public final class LWDeepLinkRouter {

    // MARK: - Types

    public typealias Handler = (_ url: URL, _ params: [String: String]) -> Bool

    // MARK: - Singleton

    public static let shared = LWDeepLinkRouter()
    public init() {}

    // MARK: - Storage (thread-safe)

    private let queue = DispatchQueue(label: "lw.deeplink.router")
    private var routes: [String: Handler] = [:] // key: host (lowercased)

    // MARK: - Register / Unregister

    /// 注册一个 host 的处理器
    public func register(host: String, handler: @escaping Handler) {
        let key = host.lowercased()
        queue.sync { routes[key] = handler }
    }

    /// 批量注册多个 host 到同一处理器
    public func register(hosts: [String], handler: @escaping Handler) {
        queue.sync {
            for h in hosts {
                routes[h.lowercased()] = handler
            }
        }
    }

    /// 撤销某个 host 的处理器
    public func unregister(host: String) {
        queue.sync { routes.removeValue(forKey: host.lowercased()) }
    }

    /// 清空所有路由
    public func unregisterAll() {
        queue.sync { routes.removeAll() }
    }

    // MARK: - Open

    /// 是否存在可处理该 URL 的路由
    public func canOpen(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return queue.sync { routes[host] != nil }
    }

    /// 便捷：传入字符串 URL
    @discardableResult
    public func open(_ string: String) -> Bool {
        guard let url = URL(string: string) else { return false }
        return open(url)
    }

    /// 分发 URL 到对应处理器
    @discardableResult
    public func open(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let params = Self.parseQuery(from: url)
        return queue.sync { routes[host]?(url, params) ?? false }
    }

    // MARK: - Helpers

    private static func parseQuery(from url: URL) -> [String: String] {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = comps.queryItems, !items.isEmpty else { return [:] }
        var dict: [String: String] = [:]
        for item in items {
            // 后项覆盖前项；nil 以空字符串代替
            dict[item.name] = item.value ?? ""
        }
        return dict
    }
}
