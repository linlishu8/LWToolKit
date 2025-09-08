import XCTest
@testable import LWCore

final class LWTaskQueueTests: XCTestCase {
    func testSubmitCompletes() async {
        let q = LWTaskQueue(maxConcurrent: 2, policy: .init(maxAttempts: 2, baseDelay: 0.05))
        let exp = expectation(description: "done")
        q.submit {
            try await Task.sleep(nanoseconds: 50_000_000)
            exp.fulfill()
        }
        await fulfillment(of: [exp], timeout: 2.0)
    }
}