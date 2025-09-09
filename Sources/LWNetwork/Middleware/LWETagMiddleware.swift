import Foundation

/**
 LWETagMiddleware & LWETagStore
 -----------------------------
 作用：
 基于 **ETag/If-None-Match** 的简易响应验证中间件：
 - 发送前（GET/HEAD）：若本地存有该 URL 的 ETag，则为请求加上 `If-None-Match`；
 - 收到响应：若响应包含 `ETag` 头，则更新本地存储，供下次请求复用。

 工作流程（需与 HTTP 缓存或你自己的正文缓存配合）：
 1) 首次请求获得 200 + `ETag`，中间件写入 `ETag`；
 2) 后续请求带上 `If-None-Match: <etag>`；
 3) 若资源未更改，服务端返回 **304 Not Modified**，可复用本地缓存正文（例如依赖 `URLCache`）；
 4) 若资源已更改，返回 200 + 新 `ETag`，中间件会更新存储。

 使用示例：
 ```swift
 // 1) 启用 URLCache（建议）+ 在中间件链前置 ETag
 var cfg = LWNetworkConfig()
 cfg.useETagCaching = true             // 若使用 LWAlamofireClient，将自动插入本中间件
 // 或手动：cfg.middlewares.insert(LWETagMiddleware(), at: 0)
 // 并在客户端侧为 URLSession 配置 URLCache（见 LWURLCache）

 let client = LWAlamofireClient(config: cfg)

 // 2) 手动操作存储（测试/调试用）
 // LWETagStore.shared.removeAll()
 ```

 注意事项：
 - 默认仅对 **GET/HEAD** 生效；若需要 PUT 等方法可自行放开。
 - `value(forHTTPHeaderField:)` 对大小写不敏感；这里读取的是标准写法 `"ETag"`。
 - 本实现**不存正文**；304 时正文由 `URLCache` 或你的业务缓存（例如 `LWInMemoryCache`）负责命中。
 */

// MARK: - Internal store

final class LWETagStore {

    static let shared = LWETagStore()

    private let lock = NSLock()
    private var tags: [String: String] = [:]

    /// 读取指定 URL 的 ETag
    func tag(for url: URL?) -> String? {
        guard let key = Self.key(for: url) else { return nil }
        lock.lock(); defer { lock.unlock() }
        return tags[key]
    }

    /// 写入/更新指定 URL 的 ETag
    func set(_ tag: String, for url: URL?) {
        guard let key = Self.key(for: url) else { return }
        lock.lock(); tags[key] = tag; lock.unlock()
    }

    /// 删除指定 URL 的 ETag
    func remove(for url: URL?) {
        guard let key = Self.key(for: url) else { return }
        lock.lock(); tags.removeValue(forKey: key); lock.unlock()
    }

    /// 清空所有 ETag
    func removeAll() {
        lock.lock(); tags.removeAll(); lock.unlock()
    }

    /// 生成存储键（忽略 fragment）
    private static func key(for url: URL?) -> String? {
        guard let u = url else { return nil }
        var comps = URLComponents(url: u, resolvingAgainstBaseURL: false)
        comps?.fragment = nil
        return comps?.string ?? u.absoluteString
    }
}

// MARK: - Middleware

public struct LWETagMiddleware: LWMiddleware {

    public init() {}

    /// 发送前：为 GET/HEAD 添加 If-None-Match（若存在且未显式覆盖）
    public func prepare(_ r: URLRequest) -> URLRequest {
        guard let method = r.httpMethod?.uppercased(), method == "GET" || method == "HEAD" else { return r }
        // 若外部已设置 If-None-Match，则尊重外部配置
        if r.value(forHTTPHeaderField: "If-None-Match") != nil { return r }
        var req = r
        if let t = LWETagStore.shared.tag(for: r.url) {
            req.setValue(t, forHTTPHeaderField: "If-None-Match")
        }
        return req
    }

    public func willSend(_ request: URLRequest) {}

    /// 收到响应：若含 ETag 则更新（不区分 200/304，服务端变更会返回新 ETag）
    public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
        guard let method = request.httpMethod?.uppercased(), method == "GET" || method == "HEAD" else { return }
        guard case .success(let (http, _)) = result else { return }
        if let etag = http.value(forHTTPHeaderField: "ETag"), !etag.isEmpty {
            LWETagStore.shared.set(etag, for: request.url)
        }
    }
}
