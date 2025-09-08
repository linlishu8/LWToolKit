import XCTest
@testable import LWCore

final class LWThrottlerTests: XCTestCase {
    func testThrottleLimitsCalls() {
        let t = LWThrottler(0.2)
        let exp = expectation(description: "throttle")
        exp.expectedFulfillmentCount = 1
        var callCount = 0
        for _ in 0..<10 { t.call { callCount += 1; exp.fulfill() } }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(callCount, 1)
    }
}