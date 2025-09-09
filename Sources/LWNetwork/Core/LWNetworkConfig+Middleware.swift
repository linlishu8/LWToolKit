import Foundation
import Alamofire
import OSLog

/**
 LWNetworkConfig & LWMiddleware
 ----------------
 作用：
 统一描述网络层的全局配置（超时、公共请求头、重试与缓存策略、证书锁定等）以及
 “请求中间件”协议。中间件可在**发起前**修改请求（如注入鉴权头），并在**收到响应**时
 获取结果做打点、解析或错误处理。

 使用示例：
 ```swift
 // 1) 自定义一个中间件：为需要鉴权的请求添加 Authorization 头，并做简单日志
 struct AuthMiddleware: LWMiddleware {
     let tokenProvider: () -> String?

     func prepare(_ request: URLRequest) -> URLRequest {
         var req = request
         if req.value(forHTTPHeaderField: "Authorization") == nil {
             if let t = tokenProvider() {
                 req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
             }
         }
         return req
     }

     func willSend(_ request: URLRequest) {
         Logger.lwNetwork.debug("➡️ \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")
     }

     func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
         switch result {
         case .success(let (http, _)):
             Logger.lwNetwork.debug("⬅️ \(http.statusCode) \(request.url?.absoluteString ?? "")")
         case .failure(let e):
             Logger.lwNetwork.error("❌ \(request.url?.absoluteString ?? "") error=\(String(describing: e))")
         }
     }
 }

 // 2) 组装全局配置
 var config = LWNetworkConfig()
 config.timeout = 15
 config.requestHeaders.add(name: "User-Agent", value: "LWApp/1.0")
 config.retryLimit = 2
 config.useETagCaching = true
 config.middlewares = [AuthMiddleware(tokenProvider: { "token_abc" })]

 // （可选）证书锁定：为域名提供 DER 证书数据（示例）
 // config.enablePinning = true
 // config.pinnedDomains["api.example.com"] = [derCertData1, derCertData2]
 // 若你在工程中定义了更丰富的 `LWPinningSets`，可赋值给 config.pinningSets

 // 3) 交给客户端（如 LWAlamofireClient）
 // let client = LWAlamofireClient(config: config)
 ```

 注意事项：
 - `LWMiddleware` 三个钩子：
   - `prepare`：可修改/返回新的 `URLRequest`（如加头、刷 session、签名）。
   - `willSend`：只读通知（已完成最终构建后、发起前）。
   - `didReceive`：带有 HTTP 响应或统一错误 `LWNetworkError` 的结果回调。
 - `enablePinning/pinnedDomains/pinningSets` 为**证书锁定**预留位；
   具体的验证逻辑需由你的客户端（如 `ServerTrustManager` 或自定义逻辑）实现。
 - `Logger.lwNetwork` 提供了统一子系统/分类的日志入口。
 */

// MARK: - Config

public struct LWNetworkConfig {
    public var timeout: TimeInterval = 20
    public var requestHeaders: HTTPHeaders = [:]

    public var traceHeaderKey: String = "X-Trace-Id"
    public var sessionHeaderKey: String = "X-Session-Id"
    public var retryLimit: Int = 2

    /// 纯缓存 TTL（单位秒，按需由客户端实现使用策略）
    public var cacheTTL: TimeInterval = 0

    /// 证书锁定开关与数据（需客户端执行实际校验）
    public var enablePinning: Bool = false
    public var pinnedDomains: [String: [Data]] = [:]
    public var pinningSets: LWPinningSets = [:] // 由工程内定义更复杂的结构时使用

    /// 中间件链
    public var middlewares: [LWMiddleware] = []

    /// 是否启用 ETag 缓存（交由客户端决定如何挂接 URLCache 与中间件）
    public var useETagCaching: Bool = false

    public init() {}
}

// MARK: - LWMiddleware

/// 网络中间件：可修改请求、观测发送、处理响应
public protocol LWMiddleware {
    /// 构建阶段：可返回修改后的请求（默认直接返回）
    func prepare(_ request: URLRequest) -> URLRequest

    /// 即将发送：观测/打点
    func willSend(_ request: URLRequest)

    /// 收到响应：携带 HTTP 响应 + Data 或统一错误
    func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest)
}

// 默认空实现，便于只实现需要的钩子
public extension LWMiddleware {
    func prepare(_ request: URLRequest) -> URLRequest { request }
    func willSend(_ request: URLRequest) {}
    func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {}
}

// MARK: - Small conveniences

public extension LWNetworkConfig {
    /// 追加一个公共请求头
    mutating func addHeader(_ name: String, _ value: String) {
        requestHeaders.add(name: name, value: value)
    }

    /// 追加一个中间件
    mutating func addMiddleware(_ m: LWMiddleware) {
        middlewares.append(m)
    }
}

