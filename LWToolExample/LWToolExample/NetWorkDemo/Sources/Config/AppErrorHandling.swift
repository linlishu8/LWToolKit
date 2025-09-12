import Foundation
import Alamofire

/// 统一错误类型：将网络/解析/业务/鉴权失效等场景归一，便于 UI 层统一呈现。
public enum AppError: Error {
    /// 业务错误：通常来自 `{code != 0, message}` 的响应
    case business(code: Int, message: String)
    /// 未授权：通常表示刷新失败或会话过期（401）
    case unauthorized
    /// HTTP 层错误：4xx/5xx 非业务包裹
    case http(status: Int, body: String?)
    /// 解码失败（JSON 结构不匹配等）
    case decoding(underlying: Error)
    /// 网络异常（无网络、超时、SSL 等）
    case network(underlying: Error)
    /// 其它未知
    case unknown(underlying: Error)
}

/// 错误呈现协议：App 注入自己的 Toast/Alert 实现。
public protocol ErrorPresenter: AnyObject {
    func present(_ error: AppError)
}

/// 错误路由中心：网络层不直接弹 UI，通过它转交给 App 的 Presenter。
public enum AppErrorRouter {
    private static weak var presenter: ErrorPresenter?

    /// 注入自定义 Presenter（例如使用你们的 HUD/Alert）
    public static func setup(_ p: ErrorPresenter) { presenter = p }

    /// 路由一个错误到 UI；若未设置 Presenter，则打印兜底
    public static func route(_ error: Error) {
        let mapped = map(error)
        presenter?.present(mapped)
        if presenter == nil {
            print("[AppError] \(mapped)")
        }
        // 在此处也可统一做埋点上报
    }

    /// 将底层错误映射为 AppError（AFError/HTTP/解码/网络等）
    public static func map(_ error: Error) -> AppError {
        if let e = error as? AppError { return e }
        if let af = error as? AFError {
            switch af {
            case .responseValidationFailed(let reason):
                if case let .unacceptableStatusCode(code) = reason {
                    if code == 401 { return .unauthorized }
                    return .http(status: code, body: nil)
                }
                return .http(status: -1, body: nil)
            case .responseSerializationFailed:
                return .decoding(underlying: af)
            case .sessionTaskFailed(let underlying):
                return .network(underlying: underlying)
            default:
                return .unknown(underlying: af)
            }
        }
        return .unknown(underlying: error)
    }
}
