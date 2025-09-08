import Foundation
public final class LWThrottler {
    private let interval: TimeInterval; private var last: TimeInterval = 0
    public init(_ interval: TimeInterval){ self.interval = interval }
    public func call(_ block: ()->Void){ let now=CFAbsoluteTimeGetCurrent(); guard now-last>=interval else { return }; last=now; block() }
}
