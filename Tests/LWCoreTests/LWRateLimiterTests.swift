import XCTest
@testable import LWCore

final class LWRateLimiterTests: XCTestCase {
    func testWindowLimit() {
        let limiter = LWRateLimiter(limit: 2, window: 0.5)
        XCTAssertTrue(limiter.allow("k"))
        XCTAssertTrue(limiter.allow("k"))
        XCTAssertFalse(limiter.allow("k"))
    }
}