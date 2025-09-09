import Foundation

/**
 LWNetworkError
 ----------------
 作用：
 统一封装网络层错误的类型与上下文信息（HTTP 状态码、原始响应体、底层错误）。
 便于上层做**可重试判断**、UI 提示、日志上报与调试定位。

 使用示例：
 ```swift
 // 1) 构建错误
 let e1 = LWNetworkError(kind: .timeout, statusCode: nil)
 let e2 = LWNetworkError(kind: .server, statusCode: 500, data: Data("oops".utf8))

 // 2) 判定是否建议重试
 if e1.isRetryable { /* 重试策略 */ }

 // 3) 统一提示文案
 print(e2.localizedDescription) // 自动组合 kind/状态码/片段

 // 4) 从系统错误快速映射
 let urlErr = URLError(.timedOut)
 let mapped = LWNetworkError.from(urlErr)

 // 5) 业务逻辑分支
 if e2.isServerError { /* 服务端异常 */ }
 if e2.isClientError { /* 客户端/鉴权问题 */ }
 ```

 注意事项：
 - `data` 可携带原始响应体（如 JSON 文本）；`responseSnippet` 会尝试提取 UTF-8 预览片段。
 - `underlying` 为底层错误（如 `URLError` / `AFError`），用于调试与上报。
 */
public struct LWNetworkError: Error, LocalizedError, Equatable {

    // MARK: - Types

    public enum Kind: Equatable {
        case network
        case timeout
        case cancelled
        case server
        case decoding
        case unauthorized
        case forbidden
        case notFound
        case rateLimited
        case invalidRequest
        case blocked
        case unknown
    }

    // MARK: - Stored Properties

    public let kind: Kind
    public let statusCode: Int?
    public let data: Data?
    public let underlying: Error?

    // MARK: - Init

    public init(kind: Kind,
                statusCode: Int? = nil,
                data: Data? = nil,
                underlying: Error? = nil) {
        self.kind = kind
        self.statusCode = statusCode
        self.data = data
        self.underlying = underlying
    }

    // MARK: - Convenience

    /// 是否建议重试（网络抖动、超时、频率限制）
    public var isRetryable: Bool {
        kind == .network || kind == .timeout || kind == .rateLimited
    }

    /// 是否为 4xx 客户端错误
    public var isClientError: Bool {
        guard let c = statusCode else { return false }
        return (400...499).contains(c)
    }

    /// 是否为 5xx 服务端错误
    public var isServerError: Bool {
        guard let c = statusCode else { return false }
        return (500...599).contains(c)
    }

    /// 从响应体中提取 UTF-8 片段（最多 512 字节），便于日志/提示
    public var responseSnippet: String? {
        guard let data = data, !data.isEmpty else { return nil }
        let maxLen = min(data.count, 512)
        let slice = data.prefix(maxLen)
        return String(data: slice, encoding: .utf8)
    }

    /// 更友好的本地化错误描述
    public var errorDescription: String? {
        var parts: [String] = []

        switch kind {
        case .network: parts.append("网络异常")
        case .timeout: parts.append("请求超时")
        case .cancelled: parts.append("请求已取消")
        case .server: parts.append("服务端错误")
        case .decoding: parts.append("解析失败")
        case .unauthorized: parts.append("未授权")
        case .forbidden: parts.append("无权限")
        case .notFound: parts.append("资源不存在")
        case .rateLimited: parts.append("频率受限")
        case .invalidRequest: parts.append("非法请求")
        case .blocked: parts.append("已拦截")
        case .unknown: parts.append("未知错误")
        }

        if let code = statusCode {
            parts.append("(HTTP \(code))")
        }

        if let text = responseSnippet, !text.isEmpty {
            parts.append("：\(text)")
        } else if let u = underlying {
            parts.append("：\(u.localizedDescription)")
        }

        return parts.joined()
    }

    // MARK: - Mapping

    /// 从系统错误快速映射为 LWNetworkError（保留 underlying）
    public static func from(_ error: Error, statusCode: Int? = nil, data: Data? = nil) -> LWNetworkError {
        if let e = error as? LWNetworkError { return e }

        if let urlErr = error as? URLError {
            switch urlErr.code {
            case .timedOut: return LWNetworkError(kind: .timeout, statusCode: statusCode, data: data, underlying: error)
            case .cancelled: return LWNetworkError(kind: .cancelled, statusCode: statusCode, data: data, underlying: error)
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return LWNetworkError(kind: .network, statusCode: statusCode, data: data, underlying: error)
            default:
                return LWNetworkError(kind: .unknown, statusCode: statusCode, data: data, underlying: error)
            }
        }

        return LWNetworkError(kind: .unknown, statusCode: statusCode, data: data, underlying: error)
    }

    // MARK: - Builders

    /// 返回一个附带新响应体的副本
    public func with(data: Data?) -> LWNetworkError {
        LWNetworkError(kind: kind, statusCode: statusCode, data: data, underlying: underlying)
    }

    /// 返回一个附带新状态码的副本
    public func with(statusCode: Int?) -> LWNetworkError {
        LWNetworkError(kind: kind, statusCode: statusCode, data: data, underlying: underlying)
    }
    
    public static func == (lhs: LWNetworkError, rhs: LWNetworkError) -> Bool {
        return lhs.kind == rhs.kind
            && lhs.statusCode == rhs.statusCode
            && lhs.data == rhs.data
    }
}
