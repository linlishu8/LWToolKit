import Foundation

/**
 LWRateLimiter
 ----------------
 作用：
 一个**基于滑动时间窗口的限流器**。按 `key` 统计最近 `window` 秒内的访问时间戳，
 当次数达到 `limit` 时，新的请求将被拒绝。适合接口防抖、按钮防滥点、日志/埋点限速等场景。
 内部使用并发队列 + barrier 写入，**线程安全**。

 使用示例：
 ```swift
 // 1) 构建：每个 key 在 10 秒内最多允许 3 次
 let limiter = LWRateLimiter(limit: 3, window: 10)

 // 2) 判定是否允许
 if limiter.allow("send_sms") {
     // 允许发送
 } else {
     // 告知用户稍后再试
 }

 // 3) 剩余额度 & 重置
 let left = limiter.remaining(for: "send_sms")    // 本窗口内剩余可用次数
 limiter.reset("send_sms")                        // 清空单个 key
 limiter.resetAll()                               // 清空全部

 // 4) 便捷：允许时才执行
 limiter.performIfAllowed(key: "upload") {
     // 执行上传逻辑
 }
 ```

 注意事项：
 - 算法为**滑动窗口**：每次请求只保留窗口内的时间戳，时间复杂度与窗口内记录数成正比。
   在高并发/大窗口场景可考虑令牌桶/漏桶等近似算法。
 - `allow` 为**同步**方法，已在内部串行化关键区；不会阻塞主线程太久，但不建议在超高频阻塞场景调用。
 */
public final class LWRateLimiter {

    // MARK: - State
    private var timestamps: [String: [TimeInterval]] = [:]
    private let limit: Int
    private let window: TimeInterval
    private let queue = DispatchQueue(label: "lw.rate.limiter", attributes: .concurrent)

    // MARK: - Init
    /// - Parameters:
    ///   - limit: 时间窗口内允许的最大次数
    ///   - window: 时间窗口长度（秒）
    public init(limit: Int, window: TimeInterval) {
        self.limit = max(0, limit)
        self.window = max(0, window)
    }

    // MARK: - API

    /// 判定当前请求是否允许（允许则同时记入一次）
    @discardableResult
    public func allow(_ key: String) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        return queue.sync(flags: .barrier) {
            var arr = timestamps[key] ?? []
            // 仅保留窗口内的记录
            arr = arr.filter { now - $0 <= window }
            guard arr.count < limit else {
                timestamps[key] = arr
                return false
            }
            arr.append(now)
            timestamps[key] = arr
            return true
        }
    }

    /// 如果允许则执行代码块，并返回是否执行
    @discardableResult
    public func performIfAllowed(key: String, _ block: () -> Void) -> Bool {
        if allow(key) {
            block()
            return true
        }
        return false
    }

    /// 返回窗口内剩余可用次数
    public func remaining(for key: String) -> Int {
        let now = CFAbsoluteTimeGetCurrent()
        return queue.sync {
            let count = (timestamps[key] ?? []).filter { now - $0 <= window }.count
            return max(0, limit - count)
        }
    }

    /// 重置某个 key 的计数
    public func reset(_ key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.timestamps.removeValue(forKey: key)
        }
    }

    /// 清空全部计数
    public func resetAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.timestamps.removeAll()
        }
    }
}
