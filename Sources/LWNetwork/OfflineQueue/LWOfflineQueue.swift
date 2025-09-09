import Foundation

/**
 LWOfflineTask & LWOfflineQueue
 ------------------------------
 作用：
 这是一个**离线任务队列**：当设备离线或接口失败时，把需要 POST/PUT 等写操作的请求**落盘排队**，
 由队列在后台定期重试，使用**指数退避 + 优先级**控制发送顺序，直到成功（2xx）或达到最大重试次数。

 特点：
 - 任务持久化到本地 JSON 文件（App 退出/崩溃后仍可恢复）；
 - 高/中/低优先级排序，优先发送高优先；
 - 指数退避（支持抖动）避免惊群；
 - 线程安全：内部串行队列；
 - API 简单：`enqueue`、`start/stop`、`flush` 即可。

 使用示例：
 ```swift
 // 1) 创建任务并入队（例如某个离线表单）
 let payload = try JSONEncoder().encode(["title": "Hello"])
 let task = LWOfflineTask(method: "POST",
                          url: "https://api.example.com/v1/posts",
                          body: payload,
                          priority: .normal)
 LWOfflineQueue.shared.enqueue(task)

 // 2) 启动轮询器（建议在 App 启动时调用一次）
 LWOfflineQueue.shared.start(interval: 2.0)

 // 3) 可在网络恢复时手动触发一次
 // LWOfflineQueue.shared.flush()

 // 4) 停止（如登出/清理时）
 // LWOfflineQueue.shared.stop()
 ```

 注意事项：
 - 该实现只处理**请求体 + 方法 + URL**（可选 headers），不包含鉴权刷新等逻辑；
   若需要携带 Token，请让你的网络拦截器（如 `LWAuthInterceptor`）在发送时自动加头。
 - 仅当响应状态码属于 **200..<300** 才视为成功；其他情况会按指数退避重试。
 - 默认持久化文件位于 **Application Support** 目录：`offline-queue.json`。
 */

// MARK: - Model

public struct LWOfflineTask: Codable {
    public enum Priority: String, Codable { case high, normal, low }

    public var id: String = UUID().uuidString
    public var method: String
    public var url: String
    public var headers: [String: String]? // 可选请求头（旧版本文件无此字段时会自然为 nil）
    public var body: Data
    public var priority: Priority
    public var retries: Int = 0
    public var nextAt: Date = Date()

    public init(method: String, url: String, body: Data, priority: Priority, headers: [String: String]? = nil) {
        self.method = method
        self.url = url
        self.body = body
        self.priority = priority
        self.headers = headers
    }
}

private extension LWOfflineTask.Priority {
    var order: Int {
        switch self {
        case .high: return 0
        case .normal: return 1
        case .low: return 2
        }
    }
}

// MARK: - Queue

public final class LWOfflineQueue {

    public static let shared = LWOfflineQueue()

    // 可调参数
    public var maxBackoffExponent: Int = 6                // 2^6 = 64s 上限
    public var baseBackoff: TimeInterval = 2.0            // 退避基数秒
    public var jitter: Double = 0.2                        // 抖动系数（0~1）
    public var maxRetries: Int = .max                      // 默认不限重试次数

    // 依赖
    private let session: URLSession

    // 持久化
    private let fileURL: URL

    // 并发控制
    private let q = DispatchQueue(label: "lw.offline.queue")
    private var timer: DispatchSourceTimer?
    private var ticking = false

    public init(session: URLSession = .shared, fileURL: URL? = nil) {
        self.session = session
        self.fileURL = fileURL ?? LWOfflineQueue.defaultFileURL()
        // 确保目录存在
        try? FileManager.default.createDirectory(at: self.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - Lifecycle

    /// 开始周期性处理
    public func start(interval: TimeInterval = 2.0) {
        q.sync {
            timer?.cancel(); timer = nil
            let t = DispatchSource.makeTimerSource(queue: q)
            t.schedule(deadline: .now() + 0.5, repeating: interval)
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            timer = t
        }
    }

    /// 停止周期性处理
    public func stop() {
        q.sync {
            timer?.cancel()
            timer = nil
        }
    }

    /// 立即尝试处理（不会与周期任务并发）
    public func flush() {
        q.async { [weak self] in self?.tick(force: true) }
    }

    // MARK: - API

    public func enqueue(_ task: LWOfflineTask) {
        q.async {
            var list = self.load()
            list.append(task)
            self.save(list)
        }
    }

    // MARK: - Core

    private func tick(force: Bool = false) {
        if ticking { return }
        ticking = true
        defer { ticking = false }

        var list = load()
        guard !list.isEmpty else { return }

        let now = Date()
        list.sort { (a, b) -> Bool in
            if a.priority.order != b.priority.order { return a.priority.order < b.priority.order }
            return a.nextAt < b.nextAt
        }

        let group = DispatchGroup()
        var remain: [LWOfflineTask] = []
        remain.reserveCapacity(list.count)

        for var task in list {
            if !force && task.nextAt > now {
                remain.append(task)
                continue
            }
            guard let url = URL(string: task.url) else {
                // 无效 URL，直接跳过
                continue
            }

            var req = URLRequest(url: url)
            req.httpMethod = task.method
            req.httpBody = task.body
            if let headers = task.headers {
                for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
            }

            group.enter()
            session.dataTask(with: req) { _, resp, _ in
                defer { group.leave() }
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    task.retries += 1
                    if task.retries <= self.maxRetries {
                        let delay = self.computeBackoff(for: task.retries)
                        task.nextAt = Date().addingTimeInterval(delay)
                        remain.append(task)
                    }
                    return
                }
                // 成功：不入 remain（即删除）
            }.resume()
        }

        group.wait()
        save(remain)
    }

    private func computeBackoff(for retries: Int) -> TimeInterval {
        let exp = min(max(1, retries), maxBackoffExponent)
        var delay = baseBackoff * pow(2.0, Double(exp - 1))
        if jitter > 0 {
            let j = min(max(jitter, 0), 1)
            let delta = delay * j
            delay += Double.random(in: -delta...delta)
            delay = max(0, delay)
        }
        return delay
    }

    // MARK: - Persistence

    private func load() -> [LWOfflineTask] {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else { return [] }
        do {
            let list = try JSONDecoder().decode([LWOfflineTask].self, from: data)
            return list
        } catch {
            // 文件损坏时清空
            try? FileManager.default.removeItem(at: fileURL)
            return []
        }
    }

    private func save(_ list: [LWOfflineTask]) {
        do {
            let data = try JSONEncoder().encode(list)
            // 原子写入：先写到临时文件，再替换
            let tmp = fileURL.appendingPathExtension("tmp")
            try data.write(to: tmp, options: .atomic)
            _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmp)
            // 若 replace 失败，回退为直接写（仍然是 .atomic）
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try data.write(to: fileURL, options: .atomic)
            }
        } catch {
            // 忽略持久化错误
        }
    }

    // MARK: - Helpers

    private static func defaultFileURL() -> URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent("offline-queue.json")
    }
}
