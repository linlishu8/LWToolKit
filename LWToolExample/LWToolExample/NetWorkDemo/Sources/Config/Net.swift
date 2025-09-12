import Foundation
import Alamofire

/// 统一的极简请求入口：将 Resource 转为 EZEndpoint 并走 AppAPI.request
public enum Net {
    /// 发起请求并解析为 `T`
    public static func request<T: Decodable>(_ r: Resource<T>) async throws -> T {
        var headers = r.options.headers
        if let key = r.options.idempotencyKey {
            headers.add(name: "X-Idempotency-Key", value: key)
        }
        let ep = EZEndpoint(path: r.path, method: r.method, requiresAuth: (r.auth == .required), task: r.task, headers: headers)
        return try await AppAPI.request(ep, as: T.self)
    }
}
