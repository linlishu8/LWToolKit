
/*
 作用：将底层错误（AFError/URLError/HTTP 状态）统一映射为领域错误，便于 UI 友好提示与遥测统计。
 使用示例：
   do {
     let user: User = try await AppNetwork.shared.client.request(UserAPI.getUser(id: "42"), as: User.self)
   } catch {
     let appErr = AppNetworkError.from(error)
     toast(appErr.userMessage)
   }
*/
import Foundation
import Alamofire
import LWToolKit

public enum AppNetworkError: Error, CustomStringConvertible {
    case notAuthenticated
    case forbidden
    case notFound
    case conflict
    case validation(message: String?)
    case rateLimited
    case server(message: String?)
    case timeout
    case cancelled
    case unreachable
    case tlsPinFailed
    case decode
    case unknown(message: String?)

    public var description: String {
        switch self {
        case .notAuthenticated: return "未登录或登录已过期"
        case .forbidden: return "无权限执行该操作"
        case .notFound: return "资源不存在"
        case .conflict: return "资源冲突或状态不一致"
        case .validation(let m): return "参数错误" + (m.map { "：\($0)" } ?? "")
        case .rateLimited: return "请求过于频繁"
        case .server(let m): return "服务器开小差" + (m.map { "：\($0)" } ?? "")
        case .timeout: return "请求超时"
        case .cancelled: return "请求已取消"
        case .unreachable: return "网络不可用"
        case .tlsPinFailed: return "证书校验失败"
        case .decode: return "数据解析失败"
        case .unknown(let m): return "未知错误" + (m.map { "：\($0)" } ?? "")
        }
    }

    public var userMessage: String { description }

    public static func from(_ error: Error) -> AppNetworkError {
        // 优先：网络库自身的错误
        if let e = error as? LWNetworkError {
            // 一些常见映射
            switch e.kind {
            case .timeout: return .timeout
            case .cancelled: return .cancelled
            case .network: return .unreachable
            case .unauthorized: return .notAuthenticated
            case .forbidden: return .forbidden
            case .notFound: return .notFound
            case .rateLimited: return .rateLimited
            case .invalidRequest: return .validation(message: e.responseSnippet)
            case .server: return .server(message: e.responseSnippet)
            case .decoding: return .decode
            case .blocked: return .forbidden
            default: break
            }
            // 兜底：根据状态码粗粒度判断
            if let code = e.statusCode {
                switch code {
                case 401: return .notAuthenticated
                case 403: return .forbidden
                case 404: return .notFound
                case 409: return .conflict
                case 422: return .validation(message: e.responseSnippet)
                case 429: return .rateLimited
                case 500...599: return .server(message: e.responseSnippet)
                default: break
                }
            }
        }

        // 其次：URLError
        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .timedOut: return .timeout
            case .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .networkConnectionLost, .dnsLookupFailed:
                return .unreachable
            case .cancelled: return .cancelled
            case .serverCertificateUntrusted, .serverCertificateHasBadDate, .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid, .secureConnectionFailed:
                return .tlsPinFailed
            default: break
            }
        }

        // 再次：AFError
        if let af = error as? AFError {
            if af.isExplicitlyCancelledError { return .cancelled }
            if case .invalidURL(_) = af { return .unreachable }
            if case .sessionTaskFailed(let underlying) = af, (underlying as? URLError)?.code == .timedOut {
                return .timeout
            }
        }

        // 解码失败
        if error is DecodingError { return .decode }

        // 兜底
        return .unknown(message: (error as NSError).localizedDescription)
    }
}
