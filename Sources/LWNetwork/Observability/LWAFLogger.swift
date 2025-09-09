import Foundation
import Alamofire
import OSLog

/**
 LWAFLogger (Alamofire EventMonitor)
 -----------------------------------
 作用：
 一个可插拔的 **Alamofire 日志器**，实现 `EventMonitor`。
 记录请求/响应的关键信息（方法、URL、状态码、耗时、字节数），并支持：
 - 可选打印请求头；
 - 可选输出响应体前 N 字节预览；
 - （可选）输出 cURL 命令辅助排查（若你的 AF 版本支持）。

 使用示例：
 ```swift
 // 1) 作为 EventMonitor 注入到 Alamofire.Session
 let logger = LWAFLogger(logHeaders: false, bodyPreviewLength: 0, logCURL: false)
 let session = Session(eventMonitors: [logger])
 // 或交给你的客户端（如 LWAlamofireClient）
 // let client = LWAlamofireClient(config: .init(), interceptor: nil, monitors: [logger])

 // 2) 发起请求时会自动打印日志到 Logger.lwNetwork
 ```

 注意事项：
 - 为防止泄露敏感信息，默认**不打印**请求头与响应体预览；请按需开启。
 - `cURL` 输出依赖 Alamofire 的 `cURLDescription` 扩展；部分版本为异步回调形式。
 - 本实现仅使用 `EventMonitor` 的安全回调，不会阻断或修改请求流程。
 */
public final class LWAFLogger: @unchecked Sendable, EventMonitor {

    // MARK: - Public

    /// 事件回调所使用的队列（避免阻塞主线程）
    public let queue = DispatchQueue(label: "lw.af.logger")

    public let logHeaders: Bool
    public let bodyPreviewLength: Int      // 0 表示不打印
    public let logCURL: Bool

    public init(logHeaders: Bool = false, bodyPreviewLength: Int = 0, logCURL: Bool = false) {
        self.logHeaders = logHeaders
        self.bodyPreviewLength = max(0, bodyPreviewLength)
        self.logCURL = logCURL
    }

    // MARK: - Internal timing

    private var starts: [UUID: CFAbsoluteTime] = [:]
    private let lock = NSLock()

    private func markStart(_ id: UUID) {
        lock.lock(); starts[id] = CFAbsoluteTimeGetCurrent(); lock.unlock()
    }
    private func duration(for id: UUID) -> TimeInterval? {
        lock.lock(); defer { lock.unlock() }
        guard let t = starts.removeValue(forKey: id) else { return nil }
        return CFAbsoluteTimeGetCurrent() - t
    }

    // MARK: - EventMonitor hooks (Request lifecycle)

    public func requestDidResume(_ request: Request) {
        markStart(request.id)
        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"
        if logHeaders, let headers = request.request?.allHTTPHeaderFields, !headers.isEmpty {
            let h = headers.map { "\($0): \($1)" }.joined(separator: ", ")
            Logger.lwNetwork.debug("➡️ \(method) \(url) headers=[\(h)]")
        } else {
            Logger.lwNetwork.debug("➡️ \(method) \(url)")
        }

        guard logCURL else { return }
        // 某些 AF 版本提供异步回调形式的 cURL 构造
        #if canImport(Alamofire)
        if let dataReq = request as? DataRequest {
            dataReq.cURLDescription { curl in
                Logger.lwNetwork.debug("curl: \(curl)")
            }
        } else {
            request.cURLDescription { curl in
                Logger.lwNetwork.debug("curl: \(curl)")
            }
        }
        #endif
    }

    public func requestDidFinish(_ request: Request) {
        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"
        let code = request.response?.statusCode
        let dur = duration(for: request.id) ?? 0

        if let error = request.error {
            Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(String(format: "%.3f", dur))s err=\(error.localizedDescription)")
        } else {
            Logger.lwNetwork.debug("⬅️ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(String(format: "%.3f", dur))s")
        }
    }

    // MARK: - Response parsing (DataRequest)

    public func request(_ request: DataRequest, didParseResponse response: DataResponse<Data?, AFError>) {
        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"
        let code = response.response?.statusCode
        let bytes = response.data?.count ?? 0
        let dur = duration(for: request.id) ?? 0

        switch response.result {
        case .success(let data?):
            if bodyPreviewLength > 0, let s = String(data: data.prefix(bodyPreviewLength), encoding: .utf8) {
                Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(String(format: "%.3f", dur))s bytes=\(bytes) body=\(s)")
            } else {
                Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(String(format: "%.3f", dur))s bytes=\(bytes)")
            }
        case .success(nil):
            Logger.lwNetwork.debug("⬅️ \(method) \(url) HTTP \(code ?? -1) cost=\(String(format: "%.3f", dur))s bytes=0")
        case .failure(let err):
            if bodyPreviewLength > 0, let data = response.data, let s = String(data: data.prefix(bodyPreviewLength), encoding: .utf8) {
                Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(String(format: "%.3f", dur))s err=\(err.localizedDescription) body=\(s)")
            } else {
                Logger.lwNetwork.error("❌ \(method) \(url) \(code.map { "HTTP \($0) " } ?? "")cost=\(String(format: "%.3f", dur))s err=\(err.localizedDescription)")
            }
        }
    }

    // MARK: - Download (optional)

    public func request(_ request: DownloadRequest, didFinishDownloadingTo destinationURL: URL) {
        let method = request.request?.httpMethod ?? "—"
        let url = request.request?.url?.absoluteString ?? "nil"
        let code = request.response?.statusCode
        let dur = duration(for: request.id) ?? 0
        let size = (try? FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.intValue ?? 0
        Logger.lwNetwork.debug("⬇️ \(method) \(url) HTTP \(code ?? -1) cost=\(String(format: "%.3f", dur))s file=\(destinationURL.lastPathComponent) bytes=\(size)")
    }
}
