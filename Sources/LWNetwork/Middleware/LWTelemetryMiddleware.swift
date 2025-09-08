import Foundation
import OSLog
public struct LWTelemetryMiddleware: LWMiddleware {
  let traceKey: String; let sessionKey: String; let sessionProvider: () -> String
  public init(traceKey: String, sessionKey: String, sessionProvider: @escaping () -> String) { self.traceKey = traceKey; self.sessionKey = sessionKey; self.sessionProvider = sessionProvider }
  public func prepare(_ r: URLRequest) -> URLRequest { var req = r; req.setValue(UUID().uuidString, forHTTPHeaderField: traceKey); req.setValue(sessionProvider(), forHTTPHeaderField: sessionKey); return req }
  public func willSend(_ request: URLRequest) { Logger.lwNetwork.debug("➡️ \(request.url?.absoluteString ?? "")") }
  public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {}
}
