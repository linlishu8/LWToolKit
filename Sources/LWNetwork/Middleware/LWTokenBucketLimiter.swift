import Foundation
public final class LWTokenBucketLimiter: LWMiddleware {
  private let rate: Double; private let burst: Double; private var tokens: Double; private var last: Date; private let lock = NSLock()
  public init(rate: Double, burst: Double) { self.rate = rate; self.burst = burst; self.tokens = burst; self.last = Date() }
  public func prepare(_ r: URLRequest) -> URLRequest { lock.lock(); defer{lock.unlock()}; let now=Date(); let delta=now.timeIntervalSince(last); tokens=min(burst, tokens + rate*delta); last=now; if tokens>=1{ tokens -= 1 } ; return r }
  public func willSend(_ request: URLRequest) {} ; public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {}
}
public final class LWCircuitBreaker: LWMiddleware {
  public enum State: String { case closed, open, halfOpen }
  private let name:String; private let failureThreshold:Int; private let rollingSeconds:TimeInterval; private let halfOpenAfter:TimeInterval
  private var state:State = .closed; private var failures:[Date]=[]; private var openedAt:Date? = nil; private let lock = NSLock()
  public init(name:String, failureThreshold:Int, rollingSeconds:TimeInterval, halfOpenAfter:TimeInterval){ self.name=name; self.failureThreshold=failureThreshold; self.rollingSeconds=rollingSeconds; self.halfOpenAfter=halfOpenAfter }
  public func prepare(_ r: URLRequest)->URLRequest{
    lock.lock(); defer{lock.unlock()}
    switch state {
      case .open:
        if let t = openedAt, Date().timeIntervalSince(t) > halfOpenAfter { state = .halfOpen } // allow probe
      case .halfOpen, .closed: break
    }
    var req = r
    if state == .open { req.setValue("1", forHTTPHeaderField: "X-CB-Open") }
    return req
  }
  public func willSend(_ request: URLRequest) {}
  public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
    lock.lock(); defer{lock.unlock()}
    let now = Date()
    failures = failures.filter{ now.timeIntervalSince($0) <= rollingSeconds }
    switch result {
      case .success(let tuple):
        let code = tuple.0.statusCode
        if state == .halfOpen { state = (200..<400).contains(code) ? .closed : .open; if state == .open { openedAt = now } }
        if (200..<400).contains(code) { failures.removeAll() }
      case .failure:
        failures.append(now)
        if failures.count >= failureThreshold { state = .open; openedAt = now }
    }
  }
}
