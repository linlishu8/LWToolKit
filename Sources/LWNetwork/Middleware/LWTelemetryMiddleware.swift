import Foundation
import OSLog

/**
 LWTelemetryMiddleware
 ---------------------
 作用：
 一个**轻量的网络遥测中间件**，用于在请求/响应阶段自动：
 - 注入 Trace ID 与 Session ID 头（便于后端与日志关联）；
 - 记录并输出**时延、状态码、字节数**等关键指标到 `Logger.lwNetwork`；
 - 通过通知广播结果，方便上层订阅做 UI 指标/打点。

 特性：
 - Trace ID 自动生成（UUID），也可由上游预先设置（若已存在则不覆盖）。
 - 线程安全地按 Trace ID 记录开始时间，在响应时计算耗时。
 - 可选打印请求头与响应体片段（谨慎在生产开启）。

 使用示例：
 ```swift
 // 1) 构造并挂到网络配置（示例与 LWAlamofireClient 配合）
 let telemetry = LWTelemetryMiddleware(
     traceKey: "X-Trace-Id",
     sessionKey: "X-Session-Id",
     sessionProvider: { LWSessionManager.shared.sessionId },
     logHeaders: false,
     bodyPreviewLength: 0
 )
 var cfg = LWNetworkConfig()
 cfg.middlewares.insert(telemetry, at: 0)
 let client = LWAlamofireClient(config: cfg)

 // 2) 监听通知（例如做 UI 指标面板）
 // NotificationCenter.default.addObserver(forName: LWTelemetryMiddleware.didFinish, object: nil, queue: .main) { note in
 //     if let m = note.userInfo?["metrics"] as? LWTelemetryMiddleware.Metrics {
 //         print("trace=\(m.traceId) status=\(m.statusCode ?? -1) cost=\(m.duration)s bytes=\(m.bytes ?? 0)")
 //     }
 // }
 ```

 注意事项：
 - 此中间件不修改请求语义，仅添加头并记录指标；若你的服务端不需要 session/trace，可将对应 key 留空或不使用。
 - 在生产环境中请谨慎开启 `logHeaders` 与 `bodyPreviewLength`（避免打印敏感信息/大体量日志）。
 */
public struct LWTelemetryMiddleware: LWMiddleware {

    // MARK: - Notification & Model

    public static let didFinish = Notification.Name("LWTelemetryMiddleware.didFinish")

    /// 一次请求的关键指标
    public struct Metrics {
        public let method: String
        public let url: String
        public let traceId: String?
        public let statusCode: Int?
        public let duration: TimeInterval
        public let bytes: Int?
        public let error: Error?
    }

    // MARK: - Configuration

    public let traceKey: String          // 例如 "X-Trace-Id"
    public let sessionKey: String        // 例如 "X-Session-Id"
    public let sessionProvider: () -> String
    public let logHeaders: Bool
    public let bodyPreviewLength: Int    // 0 表示不打印

    public init(traceKey: String,
                sessionKey: String,
                sessionProvider: @escaping () -> String,
                logHeaders: Bool = false,
                bodyPreviewLength: Int = 0) {
        self.traceKey = traceKey
        self.sessionKey = sessionKey
        self.sessionProvider = sessionProvider
        self.logHeaders = logHeaders
        self.bodyPreviewLength = max(0, bodyPreviewLength)
    }

    // MARK: - Internal timing store

    private static let timeQueue = DispatchQueue(label: "lw.telemetry.times")
    private static var startTimes: [String: CFAbsoluteTime] = [:]

    private static func setStart(_ t: CFAbsoluteTime, for trace: String) {
        timeQueue.sync { startTimes[trace] = t }
    }

    private static func popStart(for trace: String) -> CFAbsoluteTime? {
        var v: CFAbsoluteTime?
        timeQueue.sync {
            v = startTimes.removeValue(forKey: trace)
        }
        return v
    }

    // MARK: - LWMiddleware

    /// 预处理：注入 trace / session 头
    public func prepare(_ r: URLRequest) -> URLRequest {
        var req = r

        // Trace ID：若外部未设置，则自动生成
        if traceKey.isEmpty == false, req.value(forHTTPHeaderField: traceKey) == nil {
            req.setValue(UUID().uuidString, forHTTPHeaderField: traceKey)
        }

        // Session ID：每次请求都覆盖为最新值
        if sessionKey.isEmpty == false {
            req.setValue(sessionProvider(), forHTTPHeaderField: sessionKey)
        }

        return req
    }

    /// 即将发送：记录开始时间并打印基本信息
    public func willSend(_ request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "nil"
        let trace = request.value(forHTTPHeaderField: traceKey)

        if let t = trace { Self.setStart(CFAbsoluteTimeGetCurrent(), for: t) }

        if logHeaders {
            let headers = (request.allHTTPHeaderFields ?? [:]).map { "\($0): \($1)" }.joined(separator: ", ")
            Logger.lwNetwork.debug("➡️ \(method) \(url) trace=\(trace ?? "-") headers=[\(headers)]")
        } else {
            Logger.lwNetwork.debug("➡️ \(method) \(url) trace=\(trace ?? "-")")
        }
    }

    /// 收到响应：计算耗时、打印结果、发送通知
    public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "nil"
        let trace = request.value(forHTTPHeaderField: traceKey)

        let start = trace.flatMap { Self.popStart(for: $0) } ?? CFAbsoluteTimeGetCurrent()
        let duration = CFAbsoluteTimeGetCurrent() - start

        switch result {
        case .success(let (http, data)):
            if bodyPreviewLength > 0, let s = String(data: data.prefix(bodyPreviewLength), encoding: .utf8) {
                Logger.lwNetwork.debug("⬅️ \(http.statusCode) \(method) \(url) trace=\(trace ?? "-") cost=\(String(format: "%.3f", duration))s bytes=\(data.count) body=\(s)")
            } else {
                Logger.lwNetwork.debug("⬅️ \(http.statusCode) \(method) \(url) trace=\(trace ?? "-") cost=\(String(format: "%.3f", duration))s bytes=\(data.count)")
            }
            NotificationCenter.default.post(name: Self.didFinish, object: nil, userInfo: [
                "metrics": Metrics(method: method, url: url, traceId: trace, statusCode: http.statusCode, duration: duration, bytes: data.count, error: nil)
            ])

        case .failure(let e):
            let code = e.statusCode
            if bodyPreviewLength > 0, let s = e.responseSnippet {
                Logger.lwNetwork.error("❌ \(code.map { "HTTP \($0)" } ?? "—") \(method) \(url) trace=\(trace ?? "-") cost=\(String(format: "%.3f", duration))s err=\(e.localizedDescription) body=\(s)")
            } else {
                Logger.lwNetwork.error("❌ \(code.map { "HTTP \($0)" } ?? "—") \(method) \(url) trace=\(trace ?? "-") cost=\(String(format: "%.3f", duration))s err=\(e.localizedDescription)")
            }
            NotificationCenter.default.post(name: Self.didFinish, object: nil, userInfo: [
                "metrics": Metrics(method: method, url: url, traceId: trace, statusCode: code, duration: duration, bytes: e.data?.count, error: e)
            ])
        }
    }
}
