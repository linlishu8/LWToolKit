import Foundation

/**
 LWEventSource (Server‑Sent Events, SSE)
 --------------------------------------
 作用：
 轻量的 **SSE（text/event-stream）** 客户端，支持：
 - 基于 `URLSession` 的**长连接**读取；
 - 解析 `event:` / `data:` / `id:` / `retry:` 字段（多行 data 合并，以 `\n` 连接）；
 - **自动重连**（指数退避，可被服务端 `retry:` 覆盖），携带 `Last-Event-ID`；
 - 事件回调：`onEvent`、可选 `onOpen`、`onError`；
 - 自定义请求头。

 使用示例：
 ```swift
 let url = URL(string: "https://example.com/stream")!
 let es = LWEventSource(url: url, headers: ["Authorization": "Bearer ..."]) { evt in
     print("event=\(evt.event) data=\(evt.data)")
 } onOpen: {
     print("SSE opened")
 } onError: { err in
     print("SSE error:", err.localizedDescription)
 }

 es.connect()

 // 需要时关闭：
 // es.close()
 ```

 注意事项：
 - SSE 会话是**单向**的文本流，字段间以行分隔，事件块以**空行**分割；详见 WHATWG EventSource 规范。
 - 默认 `Accept: text/event-stream`，若服务端要求其他头（如鉴权）可通过 `headers` 传入。
 - 自动重连默认从 1s 开始指数回退至 30s；若服务端下发 `retry: <ms>`，会覆盖下一次重连间隔。
 - 该实现以**简洁为主**，适合作为 Demo 或轻量生产使用；若需严格 UTF‑8 断点处理、代理、证书锁定等，
   可在此基础上扩展。
 */

// MARK: - Model

public struct LWEvent {
    public let event: String
    public let data: String
    public let id: String?

    public init(event: String, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

// MARK: - Event Source

public final class LWEventSource: NSObject {

    // MARK: - Public

    public typealias Handler = (LWEvent) -> Void
    public typealias VoidHandler = () -> Void
    public typealias ErrorHandler = (Error) -> Void

    public private(set) var isConnected: Bool = false

    public init(url: URL,
                headers: [String: String] = [:],
                onEvent handler: @escaping Handler,
                onOpen: VoidHandler? = nil,
                onError: ErrorHandler? = nil) {
        self.url = url
        self.headers = headers
        self.onEvent = handler
        self.onOpen = onOpen
        self.onError = onError
        super.init()
    }

    /// 连接到 SSE 流
    public func connect() {
        guard !isConnected && !isClosing else { return }
        isClosing = false

        var req = URLRequest(url: url)
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        // Last-Event-ID（若有）
        if let last = lastEventId {
            req.setValue(last, forHTTPHeaderField: "Last-Event-ID")
        }
        // 自定义头
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        // 新建会话与任务
        let cfg = URLSessionConfiguration.default
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = 60 * 60 // SSE 长连接
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: queue)

        buffer.removeAll(keepingCapacity: false)
        task = session?.dataTask(with: req)
        task?.resume()
        isConnected = true
        // 重置指数退避（若之前断开过）
        currentBackoff = baseBackoff
    }

    /// 主动关闭连接（不会再自动重连）
    public func close() {
        isClosing = true
        isConnected = false
        task?.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        buffer.removeAll(keepingCapacity: false)
    }

    // MARK: - Private

    private let url: URL
    private let headers: [String: String]
    private let onEvent: Handler
    private let onOpen: VoidHandler?
    private let onError: ErrorHandler?

    private var session: URLSession?
    private var task: URLSessionDataTask?

    private var buffer: Data = Data()
    private var lastEventId: String?

    private var isClosing = false

    // 重连策略
    private let baseBackoff: TimeInterval = 1
    private let maxBackoff: TimeInterval = 30
    private var currentBackoff: TimeInterval = 1
    private var serverSuggestedRetryMS: Int? = nil

    private let queue = OperationQueue() // delegate 回调队列
    private let parseLock = NSLock()

    private func scheduleReconnect() {
        guard !isClosing else { return }
        isConnected = false

        // 优先服务端 retry: <ms>
        if let ms = serverSuggestedRetryMS {
            let delay = max(0.1, Double(ms) / 1000.0)
            serverSuggestedRetryMS = nil
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.connect()
            }
            return
        }

        // 指数退避
        let delay = currentBackoff
        currentBackoff = min(maxBackoff, currentBackoff * 2)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    private func handleOpenIfNeeded(_ response: HTTPURLResponse?) {
        guard let http = response, (200..<300).contains(http.statusCode) else { return }
        onOpen?()
    }

    private func parseAvailableEvents() {
        parseLock.lock(); defer { parseLock.unlock() }

        // 将缓冲区解码为字符串并尽量规范化换行
        guard !buffer.isEmpty else { return }
        let chunk = String(decoding: buffer, as: UTF8.self)
        // 查找最后一个完整的空行分隔（事件块之间以空行分割）
        // 为简单起见，这里按两连换行 "\n\n" 处理（\r\n 会在替换后转成 \n）
        var text = chunk.replacingOccurrences(of: "\r\n", with: "\n")
                         .replacingOccurrences(of: "\r", with: "\n")
        // 找到最后一个完整事件块边界
        guard let lastSepRange = text.range(of: "\n\n", options: .backwards) else { return }

        let complete = String(text[..<lastSepRange.upperBound])
        let remain = String(text[lastSepRange.upperBound...])
        buffer = Data(remain.utf8)

        // 按空行切块
        let blocks = complete.components(separatedBy: "\n\n")
        for block in blocks where !block.isEmpty {
            parseBlock(block)
        }
    }

    private func parseBlock(_ block: String) {
        var eventName = "message"
        var eventId: String?
        var dataLines: [String] = []

        for line in block.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.isEmpty { continue }
            if line.first == ":" { // comment/heartbeat
                continue
            }
            // field: value（value 前的空格需去掉）
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let field = parts.first.map(String.init) ?? ""
            let rawValue = parts.count > 1 ? String(parts[1]) : ""
            let value = rawValue.hasPrefix(" ") ? String(rawValue.dropFirst()) : rawValue

            switch field {
            case "event":
                if !value.isEmpty { eventName = value }
            case "data":
                dataLines.append(value)
            case "id":
                if !value.isEmpty { eventId = value }
            case "retry":
                if let ms = Int(value), ms >= 0 { serverSuggestedRetryMS = ms }
            default:
                break
            }
        }

        let data = dataLines.joined(separator: "\n")
        if let id = eventId { lastEventId = id }
        if !data.isEmpty {
            onEvent(LWEvent(event: eventName, data: data, id: eventId))
        }
    }
}

// MARK: - URLSessionDataDelegate

extension LWEventSource: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // 累积数据并尝试解析完整事件
        buffer.append(data)
        parseAvailableEvents()
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 连接自然结束或错误：尝试重连
        if let e = error as NSError? {
            // 主动关闭时忽略
            if !isClosing {
                onError?(e)
                scheduleReconnect()
            }
        } else {
            // 无错误但结束（例如服务器关闭）：尝试重连
            if !isClosing {
                scheduleReconnect()
            }
        }
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                           completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        handleOpenIfNeeded(response as? HTTPURLResponse)
        completionHandler(.allow)
    }
}
