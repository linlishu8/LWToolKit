import Foundation
import Alamofire
import OSLog

/**
 LWAuthInterceptor
 -----------------
 作用：
 基于 **Alamofire** 的请求拦截器，负责：
 - 在需要鉴权的请求上自动附加 `Authorization: Bearer <token>` 与 `X-Session-Id`；
 - 智能重试：401 时尝试刷新/获取 Access Token 后重试；5xx/网络波动/429（根据 `Retry-After`）指数退避重试；
 - 避免泄漏内部标记头：会移除 `__Requires-Auth__` 这个仅供内部中间件识别的标记。

 依赖：
 - 你的工程应提供 `LWTokenStore.shared.validAccessToken()`（可抛错，必要时内部刷新）；
 - 你的工程应提供 `LWSessionManager.shared.sessionId: String`（`async` 可访问）。

 使用示例：
 ```swift
 let interceptor = LWAuthInterceptor()
 let session = Session(interceptor: interceptor,
                       eventMonitors: [LWAFLogger()]) // 可选日志

 // 示例端点（见 LWAPI.swift）
 let ep = LWAPI.get(env: .dev, path: "/v1/me")

 // 客户端（示例：LWAlamofireClient）中传入该 interceptor 即可
 let client = LWAlamofireClient(config: .init(), interceptor: interceptor)
 let user: User = try await client.request(ep)
 ```

 注意事项：
 - 仅当请求头里包含 `__Requires-Auth__: 1` 时才会附加鉴权信息（由 `LWAPI` 或你的中间件约定设置）。
 - `Retry-After` 头部同时支持秒数字段或 RFC1123/HTTP-date，解析失败时退回指数退避。
 - 最大服务器/429/网络重试次数为 2 次（可按需修改 `maxServerRetry`/`maxNetworkRetry`）。
 */
public final class LWAuthInterceptor: RequestInterceptor {

    // MARK: - Tunables

    private let maxServerRetry = 2           // 5xx/429 的最大重试次数
    private let maxNetworkRetry = 2          // 网络类错误的最大重试次数
    private let baseBackoff: TimeInterval = 1.0  // 指数退避基准秒

    public init() {}

    // MARK: - Adapt

    public func adapt(_ urlRequest: URLRequest,
                      for session: Session,
                      completion: @escaping (Result<URLRequest, Error>) -> Void) {
        Task {
            var req = urlRequest
            do {
                if let needs = req.value(forHTTPHeaderField: "__Requires-Auth__"), needs == "1" {
                    // 清理内部标记头，避免发给服务端
                    req.setValue(nil, forHTTPHeaderField: "__Requires-Auth__")
                    // 取 token & sessionId
                    let token = try await LWTokenStore.shared.validAccessToken()
                    let sid = await LWSessionManager.shared.sessionId
                    if req.value(forHTTPHeaderField: "Authorization") == nil {
                        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    }
                    req.setValue(sid, forHTTPHeaderField: "X-Session-Id")
                }
                completion(.success(req))
            } catch {
                Logger.lwNetwork.error("Auth adapt failed: \(String(describing: error))")
                completion(.failure(error))
            }
        }
    }

    // MARK: - Retry

    public func retry(_ request: Request,
                      for session: Session,
                      dueTo error: Error,
                      completion: @escaping (RetryResult) -> Void) {
        // 优先使用 HTTP 状态码；否则从底层错误推断
        let http = request.response
        let status = http?.statusCode

        // 401：尝试刷新 token 后直接重试（只要刷新不抛错）
        if status == 401 {
            Task {
                do {
                    _ = try await LWTokenStore.shared.validAccessToken()
                    completion(.retry)
                } catch {
                    completion(.doNotRetryWithError(error))
                }
            }
            return
        }

        // 429：尊重 Retry-After 或指数退避
        if status == 429, request.retryCount < maxServerRetry {
            if let after = retryAfterSeconds(http) {
                completion(.retryAfter(after))
            } else {
                let delay = pow(2.0, Double(request.retryCount)) * baseBackoff
                completion(.retryWithDelay(delay))
            }
            return
        }

        // 5xx：指数退避，最多 maxServerRetry 次
        if let s = status, (500..<600).contains(s), request.retryCount < maxServerRetry {
            let delay = pow(2.0, Double(request.retryCount)) * baseBackoff
            completion(.retryWithDelay(delay))
            return
        }

        // 网络类错误（如超时/掉线）
        if let urlErr = error as? URLError, request.retryCount < maxNetworkRetry {
            switch urlErr.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                let delay = pow(2.0, Double(request.retryCount)) * baseBackoff
                completion(.retryWithDelay(delay))
                return
            default: break
            }
        }

        // 默认不重试
        completion(.doNotRetry)
    }

    // MARK: - Helpers

    /// 解析 Retry-After: 秒 或 HTTP-date
    private func retryAfterSeconds(_ response: HTTPURLResponse?) -> TimeInterval? {
        guard let value = response?.value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let secs = TimeInterval(value) { return max(0, secs) }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        fmt.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        if let date = fmt.date(from: value) {
            let delta = date.timeIntervalSinceNow
            return delta > 0 ? delta : nil
        }
        return nil
    }
}
