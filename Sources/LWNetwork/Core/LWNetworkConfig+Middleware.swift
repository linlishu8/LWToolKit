import Foundation
import Alamofire
import OSLog
public struct LWNetworkConfig {
  public var timeout: TimeInterval = 20; public var requestHeaders: HTTPHeaders = [:]
  public var traceHeaderKey = "X-Trace-Id"; public var sessionHeaderKey = "X-Session-Id"; public var retryLimit: Int = 2
  public var cacheTTL: TimeInterval = 0; public var enablePinning = false; public var pinnedDomains: [String: [Data]] = [:]; public var pinningSets: LWPinningSets = [:]
  public var middlewares: [LWMiddleware] = []; public var useETagCaching: Bool = false; public init() {}
}
public protocol LWMiddleware {
  func prepare(_ request: URLRequest) -> URLRequest
  func willSend(_ request: URLRequest)
  func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest)
}
public extension Logger { static let lwNetwork = Logger(subsystem: Bundle.main.bundleIdentifier ?? "lw.app", category: "network") }
