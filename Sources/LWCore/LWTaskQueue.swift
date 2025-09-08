import Foundation
public final class LWTaskQueue {
    private let q = DispatchQueue(label:"lw.task.queue", attributes: .concurrent)
    private let sema: DispatchSemaphore; private let policy: LWRetryPolicy
    public init(maxConcurrent:Int=2, policy: LWRetryPolicy = .init()){ sema=DispatchSemaphore(value:maxConcurrent); self.policy=policy }
    public func submit(_ work:@escaping () async throws -> Void){
        q.async { [sema, policy] in
            Task {
                sema.wait(); defer { sema.signal() }
                var attempt = 0
                while true {
                    do { try await work(); break }
                    catch { attempt += 1; if attempt >= policy.maxAttempts { break }
                        try? await Task.sleep(nanoseconds: UInt64(policy.delay(for: attempt)*1_000_000_000)) }
                }
            }
        }
    }
}
