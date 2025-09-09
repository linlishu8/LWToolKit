import Foundation

/**
 LWMemoryCache
 ----------------
 作用：
 一个**线程安全的内存缓存**，支持按键存取任意类型，并可选设置 TTL（过期秒数）。
 读取时若条目已过期则视为不存在（并自动清除）；支持手动清理与统计。

 使用示例：
 ```swift
 // 1) 基本用法
 let cache = LWMemoryCache.shared
 cache.set("hello", forKey: "greet")                // 永不过期
 cache.set(Data(), forKey: "blob", ttl: 5)          // 5 秒过期

 // 2) 读取（泛型推断）
 let s: String? = cache.value(forKey: "greet")      // "hello"
 let d: Data?   = cache.value(forKey: "blob")       // 5 秒后为 nil

 // 3) 其他操作
 _ = cache.contains("greet")                        // true/false
 cache.purgeExpired()                               // 主动清理过期项
 cache.removeValue(forKey: "greet")                 // 删除单个
 cache.removeAll()                                  // 清空

 // 4) 下标便捷（不带 TTL）
 cache["token"] = "abc"
 let token: String? = cache["token"]
 ```

 注意事项：
 - 内部使用并发队列 + barrier 写入，**读写线程安全**；读取为同步，写入为异步。
 - 过期策略：读取已过期的键将立即返回 `nil` 并异步清除；`count` 可能包含未清理的过期项，
   可调用 `purgeExpired()` 主动清理。
 - 此缓存仅驻留内存，**不会持久化**；应用退出后数据清空。
 */
public final class LWMemoryCache {

    // MARK: - Singleton
    public static let shared = LWMemoryCache()

    // MARK: - Types
    private struct Entry {
        let value: Any
        let expiry: Date? // nil 表示永不过期
    }

    // MARK: - Storage (thread-safe)
    private let queue = DispatchQueue(label: "com.lw.memorycache.queue", attributes: .concurrent)
    private var storage: [String: Entry] = [:]

    public init() {}

    // MARK: - Write

    /// 存储键值，支持可选 TTL（秒）。ttl 为空则永不过期
    public func set<T>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        let expiry = ttl.map { Date().addingTimeInterval($0) }
        let entry = Entry(value: value as Any, expiry: expiry)
        queue.async(flags: .barrier) { [weak self] in
            self?.storage[key] = entry
        }
    }

    // MARK: - Read

    /// 读取泛型值（缺失或过期时返回 nil）。读取到过期值会触发异步清理
    public func value<T>(forKey key: String) -> T? {
        var result: T?
        var shouldRemoveExpired = false
        let now = Date()

        queue.sync {
            guard let entry = storage[key] else { return }
            if let expiry = entry.expiry, expiry <= now {
                shouldRemoveExpired = true // 过期，稍后清理
                return
            }
            result = entry.value as? T
        }

        if shouldRemoveExpired {
            removeValue(forKey: key) // 异步 barrier 清理
        }
        return result
    }

    /// 是否存在未过期的键
    public func contains(_ key: String) -> Bool {
        let now = Date()
        var exists = false
        queue.sync {
            if let e = storage[key] {
                exists = (e.expiry == nil || e.expiry! > now)
            }
        }
        return exists
    }

    // MARK: - Remove

    public func removeValue(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeValue(forKey: key)
        }
    }

    public func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }

    /// 立即清理所有已过期条目
    public func purgeExpired() {
        let now = Date()
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.storage = self.storage.filter { _, entry in
                guard let expiry = entry.expiry else { return true }
                return expiry > now
            }
        }
    }

    // MARK: - Stats

    /// 当前条目数（可能包含尚未清理的过期项）
    public var count: Int {
        var c = 0
        queue.sync { c = storage.count }
        return c
    }

    // MARK: - Subscript

    /// 下标便捷（设置不带 TTL）
    public subscript<T>(key: String) -> T? {
        get { value(forKey: key) }
        set {
            if let v = newValue {
                set(v, forKey: key, ttl: nil)
            } else {
                removeValue(forKey: key)
            }
        }
    }
}
