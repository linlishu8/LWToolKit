
/*
 作用：集中装配网络栈（AF Session、拦截器、日志监控、中间件、证书锁定等），统一暴露 client。
 使用示例：
   let user: User = try await AppNetwork.shared.client.request(UserAPI.getUser(id: "42"), as: User.self)
   print(user)
 特点/注意事项：
   - 需先引入 LWNetwork 与 Alamofire；如果方法签名与本 Demo 有出入，请按你的库版本微调。
   - 若未使用证书锁定，可删除 pinning.json，装配会自动跳过。
*/
import Foundation
import Alamofire
import LWToolKit

public final class AppNetwork {
    public static let shared = AppNetwork()

    public let client: LWAlamofireClient

    private init() {
        // 1) 拦截器（401 刷新/重试、会话头注入等）
        let interceptor = LWAuthInterceptor()

        // 2) 日志（可按需传 LWLogOptions；此处用默认）
        let logger = LWAFLogger()

        // 3) 中间件链（根据你的需求微调参数/顺序）
        let telemetry = LWTelemetryMiddleware(
            traceKey: "X-Trace-Id",
            sessionKey: "X-Session-Id",
            sessionProvider: { awaiter() }
        )
        // 将异步 sessionId 桥接为同步闭包（LWTelemetryMiddleware 要求 () -> String）
        // 这里用一个小工具，把 actor 的读取变为阻塞式读取（成本极低，仅在 prepare 阶段调用）
        func awaiter() -> String {
            let sema = DispatchSemaphore(value: 0)
            var id = ""
            Task { id = await LWSessionManager.shared.sessionId; sema.signal() }
            sema.wait()
            return id
        }

        let cache = LWCacheMiddleware(ttl: 120) // 命中 GET 2xx 的结果 120s（示例值）
        let limiter = LWTokenBucketLimiter(rate: 5, burst: 10, markHeader: true)
        let breaker = LWCircuitBreaker(name: "api-core",
                                       failureThreshold: 5,
                                       rollingSeconds: 30,
                                       halfOpenAfter: 60)

        var cfg = LWNetworkConfig()
        cfg.timeout = 30
        cfg.requestHeaders = HTTPHeaders([
            "Accept": "application/json",
            "User-Agent": "LWToolExample/1.0"
        ])
        cfg.useETagCaching = true
        cfg.middlewares = [telemetry, cache, limiter, breaker]

        // 可选：证书锁定（如你需要，把加载的 pinningSets 挂到 cfg 上；客户端当前不主动用 trust manager）
        // let sets = try? LWPinningProvider.loadLocalConfig() // 读取 Resources/pinning.json（DER Base64）
        // cfg.pinningSets = sets ?? [:]
        // cfg.enablePinning = true

        self.client = LWAlamofireClient(
            config: cfg,
            interceptor: interceptor,
            monitors: [logger]
        )
    }
}
