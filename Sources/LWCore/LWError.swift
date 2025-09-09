import Foundation

/**
 LWError
 ----------------
 作用：
 一个在项目/示例中通用的错误模型，统一封装**网络错误**与**业务错误**两类场景，
 便于跨模块传递与展示，同时提供辅助属性（错误码、消息、域等）以及 `NSError` 映射，
 方便与依赖库或系统 API 对接。

 使用示例：
 ```swift
 // 1) 构建错误
 let e1: LWError = .network(code: 502, message: "Bad Gateway")
 let e2: LWError = .business(code: 1001, message: "余额不足")

 // 2) 统一处理
 func handle(_ error: Error) {
     if let e = error as? LWError {
         print("⛔️ [\(e.domain)] code=\(e.code ?? -1) message=\(e.message)")
     } else {
         print("⛔️ \(error.localizedDescription)")
     }
 }

 // 3) 与 NSError 互通
 let ns = e1.nsError
 // 一些 API 需要 NSError：someAPIFunc(error: ns)

 // 4) UI 展示
 let toast = (e2 as Error).localizedDescription  // 直接可用于提示文案
 ```

 注意事项：
 - `business` 场景指请求成功但服务端返回了业务失败态（如 code != 0）。
 - `network` 场景指请求链路异常（超时、断网、网关错误等）。
 - 只定义必要字段；更复杂的错误上下文（如 requestId、endpoint）可在外层结构承载。
 */
public enum LWError: Error, Equatable {

    /// 请求链路/协议相关错误（超时、断网、DNS、网关等）
    case network(code: Int, message: String)

    /// 业务语义错误（请求成功但语义失败，如余额不足、权限不足）
    case business(code: Int, message: String)
}

// MARK: - Convenience

public extension LWError {

    /// 错误码（若无则为 nil）
    var code: Int? {
        switch self {
        case let .network(code, _):  return code
        case let .business(code, _): return code
        }
    }

    /// 错误信息
    var message: String {
        switch self {
        case let .network(_, msg):  return msg
        case let .business(_, msg): return msg
        }
    }

    /// 错误域
    var domain: String {
        switch self {
        case .network:  return "LWError.network"
        case .business: return "LWError.business"
        }
    }

    /// 是否为网络类错误
    var isNetwork: Bool {
        if case .network = self { return true }
        return false
    }

    /// 是否为业务类错误
    var isBusiness: Bool {
        if case .business = self { return true }
        return false
    }

    /// 映射到 NSError，便于与系统/第三方 API 互通
    var nsError: NSError {
        NSError(
            domain: domain,
            code: code ?? -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}

// MARK: - LocalizedError

extension LWError: LocalizedError {
    public var errorDescription: String? { message }
}
