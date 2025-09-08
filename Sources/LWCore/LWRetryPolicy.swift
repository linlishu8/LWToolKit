import Foundation
public struct LWRetryPolicy {
    public let maxAttempts:Int; public let baseDelay:TimeInterval
    public init(maxAttempts:Int=3, baseDelay:TimeInterval=0.8){ self.maxAttempts=maxAttempts; self.baseDelay=baseDelay }
    public func delay(for attempt:Int)->TimeInterval{ attempt<=1 ? 0 : pow(2, Double(attempt-1))*baseDelay }
}
