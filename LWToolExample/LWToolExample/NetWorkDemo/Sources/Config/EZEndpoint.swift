import Foundation
import Alamofire
import LWToolKit

/// 极简端点：业务仅需填写 path/method/参数/是否鉴权；可选 headers。
/// - 由拦截器识别 `requiresAuth` 并自动注入 `Authorization`。
public struct EZEndpoint: LWEndpoint {
    public var baseURL: URL { URL(string: TestAppNetwork.shared.baseURLString)! }
    public var path: String
    public var method: HTTPMethod
    public var task: LWTask
    public var requiresAuth: Bool
    public var headers: HTTPHeaders

    /// - Parameters:
    ///   - path: 接口路径（以 `/` 开头）
    ///   - method: HTTP 方法
    ///   - requiresAuth: 是否需要鉴权（触发拦截器注入 Bearer）
    ///   - task: 负载（Query / JSON / Multipart / Download）
    ///   - headers: 可选请求头（如需传 `X-Idempotency-Key` 等）
    public init(path: String,
                method: HTTPMethod,
                requiresAuth: Bool,
                task: LWTask,
                headers: HTTPHeaders = HTTPHeaders()) {
        self.path = path
        self.method = method
        self.requiresAuth = requiresAuth
        self.task = task
        self.headers = headers
    }
}
