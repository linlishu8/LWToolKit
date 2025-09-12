/* 
  作用：集中列出所有可配置参数，并提供默认值。
*/
import Foundation
import Alamofire
import LWToolKit

public enum AppEZConfig {
    public struct Params {
        public var baseURL: String
        public var retryLimit: Int = 3
        public var requestTimeout: TimeInterval = 30
        public var cacheTTL: TimeInterval = 300
        public var enablePinning: Bool = false
        public var logSampling: Double = 0.1
        public var redactedHeaders: [String] = ["Authorization","Cookie","Set-Cookie","X-Session-Id"]
        public var defaultHeaders: HTTPHeaders = AppEZConfig.defaultHeaders()
        public var middlewares: [LWMiddleware] = [TestTelemetryMiddleware()]
        public var interceptor: RequestInterceptor? = nil
        public init(baseURL: String) { self.baseURL = baseURL }
    }
    public static func defaultHeaders() -> HTTPHeaders {
        var h = HTTPHeaders()
        let lang = Locale.preferredLanguages.first ?? Locale.current.identifier
        h.add(name: "Accept-Language", value: lang)
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        h.add(name: "X-App-Version", value: ver)
        let sys = UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        h.add(name: "X-Device-OS", value: sys)
        h.add(name: "Accept", value: "application/json")
        return h
    }
}
