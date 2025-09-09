import Foundation

/**
 LWRetryPolicy
 ----------------
 作用：
 一个**指数退避（Exponential Backoff）**重试策略工具。根据尝试次数计算等待时长，
 支持可选抖动（Jitter）与最大延迟上限，并提供一个通用的 `retry` 异步辅助方法，
 方便对网络请求、IO 操作等场景做稳定的重试控制。

 使用示例：
 ```swift
 // 1) 仅计算延迟（attempt 从 1 开始）
 let policy = LWRetryPolicy(maxAttempts: 3, baseDelay: 0.8)
 let d1 = policy.delay(for: 1)               // 第 1 次：0 秒
 let d2 = policy.delay(for: 2)               // 第 2 次：~1.6 秒
 let d3 = policy.delay(for: 3, jitter: 0.2)  // 第 3 次：在 ±20% 抖动范围内

 // 2) 在你的循环里等待
 for attempt in 1...policy.maxAttempts {
     if attempt > 1 {
         try? await policy.sleep(for: attempt, jitter: 0.1, maxDelay: 6.0)
     }
     // 执行操作...
 }

 // 3) 最简便：用内置 retry 辅助方法
 let result: Data = try await policy.retry(
     operation: {
         // 这里写你的异步操作，例如网络请求
         return Data()
     },
     shouldRetry: { error in
         // 仅对特定错误重试（默认为对所有错误重试）
         // return (error as? URLError)?.code == .timedOut
         return true
     },
     jitter: 0.1,
     maxDelay: 6.0
 )
 ```

 注意事项：
 - `attempt` 从 **1** 开始计数：第 1 次不等待，之后按指数退避。
 - 抖动（`jitter`）可减少惊群，取值 0~1，表示在 ±`jitter`×`delay` 范围内随机波动。
 - 指数退避公式：`delay = (attempt <= 1 ? 0 : baseDelay * 2^(attempt-1))`，再套用抖动与 `maxDelay` 截断。
 - `retry` 方法在达到 `maxAttempts` 仍失败时会**抛出最后一次的错误**。
 */
public struct LWRetryPolicy {

    public let maxAttempts: Int
    public let baseDelay: TimeInterval

    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 0.8) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
    }

    /// 计算某次尝试的等待时长（秒）
    /// - Parameters:
    ///   - attempt: 从 1 开始计数；1 表示首次尝试，返回 0
    ///   - jitter: 抖动系数（0~1）；nil 或 <=0 表示不加抖动
    ///   - maxDelay: 最大等待上限（用于防止指数爆炸）
    public func delay(for attempt: Int,
                      jitter: Double? = nil,
                      maxDelay: TimeInterval? = nil) -> TimeInterval {
        guard attempt > 1 else { return 0 }
        var d = pow(2, Double(attempt - 1)) * baseDelay

        // clamp max
        if let cap = maxDelay { d = min(d, max(0, cap)) }

        // apply jitter ±(j * d)
        if let j = jitter, j > 0 {
            let jv = min(max(j, 0), 1)
            let delta = d * jv
            d = max(0, d + Double.random(in: -delta...delta))
        }
        return d
    }

    /// 依据 attempt 等待一段时间（被取消时会提前返回）
    public func sleep(for attempt: Int,
                      jitter: Double? = nil,
                      maxDelay: TimeInterval? = nil) async throws {
        let seconds = delay(for: attempt, jitter: jitter, maxDelay: maxDelay)
        guard seconds > 0 else { return }
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// 通用异步重试辅助
    /// - Parameters:
    ///   - operation: 要执行的异步操作；成功返回 T，失败抛出 Error
    ///   - shouldRetry: 遇错时是否继续重试（默认对所有错误重试）
    ///   - jitter: 抖动系数（0~1），默认 0
    ///   - maxDelay: 单次最大等待上限（秒）
    /// - Returns: 操作成功时返回结果 T；若最终失败则抛出最后一次错误
    public func retry<T>(
        operation: @escaping () async throws -> T,
        shouldRetry: (Error) -> Bool = { _ in true },
        jitter: Double = 0,
        maxDelay: TimeInterval? = nil
    ) async throws -> T {
        var lastError: Error? = nil

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt >= maxAttempts || !shouldRetry(error) {
                    break
                }
                try? await sleep(for: attempt + 1, jitter: jitter, maxDelay: maxDelay)
            }
        }
        throw lastError ?? NSError(domain: "LWRetryPolicy", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown retry failure"])
    }
}
