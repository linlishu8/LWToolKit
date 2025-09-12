import Foundation
import Alamofire
import LWToolKit

/// 环境管理器：负责读取默认环境、运行时切换与网络层重建
public final class TestAppEnvironment {
    public static let shared = TestAppEnvironment()
    private init() {}

    private let storeKey = "AppEnv.current"
    public private(set) var current: AppEnv = .prod

    /// 是否允许在 Release 构建中运行时切换（默认 false）
    public var allowRuntimeSwitchInRelease: Bool = false

    /// 启动时激活默认环境（Info.plist > 上次选择 > 代码默认）
    @discardableResult
    public func activateAtLaunch() -> AppEnv {
        if let cached = loadCached() {
            current = cached
        } else if let fromInfo = infoPlistDefault(), let env = AppEnv(rawValue: fromInfo) {
            current = env
        } else {
            current = .prod
        }
        rebuildNetwork(for: current)
        return current
    }

    /// 切换到指定环境（会清理凭证/缓存并重建网络层）
    public func switchEnv(to env: AppEnv) {
        #if !DEBUG
        guard allowRuntimeSwitchInRelease else {
            print("[AppEnv] Runtime switching is disabled in Release.")
            return
        }
        #endif
        guard env != current else { return }
        current = env
        saveCached(env)

        // 清理状态（避免跨环境污染）
        Task { try? await TokenStore.shared.save(nil) }
        HTTPCookieStorage.shared.removeCookies(since: .distantPast)
        URLCache.shared.removeAllCachedResponses()

        rebuildNetwork(for: env)

        // 广播变更
        NotificationCenter.default.post(name: .appEnvDidChange, object: env)
    }

    // MARK: - Private

    private func rebuildNetwork(for env: AppEnv) {
        var p = AppEZConfig.Params(baseURL: env.baseURL)
        p.enablePinning = env.enablePinning
        p.logSampling = env.logSampling

        // 合并额外头（X-Env 等）
        var headers = p.defaultHeaders
        for (k, v) in env.extraHeaders { headers.add(name: k, value: v) }
        p.defaultHeaders = headers

        _ = TestAppNetwork.shared.bootstrap(p)
    }

    private func saveCached(_ env: AppEnv) {
        if let data = try? JSONEncoder().encode(env) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
    private func loadCached() -> AppEnv? {
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let env = try? JSONDecoder().decode(AppEnv.self, from: data) {
            return env
        }
        return nil
    }
    private func infoPlistDefault() -> String? {
        Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String
    }
}

public extension Notification.Name {
    static let appEnvDidChange = Notification.Name("AppEnv.didChange")
}
