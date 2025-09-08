import XCTest
@testable import LWCore

final class LWDebouncerTests: XCTestCase {
    func testDebounceExecutesLast() {
        let exp = expectation(description: "debounced")
        let d = LWDebouncer(delay: 0.1)
        var count = 0
        d.call { count = 1 }
        d.call { count = 2 }
        d.call { count = 3; exp.fulfill() }
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(count, 3)
    }
}