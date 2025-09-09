import Foundation

/**
 LWTokenBucketLimiter & LWCircuitBreaker
 --------------------------------------
 作用：
 - **LWTokenBucketLimiter**：基于「令牌桶」的**客户端限流**中间件，在 `prepare` 阶段以固定速率补充令牌，
   没有令牌时视为“超速”请求（默认不改变请求；可选在头里打标记）。
 - **LWCircuitBreaker**：**断路器**中间件，基于滚动窗口中的失败次数控制状态：`closed → open → halfOpen`，
   half‑open 状态允许探测一次，成功则关闭、失败则重新打开。

 设计说明：
 - 由于 `LWMiddleware` 仅能改写 `URLRequest`，无法直接“拦截并失败”请求，因此默认策略是**不阻断**，
   而是通过请求头进行**打标**（例如 `X-Rate-Limited`、`X-CB-State`），供上层或服务端识别处理；
   如果你希望在客户端直接丢弃/延迟，请在网络层外部调用这些组件的辅助方法。
 - 两个中间件都为**线程安全**（互斥锁保护状态）。

 使用示例：
 ```swift
 // 1) 令牌桶：每秒 5 次、瞬时突发容量 10
 let rateLimiter = LWTokenBucketLimiter(rate: 5, burst: 10, markHeader: true)

 // 2) 断路器：30 秒窗口内连续失败 >= 5 次则打开；60 秒后进入 half-open 允许一次探测
 let breaker = LWCircuitBreaker(name: "api-core",
                                failureThreshold: 5,
                                rollingSeconds: 30,
                                halfOpenAfter: 60)

 // 3) 装配到网络配置（置于链前较合适）
 var cfg = LWNetworkConfig()
 cfg.middlewares.append(rateLimiter)
 cfg.middlewares.append(breaker)

 // 4) 在 UI 或监控中订阅断路器状态变化
 // NotificationCenter.default.addObserver(forName: LWCircuitBreaker.didChangeState, object: nil, queue: .main) { note in
 //     if let name = note.userInfo?["name"] as? String,
 //        let state = note.userInfo?["state"] as? String {
 //         print("Circuit[\(name)] -> \(state)")
 //     }
 // }
 ```

 注意事项：
 - **LWTokenBucketLimiter**：`allow()` 可单独在业务层调用以主动判定是否放行；
   `prepare` 中若检测到超速，默认**不修改请求**，可通过 `markHeader = true` 让其注入 `X-Rate-Limited: 1`。
 - **LWCircuitBreaker**：状态判断基于 `didReceive` 的结果；你也可以在上层将 5xx/网络错误统一映射成 `LWNetworkError`
   后再交给中间件，以获得一致行为。断路器会通过 `X-CB-State` 打标当前状态（`open/halfOpen/closed`）。
 */

// MARK: - Token Bucket

public final class LWTokenBucketLimiter: LWMiddleware {

    private let rate: Double          // 每秒补充令牌数
    private let burst: Double         // 桶容量（最大突发）
    private var tokens: Double        // 当前令牌
    private var last: Date            // 上次补充时间
    private let lock = NSLock()

    /// 是否在 prepare 时为超速请求添加请求头标记（X-Rate-Limited: 1）
    private let markHeader: Bool

    /// - Parameters:
    ///   - rate: 每秒补充令牌数（>0）
    ///   - burst: 最大桶容量（>=1）
    ///   - markHeader: 超速时是否在请求头中打标（默认 false）
    public init(rate: Double, burst: Double, markHeader: Bool = false) {
        self.rate = max(0, rate)
        self.burst = max(1, burst)
        self.tokens = self.burst
        self.last = Date()
        self.markHeader = markHeader
    }

