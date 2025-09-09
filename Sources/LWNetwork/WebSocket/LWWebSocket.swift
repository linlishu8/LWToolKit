import Foundation

/**
 LWWebSocket
 -----------
 作用：
 一个基于 `URLSessionWebSocketTask` 的**轻量 WebSocket 客户端**封装，提供：
 - 文本/二进制消息收发（`send(String/Data)`、`onText/onData` 回调）；
 - **自动重连**（指数退避至上限，手动关闭则不重连）；
 - **心跳保活**（定时 `ping`，可配置间隔）；
 - 连接/关闭/错误回调；
 - 自定义请求头。

 使用示例：
 ```swift
 let ws = LWWebSocket(url: URL(string: "wss://echo.websocket.org")!,
                      headers: ["Authorization": "Bearer …"],
                      keepAliveInterval: 20)

 ws.onOpen = { print("opened") }
 ws.onText = { print("text:", $0) }
 ws.onData = { print("data:", $0.count) }
 ws.onError = { print("error:", $0.localizedDescription) }
 ws.onClose = { code, reason in
     print("closed code=\(code?.rawValue ?? -1) reason=\(reason.flatMap { String(data: $0, encoding: .utf8) } ?? "-")")
 }

 ws.connect()

 Task {
     try await ws.send("hello")
 }

 // 需要时关闭：
 // ws.close()
 ```

 注意事项：
 - iOS 13+ 可用。`ws://` 需在 `Info.plist` 配置 ATS 例外；生产环境建议使用 `wss://`。
 - “连接已打开”的时机以 `URLSessionWebSocketDelegate.didOpenWithProtocol` 为准。
 - 自动重连默认从 1s 开始指数退避到 30s；手动 `close()` 后将不再重连。
 */
public final class LWWebSocket: NSObject {

    // MARK: - Public Handlers

    public var onOpen: (() -> Void)?
    public var onText: ((String) -> Void)?
    public var onData: ((Data) -> Void)?
    public var onError: ((Error) -> Void)?
    public var onClose: ((URLSessionWebSocketTask.CloseCode?, Data?) -> Void)?

    // MARK: - Config

    public let url: URL
    public let headers: [String: String]
    public let keepAliveInterval: TimeInterval

    // MARK: - State

    public private(set) var isConnected: Bool = false

    // MARK: - Internals

    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private let delegateQueue = OperationQueue()
    private let sync = DispatchQueue(label: "lw.websocket.sync")

    // reconnect
    private var shouldReconnect = true
    private var reconnectDelay: TimeInterval = 1
    private let maxReconnectDelay: TimeInterval = 30

    // keepalive
    private var pingTimer: DispatchSourceTimer?

    // MARK: - Init

    public init(url: URL,
                headers: [String: String] = [:],
                keepAliveInterval: TimeInterval = 20) {
        self.url = url
        self.headers = headers
        self.keepAliveInterval = keepAliveInterval
        super.init()
        let cfg = URLSessionConfiguration.default
        cfg.waitsForConnectivity = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        delegateQueue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: delegateQueue)
    }

    // MARK: - API

    /// 建立连接（若已连接则忽略）
    public func connect() {
        sync.async {
            guard self.task == nil else { return }
            var req = URLRequest(url: self.url)
            for (k, v) in self.headers { req.setValue(v, forHTTPHeaderField: k) }
            let t = self.session.webSocketTask(with: req)
            self.task = t
            self.shouldReconnect = true
            t.resume()
            self.startReceiveLoop()
        }
    }

    /// 发送文本
    public func send(_ text: String) async throws {
        try await withCheckedThrowingContinuation(isolation: nil) { (cont: CheckedContinuation<Void, Error>) in
            self.sync.async {
                guard let t = self.task else {
                    cont.resume(throwing: NSError(domain: "LWWebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebSocket not connected"]))
                    return
                }
                t.send(.string(text)) { error in
                    if let e = error { cont.resume(throwing: e) } else { cont.resume(returning: ()) }
                }
            }
        }
    }

    /// 发送二进制
    public func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation(isolation: nil) { (cont: CheckedContinuation<Void, Error>) in
            self.sync.async {
                guard let t = self.task else {
                    cont.resume(throwing: NSError(domain: "LWWebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebSocket not connected"]))
                    return
                }
                t.send(.data(data)) { error in
                    if let e = error { cont.resume(throwing: e) } else { cont.resume(returning: ()) }
                }
            }
        }
    }

    /// 发送 JSON（Encodable）
    public func sendJSON<T: Encodable>(_ value: T, encoder: JSONEncoder = JSONEncoder()) async throws {
        let data = try encoder.encode(value)
        try await send(data)
    }

    /// 主动关闭（不再自动重连）
    public func close(code: URLSessionWebSocketTask.CloseCode = .normalClosure, reason: String? = nil) {
        sync.async {
            self.shouldReconnect = false
            self.isConnected = false
            self.stopPingTimer()
            guard let t = self.task else { return }
            let reasonData = reason?.data(using: .utf8)
            t.cancel(with: code, reason: reasonData)
            self.task = nil
        }
    }

    // MARK: - Internal

    private func startReceiveLoop() {
        guard let t = self.task else { return }
        t.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let s):
                    self.onText?(s)
                case .data(let d):
                    self.onData?(d)
                @unknown default:
                    break
                }
                // 继续读
                self.startReceiveLoop()

            case .failure(let error):
                self.handleErrorAndMaybeReconnect(error)
            }
        }
    }

    private func handleErrorAndMaybeReconnect(_ error: Error) {
        onError?(error)
        isConnected = false
        stopPingTimer()
        // 清空当前 task（由重连重新创建）
        sync.async { self.task = nil }
        guard shouldReconnect else { return }
        let delay = reconnectDelay
        reconnectDelay = min(maxReconnectDelay, max(1, reconnectDelay * 2))
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }

    private func startPingTimer() {
        guard keepAliveInterval > 0 else { return }
        let timer = DispatchSource.makeTimerSource(queue: sync)
        timer.schedule(deadline: .now() + keepAliveInterval, repeating: keepAliveInterval)
        timer.setEventHandler { [weak self] in
            guard let self = self, let t = self.task else { return }
            t.sendPing { error in
                if let e = error {
                    self.onError?(e)
                    self.handleErrorAndMaybeReconnect(e)
                }
            }
        }
        timer.resume()
        pingTimer = timer
    }

    private func stopPingTimer() {
        pingTimer?.cancel()
        pingTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension LWWebSocket: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        reconnectDelay = 1
        startPingTimer()
        onOpen?()
    }

    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        onClose?(closeCode, reason)
        // 当服务器主动关闭时，也触发重连逻辑
        isConnected = false
        stopPingTimer()
        sync.async { self.task = nil }
        if shouldReconnect {
            let delay = reconnectDelay
            reconnectDelay = min(maxReconnectDelay, max(1, reconnectDelay * 2))
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.connect()
            }
        }
    }
}
