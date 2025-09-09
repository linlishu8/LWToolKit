import Foundation

/**
 LWInMemoryCache & LWCacheMiddleware
 ----------------------------------
 作用：
 - **LWInMemoryCache**：一个线程安全的内存型 KV 缓存（值为 `Data`），支持 TTL（过期时间）。
 - **LWCacheMiddleware**：网络中间件（配合 `LWNetworking` 客户端使用），在 **成功的响应** 时将响应体写入
   `LWInMemoryCache`，用于简单的 GET 结果缓存。并提供生成缓存键的辅助方法。

 使用示例：
 ```swift
 // 1) 直接使用缓存
 let key = LWCacheMiddleware.key(for: request)      // 由请求生成缓存键
 if let data = LWInMemoryCache.shared.get(key) {
     // 命中缓存，直接使用 data（避免发网）
 }

 // 2) 在网络客户端中挂载中间件（以 LWAlamofireClient 为例）
 var cfg = LWNetworkConfig()
 cfg.middlewares.append(LWCacheMiddleware(ttl: 30)) // GET 响应缓存 30s
 let client = LWAlamofireClient(config: cfg)

 // 3) 写入缓存（由中间件在 2xx 响应时自动完成）
 // 4) 手动操作
 LWInMemoryCache.shared.set(key, data: Data("Hello".utf8), ttl: 10)
 LWInMemoryCache.shared.remove(key)
 LWInMemoryCache.shared.purgeExpired()
 LWInMemoryCache.shared.clear()
 ```

 注意事项：
 - 该缓存为**进程内**内存缓存，应用退出即清空；适合接口临时缓存、列表数据等轻量场景。
 - `LWCacheMiddleware` 默认**仅缓存 GET 且 2xx 的响应**；如需更复杂策略（按 Header 控制等），可自行扩展。
 - 若你需要真正的 HTTP 缓存（含 ETag/Cache-Control），建议结合系统 `URLCache` 或已有的 ETag 中间件。
 */

// MARK: - In-memory cache

public final class LWInMemoryCache {

    public static let shared = LWInMemoryCache()

    private struct Entry {
        let data: Data
        let expiry: Date
    }

    private var store: [String: Entry] = [:]
    private let lock = NSLock()

    public init() {}

    /// 读取（若过期则返回 nil 并清理）
    public func get(_ key: String) -> Data? {
        lock.lock(); defer { lock.unlock() }
        guard let e = store[key] else { return nil }
        if e.expiry > Date() { return e.data }
        store.removeValue(forKey: key)
        return nil
    }

    /// 写入（ttl 秒后过期）
    public func set(_ key: String, data: Data, ttl: TimeInterval) {
        let expiry = Date().addingTimeInterval(max(0, ttl))
        lock.lock(); store[key] = Entry(data: data, expiry: expiry); lock.unlock()
    }

    /// 删除单个键
    public func remove(_ key: String) {
        lock.lock(); store.removeValue(forKey: key); lock.unlock()
    }

    /// 清空所有
    public func clear() {
        lock.lock(); store.removeAll(); lock.unlock()
    }

    /// 立即清理过期条目
    public func purgeExpired() {
        let now = Date()
        lock.lock()
        store = store.filter { _, e in e.expiry > now }
        lock.unlock()
    }

    /// 当前条目数（可能包含未清理的过期项）
    public var count: Int {
        lock.lock(); let c = store.count; lock.unlock(); return c
    }
}

// MARK: - Cache middleware

public struct LWCacheMiddleware: LWMiddleware {
    /// TTL（秒），<=0 时不缓存
    public let ttl: TimeInterval

    public init(ttl: TimeInterval) { self.ttl = ttl }

    public func prepare(_ request: URLRequest) -> URLRequest { request }
    public func willSend(_ request: URLRequest) {}

    /// 在成功响应（2xx）后写入缓存（仅对 GET）
    public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
        guard ttl > 0 else { return }
        guard (request.httpMethod ?? "GET").uppercased() == "GET" else { return }
        guard case .success(let (http, data)) = result, (200..<300).contains(http.statusCode) else { return }
        let key = Self.key(for: request)
        LWInMemoryCache.shared.set(key, data: data, ttl: ttl)
    }

    // MARK: - Key helpers

    /// 由 URLRequest 生成缓存键（method + url + bodyHash + 指定头）
    /// - Parameter includeHeaders: 需要纳入 Key 计算的 Header 名（大小写不敏感）
    public static func key(for request: URLRequest, includeHeaders: [String] = []) -> String {
        let method = (request.httpMethod ?? "GET").uppercased()
        let url = request.url?.absoluteString ?? ""
        let bodyHash = request.httpBody?.hashValue ?? 0
        var parts = ["\(method) \(url) #\(bodyHash)"]
        if !includeHeaders.isEmpty {
            let lower = Set(includeHeaders.map { $0.lowercased() })
            let headers = request.allHTTPHeaderFields ?? [:]
            let picked = headers
                .filter { lower.contains($0.key.lowercased()) }
                .sorted { $0.key.lowercased() < $1.key.lowercased() }
                .map { "\($0.key.lowercased())=\($0.value)" }
                .joined(separator: "&")
            if !picked.isEmpty { parts.append("|\(picked)") }
        }
        return parts.joined()
    }
}