    /// 判定是否允许（原子操作）：允许则消耗 1 个令牌
    @discardableResult
    public func allow() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let delta = now.timeIntervalSince(last)
        tokens = min(burst, tokens + rate * delta)
        last = now
        if tokens >= 1 {
            tokens -= 1
            return true
        }
        return false
    }

    /// 当前可用令牌（近似值，仅用于展示）
    public var availableTokens: Double {
        lock.lock(); defer { lock.unlock() }
        let now = Date()
        let delta = now.timeIntervalSince(last)
        let filled = min(burst, tokens + rate * delta)
        return filled
    }

    /// 复位：清空/填满令牌
    public func reset(fill: Bool = true) {
        lock.lock()
        tokens = fill ? burst : 0
        last = Date()
        lock.unlock()
    }

    // MARK: LWMiddleware

    public func prepare(_ r: URLRequest) -> URLRequest {
        guard !allow() else { return r }
        guard markHeader else { return r }
        var req = r
        req.setValue("1", forHTTPHeaderField: "X-Rate-Limited")
        return req
    }

    public func willSend(_ request: URLRequest) {}
    public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {}
}

// MARK: - Circuit Breaker

public final class LWCircuitBreaker: LWMiddleware {

    public enum State: String { case closed, open, halfOpen }

    public static let didChangeState = Notification.Name("LWCircuitBreaker.didChangeState")

    private let name: String
    private let failureThreshold: Int
    private let rollingSeconds: TimeInterval
    private let halfOpenAfter: TimeInterval

    private var state: State = .closed
    private var failures: [Date] = []
    private var openedAt: Date? = nil

    private let lock = NSLock()

    public init(name: String,
                failureThreshold: Int,
                rollingSeconds: TimeInterval,
                halfOpenAfter: TimeInterval) {
        self.name = name
        self.failureThreshold = max(1, failureThreshold)
        self.rollingSeconds = max(1, rollingSeconds)
        self.halfOpenAfter = max(1, halfOpenAfter)
    }

    // 便捷访问
    public var currentState: State { lock.lock(); defer { lock.unlock() }; return state }
    public var isOpen: Bool { currentState == .open }

    // 控制
    public func forceOpen() { transition(to: .open) }
    public func forceClose() { transition(to: .closed); lock.lock(); failures.removeAll(); lock.unlock() }

    // MARK: LWMiddleware

    public func prepare(_ r: URLRequest) -> URLRequest {
        lock.lock()
        // open → halfOpen（到期尝试探测一次）
        if state == .open, let t = openedAt, Date().timeIntervalSince(t) > halfOpenAfter {
            transitionLocked(to: .halfOpen)
        }
        let st = state
        lock.unlock()

        var req = r
        req.setValue(st.rawValue, forHTTPHeaderField: "X-CB-State")
        if st == .open {
            req.setValue("1", forHTTPHeaderField: "X-CB-Open")
        }
        return req
    }

    public func willSend(_ request: URLRequest) {}

    public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
        lock.lock(); defer { lock.unlock() }

        let now = Date()
        // 滚动窗口：清理过期失败记录
        failures = failures.filter { now.timeIntervalSince($0) <= rollingSeconds }

        switch result {
        case .success(let tuple):
            let code = tuple.0.statusCode
            let ok = (200..<400).contains(code)
            if state == .halfOpen {
                transitionLocked(to: ok ? .closed : .open)
                if state == .open { openedAt = now }
            }
            if ok { failures.removeAll() }
            else { recordFailureLocked(now) }

        case .failure:
            recordFailureLocked(now)
        }
    }

    // MARK: - Private

    private func recordFailureLocked(_ now: Date) {
        failures.append(now)
        if failures.count >= failureThreshold {
            transitionLocked(to: .open)
            openedAt = now
        }
    }

    private func transition(to new: State) {
        lock.lock(); transitionLocked(to: new); lock.unlock()
    }

    private func transitionLocked(to new: State) {
        guard state != new else { return }
        state = new
        NotificationCenter.default.post(name: Self.didChangeState, object: nil, userInfo: [
            "name": name,
            "state": new.rawValue
        ])
    }
}
