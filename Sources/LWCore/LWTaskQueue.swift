import Foundation

@available(iOS 14.0, *)
public final class LWTaskQueue {
    private let q = DispatchQueue(label: "lw.task.queue", attributes: .concurrent)
    private let sema: AsyncSemaphore
    private let policy: LWRetryPolicy

    public init(maxConcurrent: Int = 2, policy: LWRetryPolicy = .init()) {
        self.sema = AsyncSemaphore(value: max(1, maxConcurrent))
        self.policy = policy
    }

    /// 提交一个异步任务（带并发限制与重试）
    public func submit(_ work: @escaping () async throws -> Void) {
        q.async { [sema, policy] in
            Task.detached(priority: .medium) {
                await sema.withPermit {
                    var attempt = 0
                    while true {
                        do {
                            try await work()
                            break
                        } catch {
                            attempt += 1
                            if attempt >= policy.maxAttempts { break }
                            let seconds = policy.delay(for: attempt)
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
