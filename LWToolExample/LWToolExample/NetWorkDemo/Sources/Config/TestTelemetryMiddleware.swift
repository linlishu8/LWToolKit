/* 
  作用：统一遥测：方法/URL/状态码/耗时/请求ID。
*/
import Foundation
import Alamofire
import LWToolKit

public final class TestTelemetryMiddleware: LWMiddleware {
    private let startKey = "ez_start_time"
    public func prepare(_ request: inout URLRequest) {
        if request.value(forHTTPHeaderField: "X-Request-Id") == nil {
            request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-Id")
        }
        request.setValue(String(Date().timeIntervalSince1970), forHTTPHeaderField: startKey)
    }
    public func willSend(_ request: URLRequest) { }
    public func didReceive(_ request: URLRequest, response: HTTPURLResponse?, data: Data?) {
        let start = Double(request.value(forHTTPHeaderField: startKey) ?? "") ?? 0
        let cost = start > 0 ? Date().timeIntervalSince1970 - start : 0
        let url = request.url?.absoluteString ?? "-"
        let method = request.httpMethod ?? "-"
        let code = response?.statusCode ?? -1
        print("[EZNet][telemetry] \(method) \(url) -> \(code) in \(String(format: "%.3f", cost))s")
    }
}
