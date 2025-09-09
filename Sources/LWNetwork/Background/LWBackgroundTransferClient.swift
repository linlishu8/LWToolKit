import Foundation

/**
 LWBackgroundTransferClient
 ----------------
 作用：
 一个**支持后台下载**的轻量网络客户端。基于 `URLSession` 的 background 会话，
 提供：并发任务管理、进度/完成/失败回调（代理）、任务合并标识、暂停/续传、
 以及 App 重启后**恢复挂起任务**。为兼容自定义 `URLProtocol` 的本地调试，
 若 URL 的 host 是 `demo.local` 将自动使用前台默认会话。

 使用示例：
 ```swift
 // 1) AppDelegate 中转交后台回调（必须）
 // func application(_ application: UIApplication,
 //                  handleEventsForBackgroundURLSession identifier: String,
 //                  completionHandler: @escaping () -> Void) {
 //     LWBackgroundTransferClient.handleEvents(for: identifier, completionHandler: completionHandler)
 // }

 // 2) 设置代理，开始下载
 final class DLDelegate: LWBackgroundTransferDelegate {
     func bgProgress(id: String, bytesWritten: Int64, totalBytes: Int64) {
         print("progress \(id): \(bytesWritten)/\(totalBytes)")
     }
     func bgFinished(id: String, fileURL: URL) { print("done:", id, fileURL) }
     func bgFailed(id: String, error: Error) { print("fail:", id, error) }
 }
 let d = DLDelegate()
 LWBackgroundTransferClient.shared.delegate = d
 let id = LWBackgroundTransferClient.shared.download(id: "file1",
                                                     from: URL(string: "https://example.com/a.zip")!)

 // 3) 暂停与续传
 LWBackgroundTransferClient.shared.pause(id: id) { resumeData in
     if let data = resumeData {
         LWBackgroundTransferClient.shared.resume(id: id, resumeData: data)
     }
 }

 // 4) App 启动时恢复系统持有的挂起任务（如崩溃/被杀）
 LWBackgroundTransferClient.shared.restorePendingTasks()
 ```

 注意事项：
 - 使用 background 会话需要在 AppDelegate 实现 `handleEventsForBackgroundURLSession` 并调用
   `LWBackgroundTransferClient.handleEvents(...)`，否则系统唤醒后无法正确完成收尾。
 - 通过 `task.taskDescription` 绑定应用侧的下载 `id`，避免重启后字典映射丢失。
 - 暂停/续传依赖服务器支持 HTTP Range（`resumeData`）。
 */
public protocol LWBackgroundTransferDelegate: AnyObject {
    func bgProgress(id: String, bytesWritten: Int64, totalBytes: Int64)
    func bgFinished(id: String, fileURL: URL)
    func bgFailed(id: String, error: Error)
}

public final class LWBackgroundTransferClient: NSObject {

    // MARK: - Singleton
    public static let shared = LWBackgroundTransferClient()

    // MARK: - Configuration
    public var identifier: String = "com.example.lw.bg" {
        didSet { rebuildSessions() }
    }
    /// 使用后台会话；当 URL host 为 demo.local 时会强制使用前台会话
    public var useBackground: Bool = true {
        didSet { /* 会在下一次构建任务时生效 */ }
    }
    /// 网络策略
    public var allowsCellularAccess: Bool = true {
        didSet { applyConfig() }
    }
    public var waitsForConnectivity: Bool = true {
        didSet { applyConfig() }
    }
    public var isDiscretionary: Bool = false {
        didSet { applyConfig() }
    }

    // MARK: - Sessions
    private var bgSession: URLSession!
    private var fgSession: URLSession!

    // MARK: - State
    private var tasks: [String: URLSessionDownloadTask] = [:] // key: id
    public weak var delegate: LWBackgroundTransferDelegate?

    private let stateQueue = DispatchQueue(label: "lw.bg.transfer.state")

    // MARK: - Init
    override private init() {
        super.init()
        rebuildSessions()
    }

    // MARK: - Public API

