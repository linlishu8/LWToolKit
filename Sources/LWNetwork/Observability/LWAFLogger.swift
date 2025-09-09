import Foundation
import Alamofire
import OSLog

/**
 LWAFLogger (Alamofire EventMonitor)
 -----------------------------------
 作用：
 一个可插拔的 **Alamofire 网络日志器**，实现 `EventMonitor` 接口，用于统一、可控地打印
 请求/响应的关键信息（方法、URL、状态码、耗时、字节数），并支持：
 - **采样**（减少日志噪声与开销）；
 - **可选打印请求头**（默认不打印，支持脱敏）；
 - **可选响应体预览**（按字节数截断 + JSON 脱敏）；
 - **可选 cURL** 输出（便于抓包/复现）；
 - 失败、解码等异常路径有一致的输出格式，利于排障。

 使用示例：
 ```swift
 var opts = LWLogOptions()
 opts.enabled = true
 opts.logHeaders = true
 opts.bodyPreviewBytes = 1024
 let logger = LWAFLogger(options: opts)

 let client = LWAlamofireClient(config: .init(),
                                interceptor: LWAuthInterceptor(),
                                monitors: [logger])
 ```

 安全与隐私：
 - **默认不打印请求头与响应体**，避免泄露敏感信息；
 - 打开后也会对常见敏感头与 JSON key 做脱敏；
 - 建议线上开启采样（如 0.1），开发/测试阶段可全量。

 兼容性与注意事项：
 - 依赖 Alamofire `EventMonitor`；cURL 输出依赖 Alamofire 的 `cURLDescription`；
 - 日志使用 `Logger.lwNetwork`（见 `Logger+LWNetwork.swift`）；
 - 本类只做“监听打印”，不改变请求流程与结果。
 */

/// Alamofire 网络日志器：采样 / 头部可选打印（支持脱敏）/ 响应体预览（支持脱敏）/ cURL。
public final class LWAFLogger: @unchecked Sendable, EventMonitor {

    // EventMonitor 回调队列（避免阻塞主线程）
    public let queue = DispatchQueue(label: "lw.af.logger")

    // 配置
    private let options: LWLogOptions
    public init(options: LWLogOptions) { self.options = options }
    /// 兼容旧用法：`LWAFLogger()`
    public convenience init() { self.init(options: .init()) }

    // 采样
    private func hitSample() -> Bool { Double.random(in: 0...1) <= max(0, min(1, options.sampleRate)) }

    // 起止时间记录
    private var starts: [UUID: CFAbsoluteTime] = [:]
    private let lock = NSLock()
    private func markStart(_ id: UUID) { lock.lock(); starts[id] = CFAbsoluteTimeGetCurrent(); lock.unlock() }
    private func duration(for id: UUID) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        guard let t = starts.removeValue(forKey: id) else { return nil }
        return CFAbsoluteTimeGetCurrent() - t
    }
    // 改为静态，避免捕获 self
    private static func fmt(_ s: TimeInterval) -> String { String(format: "%.3f", s) }

    // MARK: - Request lifecycle

    public func requestDidResume(_ request: Request) {
        guard options.enabled, hitSample() else { return }
        markStart(request.id)

        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"

        if options.logHeaders, let headers = request.request?.allHTTPHeaderFields, !headers.isEmpty {
            let safe = LWLogRedactor.headers(headers, redact: options.redactHeaders)
            let h = safe.map { "\($0): \($1)" }.joined(separator: ", ")
            Logger.lwNetwork.debug("➡️ \(method) \(url) headers=[\(h)]")
        } else {
            Logger.lwNetwork.debug("➡️ \(method) \(url)")
        }

        if options.logCURL {
            if let dataReq = request as? DataRequest {
                dataReq.cURLDescription { curl in
                    Logger.lwNetwork.debug("curl: \(curl)")
                }
            } else {
                request.cURLDescription { curl in
                    Logger.lwNetwork.debug("curl: \(curl)")
                }
            }
        }
    }

    public func requestDidFinish(_ request: Request) {
        guard options.enabled else { return }
        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"
        let code = request.response?.statusCode
        let dur  = duration(for: request.id) ?? 0

        if let error = request.error {
            Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(Self.fmt(dur))s err=\(error.localizedDescription)")
        } else {
            Logger.lwNetwork.debug("⬅️ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(Self.fmt(dur))s")
        }
    }

    // MARK: - Data response (body 预览)

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        guard options.enabled, hitSample() else { return }
        let method = request.request?.httpMethod ?? "—"
        let url    = request.request?.url?.absoluteString ?? "nil"
        let code   = response.response?.statusCode
        let bytes  = response.data?.count ?? 0
        let dur    = duration(for: request.id) ?? 0

        switch response.result {
        case .success(let data?):
            if options.bodyPreviewBytes > 0,
               let preview = LWLogRedactor.bodyPreview(data, limit: options.bodyPreviewBytes, redactKeys: options.redactBodyKeys) {
                Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(Self.fmt(dur))s bytes=\(bytes) body=\n\(preview)")
            } else {
                Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(Self.fmt(dur))s bytes=\(bytes)")
            }
        case .success:
            Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(Self.fmt(dur))s bytes=0")
        case .failure(let err):
            if options.bodyPreviewBytes > 0,
               let preview = LWLogRedactor.bodyPreview(response.data, limit: options.bodyPreviewBytes, redactKeys: options.redactBodyKeys) {
                Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(Self.fmt(dur))s err=\(err.localizedDescription) body=\n\(preview)")
            } else {
                Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(Self.fmt(dur))s err=\(err.localizedDescription)")
            }
        }
    }

    // MARK: - Download

    public func request(_ request: DownloadRequest, didFinishDownloadingTo destinationURL: URL) {
        guard options.enabled, hitSample() else { return }
        let method = request.request?.httpMethod ?? "—"
        let url    = request.request?.url?.absoluteString ?? "nil"
        let code   = request.response?.statusCode
        let dur    = duration(for: request.id) ?? 0
        let size   = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.intValue ?? 0
        Logger.lwNetwork.debug("⬇️ \(method) \(url) HTTP \(code ?? -1) cost=\(Self.fmt(dur))s file=\(destinationURL.lastPathComponent) bytes=\(size)")
    }
}


