import Foundation

/**
 LWRequestCoalescer & LWRequestKey
 --------------------------------
 作用：
 - **LWRequestCoalescer**：合并同一请求的并发执行（in‑flight 去重）。当多个协程对同一 Key 同时发起请求，
   只会真正执行一次，其他协程复用同一 `Task` 的结果；请求完成或失败后即从表中移除（不做持久缓存）。
 - **LWRequestKey**：用于标识“相同请求”的键（默认由 `method + url + httpBody` 构成）。

 使用示例：
 ```swift
 let coalescer = LWRequestCoalescer()

 // 1) 生成 Key（从 URLRequest）
 var req = URLRequest(url: URL(string: "https://api.example.com/v1/me")!)
 req.httpMethod = "GET"
 let key = LWRequestKey(req)

 // 2) 合并执行：并发调用仅触发一次实际请求
 let data = try await coalescer.run(for: key) {
     // 这里放真正的网络调用
     try await URLSession.shared.data(for: req).0
 }

 // 3) 取消/清理
 coalescer.cancel(for: key)
 coalescer.cancelAll()
 print("inflight:", await coalescer.inflightCount)
 ```

 注意事项：
 - **仅合并在途请求**，不做结果缓存；若需要缓存请结合 `LWMemoryCache` 或 URLCache。
 - `LWRequestKey` 的 `bodyHash` 使用 `Data.hashValue`，适合**进程内即时合并**；
   如需跨进程/跨时段稳定哈希，可在工程中改用 `CryptoKit` 的 SHA256。
 - 若你的“相同请求”规则需要考虑特定 Header，可在外层自定义 Key 规则或扩展 `LWRequestKey`。
 */

// MARK: - Coalescer

public actor LWRequestCoalescer {

    private var tasks: [LWRequestKey: Task<Data, Error>] = [:]

    public init() {}

    /// 若相同 Key 的任务已存在，则直接复用该任务的结果；否则创建新任务并记录
    public func run(for key: LWRequestKey,
                    _ block: @escaping @Sendable () async throws -> Data) async throws -> Data {
        if let t = tasks[key] {
            return try await t.value
        }
        let t = Task<Data, Error> {
            try await block()
        }
        tasks[key] = t
        defer { tasks[key] = nil } // 成功/失败/取消后都移除
        return try await t.value
    }

    /// 取消并移除某个 Key 的进行中任务（若存在）
    @discardableResult
    public func cancel(for key: LWRequestKey) -> Bool {
        guard let t = tasks.removeValue(forKey: key) else { return false }
        t.cancel()
        return true
    }

    /// 取消所有进行中任务并清空
    public func cancelAll() {
        for (_, t) in tasks { t.cancel() }
        tasks.removeAll()
    }

    /// 当前在途任务数量
    public var inflightCount: Int { tasks.count }

    /// 便捷：从 URLRequest 构建 Key
    public static func key(for request: URLRequest) -> LWRequestKey { LWRequestKey(request) }
}

// MARK: - Key

public struct LWRequestKey: Hashable, CustomStringConvertible {

    public let method: String
    public let url: String
    public let bodyHash: Int

    /// 以 URLRequest 构建 Key（method + url + httpBody.hashValue）
    public init(_ r: URLRequest) {
        self.method = r.httpMethod ?? "GET"
        self.url = r.url?.absoluteString ?? ""
        if let body = r.httpBody {
            self.bodyHash = body.hashValue
        } else {
            self.bodyHash = 0
        }
    }

    /// 直接用字段构造（可用于自定义规则）
    public init(method: String, url: String, bodyHash: Int = 0) {
        self.method = method
        self.url = url
        self.bodyHash = bodyHash
    }

    public var description: String {
        "LWRequestKey(\(method) \(url) bodyHash:\(bodyHash))"
    }
}
