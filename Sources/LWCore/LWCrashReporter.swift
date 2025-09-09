import Foundation

/**
 LWCrashReporter
 ----------------
 作用：
 一个**超轻量的崩溃/异常上报门面**。提供统一接口 `record(_:userInfo:)` 与 `setUser(id:)`，
 便于在项目中无侵入地切换或同时对接 Crashlytics、Sentry 等第三方 SDK。
 内部使用串行队列保证线程安全，并支持**注册多个后端**（recorders / userSetters）。

 使用示例：
 ```swift
 // 1) 在应用启动时注册你实际使用的 SDK
 LWCrashReporter.shared.register(
     record: { error, userInfo in
         // 示例：Crashlytics
         // Crashlytics.crashlytics().record(error: error, userInfo: userInfo)
         // 或示例：Sentry
         // SentrySDK.capture(error: error) { scope in
         //     userInfo?.forEach { scope.setExtra(value: $0.value, key: $0.key) }
         // }
     },
     setUser: { userId in
         // 示例：Crashlytics
         // Crashlytics.crashlytics().setUserID(userId ?? "")
         // 示例：Sentry
         // if let id = userId { SentrySDK.setUser(User(userId: id)) } else { SentrySDK.setUser(nil) }
     }
 )

 // 2) 业务代码中上报非致命异常
 enum NetworkError: Error { case invalidResponse }
 LWCrashReporter.shared.record(NetworkError.invalidResponse, userInfo: [
     "endpoint": "/v1/users/me",
     "status"  : 502
 ])

 // 3) 设置/清除当前用户（登录/登出时调用）
 LWCrashReporter.shared.setUser(id: "u_123456")
 LWCrashReporter.shared.setUser(id: nil) // 登出时清空
 ```

 注意事项：
 - `record` 的回调在内部串行队列上执行；如需更新 UI，请切回主线程。
 - 你可以注册多个后端（例如同时打点到 Crashlytics 与 Sentry）；会按注册顺序依次调用。
 - 若需要在 Debug 包抑制上报，可在调用处或注册处用 `#if !DEBUG` 包裹。
 */

public protocol LWCrashReporting {
    /// 上报一个非致命异常
    /// - Parameters:
    ///   - error: 错误对象
    ///   - userInfo: 额外上下文（需可序列化）
    func record(_ error: Error, userInfo: [String: Any]?)

    /// 设置当前用户（可传 nil 清除）
    func setUser(id: String?)
}

public final class LWCrashReporter: LWCrashReporting {

    // MARK: - Singleton
    public static let shared = LWCrashReporter()

    // MARK: - Init
    public init() {}

    // MARK: - Backend registry

    /// 线程安全：内部串行队列
    private let queue = DispatchQueue(label: "lw.crash.reporter")

    /// 已注册的后端回调
    private var recorders: [(Error, [String: Any]?) -> Void] = []
    private var userSetters: [(String?) -> Void] = []

    /// 注册一个后端（如 Crashlytics / Sentry）
    /// - Parameters:
    ///   - record: 上报实现
    ///   - setUser: 设置用户实现（可选）
    public func register(
        record: @escaping (Error, [String: Any]?) -> Void,
        setUser: ((String?) -> Void)? = nil
    ) {
        queue.sync {
            recorders.append(record)
            if let setter = setUser {
                userSetters.append(setter)
            }
        }
    }

    // MARK: - LWCrashReporting

    public func record(_ error: Error, userInfo: [String: Any]? = nil) {
        queue.async { [recorders] in
            recorders.forEach { $0(error, userInfo) }
        }
    }

    public func setUser(id: String?) {
        queue.async { [userSetters] in
            userSetters.forEach { $0(id) }
        }
    }
}
