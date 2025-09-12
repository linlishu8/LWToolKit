import Foundation
import Alamofire
import LWToolKit

/// 鉴权要求：取代布尔参数，语义更明确
public enum AuthRequirement { case required, none }

/// 单次请求的可选项（自定义头、Idempotency-Key 等）
public struct RequestOptions {
    public var headers: HTTPHeaders = HTTPHeaders()
    public var idempotencyKey: String? = nil
    public init(headers: HTTPHeaders = HTTPHeaders(), idempotencyKey: String? = nil) {
        self.headers = headers; self.idempotencyKey = idempotencyKey
    }
}

/// 语义化的资源声明：通过静态工厂生成 GET/POST/FORM 请求
public struct Resource<T: Decodable> {
    let path: String
    let method: HTTPMethod
    let auth: AuthRequirement
    let task: LWTask
    let options: RequestOptions

    public init(_ path: String, method: HTTPMethod, auth: AuthRequirement, task: LWTask, options: RequestOptions = .init()) {
        self.path = path; self.method = method; self.auth = auth; self.task = task; self.options = options
    }
}

public extension Resource {
    /// GET 请求
    static func get(_ path: String, auth: AuthRequirement = .none, query: [String: Any]? = nil, options: RequestOptions = .init()) -> Resource<T> {
        .init(path, method: .get, auth: auth, task: .requestParameters(query ?? [:], encoding: URLEncoding.queryString), options: options)
    }
    /// POST JSON 请求
    static func postJSON(_ path: String, auth: AuthRequirement = .none, body: Encodable, options: RequestOptions = .init()) -> Resource<T> {
        .init(path, method: .post, auth: auth, task: .requestJSONEncodable(body), options: options)
    }
    /// POST 表单请求（x-www-form-urlencoded 或自定义编码）
    static func postForm(_ path: String, auth: AuthRequirement = .none, params: [String: Any], options: RequestOptions = .init()) -> Resource<T> {
        .init(path, method: .post, auth: auth, task: .requestParameters(params, encoding: URLEncoding.httpBody), options: options)
    }
}