    /// 开始一个下载任务（返回 id，便于暂停/取消/续传）
    @discardableResult
    public func download(id: String, from url: URL) -> String {
        let session = (useBackground && url.host != "demo.local") ? bgSession! : fgSession!
        let task = session.downloadTask(with: url)
        task.taskDescription = id
        stateQueue.sync {
            tasks[id] = task
        }
        task.resume()
        return id
    }

    /// 取消某个任务
    public func cancel(id: String) {
        stateQueue.sync {
            tasks[id]?.cancel()
            tasks[id] = nil
        }
    }

    /// 暂停并获取 resumeData（需服务端支持 Range）。回调在主线程
    public func pause(id: String, completion: @escaping (Data?) -> Void) {
        var task: URLSessionDownloadTask?
        stateQueue.sync { task = tasks[id] }
        guard let t = task else { DispatchQueue.main.async { completion(nil) }; return }
        t.cancel(byProducingResumeData: { data in
            DispatchQueue.main.async { completion(data) }
        })
    }

    /// 用 resumeData 续传
    public func resume(id: String, resumeData: Data) {
        // 默认用后台会话续传；若最初是前台任务也可续传（系统会处理）
        let task = bgSession.downloadTask(withResumeData: resumeData)
        task.taskDescription = id
        stateQueue.sync { tasks[id] = task }
        task.resume()
    }

    /// 恢复系统仍持有的挂起任务（应用启动时调用）
    public func restorePendingTasks() {
        let group = DispatchGroup()
        for session in [bgSession!, fgSession!] {
            group.enter()
            session.getAllTasks { [weak self] all in
                guard let self = self else { group.leave(); return }
                self.stateQueue.sync {
                    for case let t as URLSessionDownloadTask in all {
                        if let id = t.taskDescription {
                            self.tasks[id] = t
                        }
                    }
                }
                group.leave()
            }
        }
        group.wait()
    }

    // MARK: - Private (sessions)

    private func rebuildSessions() {
        // background session
        let bgCfg = URLSessionConfiguration.background(withIdentifier: identifier)
        bgCfg.allowsCellularAccess = allowsCellularAccess
        bgCfg.waitsForConnectivity = waitsForConnectivity
        bgCfg.isDiscretionary = isDiscretionary
        bgCfg.sessionSendsLaunchEvents = true
        bgSession = URLSession(configuration: bgCfg, delegate: self, delegateQueue: nil)

        // foreground(default) session
        let fgCfg = URLSessionConfiguration.default
        fgCfg.allowsCellularAccess = allowsCellularAccess
        fgCfg.waitsForConnectivity = waitsForConnectivity
        fgSession = URLSession(configuration: fgCfg, delegate: self, delegateQueue: nil)
    }

    private func applyConfig() {
        // 重新创建会话以应用新配置
        rebuildSessions()
    }
}

// MARK: - URLSessionDownloadDelegate

extension LWBackgroundTransferClient: URLSessionDownloadDelegate {
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let id = downloadTask.taskDescription ?? stateQueue.sync { tasks.first(where: { $0.value == downloadTask })?.key } ?? "unknown"
        delegate?.bgProgress(id: id, bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
    }

    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskDescription ?? stateQueue.sync { tasks.first(where: { $0.value == downloadTask })?.key } ?? "unknown"
        delegate?.bgFinished(id: id, fileURL: location)
        stateQueue.sync { tasks[id] = nil }
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let id = task.taskDescription ?? stateQueue.sync { tasks.first(where: { $0.value == task })?.key } ?? "unknown"
        delegate?.bgFailed(id: id, error: error)
        stateQueue.sync { tasks[id] = nil }
    }
}

// MARK: - AppDelegate hook

extension LWBackgroundTransferClient {
    private static var pendingHandler: (() -> Void)?

    /// AppDelegate 中转交后台事件回调，完成后需调用系统的 completionHandler
    public static func handleEvents(for identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == LWBackgroundTransferClient.shared.identifier else {
            completionHandler()
            return
        }
        pendingHandler = completionHandler
    }

    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        // 系统要求在所有回调完成后再调用 completionHandler
        LWBackgroundTransferClient.pendingHandler?()
        LWBackgroundTransferClient.pendingHandler = nil
    }
}
