import Foundation

/**
 LWSessionManager
 ----------------
 作用：
 一个**轻量的“会话 ID”管理器**，用于在 App 运行期间维护一个全局的 `sessionId`（通常在冷启动/重启时变化）。
 采用 `actor` 实现，天然线程安全，可在并发环境下读写。常用于：
 - 为所有请求打上 `X-Session-Id` 头（便于后端聚合一次 App 运行内的请求）；
 - 崩溃/日志/埋点中标记当前会话；
 - 在用户登出或关键场景切换时**旋转**（重置）会话 ID。

 使用示例：
 ```swift
 // 1) 读取会话 ID（任意线程，需 await）
 let sid = await LWSessionManager.shared.sessionId

 // 2) 旋转会话（例如用户登出后）
 await LWSessionManager.shared.rotate()

 // 3) 监听会话变化（例如刷新 UI 或更新埋点上下文）
 // NotificationCenter.default.addObserver(forName: LWSessionManager.didRotate, object: nil, queue: .main) { note in
 //     if let newId = note.userInfo?["sessionId"] as? String {
 //         print("Session rotated -> \(newId)")
 //     }
 // }
 ```

 注意事项：
 - `sessionId` 默认在实例化时生成一个新的 UUID；应用重启后会自然变化。
 - 若需**跨重启保持同一会话**，可改为持久化到 `UserDefaults/Keychain` 并在 `init` 时读取。
 - 该管理器只负责 session 语义，不负责 Trace ID；请求级 Trace ID 建议使用独立的中间件（如 `LWTelemetryMiddleware`）。
 */
public actor LWSessionManager {

    // 会话旋转通知（userInfo: ["sessionId": String]）
    public static let didRotate = Notification.Name("LWSessionManager.didRotate")

    public static let shared = LWSessionManager()

    public private(set) var sessionId: String

    public init(id: String = UUID().uuidString) {
        self.sessionId = id
    }

    /// 手动设置会话 ID（谨慎使用，一般用 rotate() 即可）
    public func set(_ id: String) {
        sessionId = id
        notifyRotation()
    }

    /// 旋转会话：生成一个新的 UUID
    public func rotate() {
        sessionId = UUID().uuidString
        notifyRotation()
    }

    // MARK: - Private

    private func notifyRotation() {
        let id = sessionId
        // 在主线程上发通知，便于 UI 层监听
        Task { @MainActor in
            NotificationCenter.default.post(name: Self.didRotate, object: nil, userInfo: ["sessionId": id])
        }
    }
}
