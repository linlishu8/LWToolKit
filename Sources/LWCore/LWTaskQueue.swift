import Foundation

/**
 LWTaskQueue
 ----------------
 作用：
 一个**带并发上限与重试策略**的异步任务队列。你可以不断提交 `async throws` 的任务，
 队列会在最多 `maxConcurrent` 个并发度下执行；任务失败时按照 `LWRetryPolicy`
 自动退避重试，直到成功或达到最大尝试次数。

 使用示例：
 ```swift
 // 1) 构建队列：最多并发 3 个任务，重试策略默认（3 次、指数退避）
 if #available(iOS 14.0, *) {
     let queue = LWTaskQueue(maxConcurrent: 3)

     // 2) 提交任务（失败会自动按策略重试）
     queue.submit {
         try await uploadFile("/path/a")
     }
     queue.submit {
         try await uploadFile("/path/b")
     }

     // 3) 如需拿到 Task 以便取消/等待，使用返回 Task 的重载
     let t = queue.submitReturningTask {
         try await syncUserProfile()
     }
     // 取消：t.cancel()
     // 等待：await t.value
 }
 ```

 注意事项：
 - `LWRetryPolicy.delay(for:)` 的 `attempt` 从 **1** 起算：第 1 次不等待，
   从第 2 次开始指数退避。此队列内部已正确使用 `attempt+1` 计算下一次等待。
 - 任务体必须是 `async throws`；若你没有错误要抛出，可直接不抛错或抛自定义错误来触发重试。
 - `submit` 内部使用 `Task.detached` 执行；若需要取消或等待，请使用 `submitReturningTask` 拿到 `Task`。
 */
@available(iOS 14.0, *)
public final class LWTaskQueue {

    // MARK: - Internals
    private let q = DispatchQueue(label: "lw.task.queue", attributes: .concurrent)
    private let sema: AsyncSemaphore
    private let policy: LWRetryPolicy

    // MARK: - Init
    public init(maxConcurrent: Int = 2, policy: LWRetryPolicy = .init()) {
        self.sema = AsyncSemaphore(value: max(1, maxConcurrent))
        self.policy = policy
    }

    // MARK: - Submit

    /// 提交一个异步任务（带并发限制与重试），不返回 Task 句柄
    public func submit(_ work: @escaping () async throws -> Void) {
        q.async { [sema, policy] in
            Task.detached(priority: .medium) {
                await sema.withPermit {
                    var attempt = 1
                    while true {
                        do {
                            try await work()
                            break
                        } catch {
                            // 达到最大次数则停止
                            if attempt >= policy.maxAttempts { break }
                            // 计算“下一次尝试”的等待时长：attempt+1
                            let seconds = policy.delay(for: attempt + 1)
                            attempt += 1
                            if seconds > 0 {
                                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                            }
                        }
                    }
                }
            }
        }
    }

    /// 提交一个异步任务，并返回可取消/等待的 Task 句柄
    @discardableResult
    public func submitReturningTask(_ work: @escaping () async throws -> Void) -> Task<Void, Never> {
        return Task.detached(priority: .medium) { [sema, policy] in
            await sema.withPermit {
                var attempt = 1
                while true {
                    do {
                        try await work()
                        break
                    } catch {
                        if attempt >= policy.maxAttempts { break }
                        let seconds = policy.delay(for: attempt + 1)
                        attempt += 1
                        if seconds > 0 {
                            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                        }
                    }
                }
            }
        }
    }
}

/// 简单的异步信号量（FIFO），避免在 async 环境中阻塞线程
@available(iOS 14.0, *)
actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) { self.value = value }

    func wait() async {
        if value > 0 { value -= 1; return }
        await withCheckedContinuation { cont in waiters.append(cont) }
    }

    func signal() {
        if !waiters.isEmpty {
            let cont = waiters.removeFirst()
            cont.resume()
        } else {
            value += 1
        }
    }

    /// 便捷用法：自动获取/释放许可
    func withPermit<T>(_ body: @Sendable () async -> T) async -> T {
        await wait()
        defer { signal() }
        return await body()
    }
}
