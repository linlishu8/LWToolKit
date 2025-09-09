import Foundation

/**
 LWTokenStore
 ------------
 作用：
 一个**并发安全（actor）**的 Token 管理器，负责：
 - 保存/读取 `access`、`refresh`、`expiry`；
 - 在 Access Token 将要过期时**自动刷新**（合并并发刷新，避免多次命中后端）；
 - 将 Token 持久化到 Keychain（配合 `LWNetKeychain`）；
 - 提供便捷的 `validAccessToken()` 获取逻辑，业务侧只关心“拿一个可用的 AccessToken”。

 使用示例：
 ```swift
 // 1) 启动时从 Keychain 恢复（如有）
 await LWTokenStore.shared.loadFromKeychain()

 // 2) 配置刷新器（传入使用 refresh token 换取新对的实现）
 LWTokenStore.shared.setRefresher { refreshToken in
     // 调你的刷新接口，返回新的 Token
     // 这里只是示例：
     let new = try await MyAuthAPI.refresh(refreshToken: refreshToken)
     return LWTokenStore.Token(access: new.access, refresh: new.refresh, expiry: new.expiry)
 }

 // 3) 登录后注入首个 Token（或使用上面的 loadFromKeychain）
 let first = LWTokenStore.Token(access: "a", refresh: "r", expiry: Date().addingTimeInterval(3600))
 await LWTokenStore.shared.bootstrap(first)

 // 4) 需要用到时获取一个**有效** Access Token（内部会自动刷新）
 let token = try await LWTokenStore.shared.validAccessToken()

 // 5) 登出
 await LWTokenStore.shared.logout()
 ```

 注意事项：
 - `validAccessToken()` 默认在**过期前 30 秒**触发刷新（可通过参数或默认余量调整）。
 - 刷新的并发调用会**合并**为一次（`refreshTask`）；失败会把错误抛给所有等待者。
 - 该管理器不直接发起网络请求，刷新逻辑由你通过 `setRefresher` 注入。
 */
public actor LWTokenStore {

    public static let shared = LWTokenStore()

    // MARK: - Model

    public struct Token: Codable, Sendable {
        public var access: String
        public var refresh: String
        public var expiry: Date

        public init(access: String, refresh: String, expiry: Date) {
            self.access = access
            self.refresh = refresh
            self.expiry = expiry
        }
    }

    // MARK: - State

    private var refresher: (@Sendable (String) async throws -> Token)? = nil
    private var token: Token? = nil
    private var refreshTask: Task<String, Error>? = nil

    /// 默认过期余量（提前多少秒认为 token 已过期需要刷新）
    public var defaultLeeway: TimeInterval = 30

    // MARK: - Configuration

    /// 配置刷新闭包（使用 refresh token 获取新的 Token）
    public func setRefresher(_ f: @escaping @Sendable (String) async throws -> Token) {
        self.refresher = f
    }

    /// 注入首个 Token，并写入 Keychain
    public func bootstrap(_ token: Token) async {
        self.token = token
        await LWNetKeychain.shared.saveToken(token)
    }

    /// 从 Keychain 恢复 Token（若不存在则不做处理）
    @discardableResult
    public func loadFromKeychain() async -> Bool {
        if let t = await LWNetKeychain.shared.loadToken() {
            self.token = t
            return true
        }
        return false
    }

    /// 手动更新 Token（写入 Keychain）
    public func update(_ new: Token) async {
        self.token = new
        await LWNetKeychain.shared.saveToken(new)
    }

    /// 登出：清空内存 Token 并删除 Keychain 中的 Token
    public func logout() async {
        self.token = nil
        await LWNetKeychain.shared.removeToken()
        // 取消可能在途的刷新
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Query

    /// 获取一个**有效**的 Access Token（如临近过期则自动刷新）
    public func validAccessToken(leeway: TimeInterval? = nil) async throws -> String {
        let margin = leeway ?? defaultLeeway
        if let t = token, isValid(t, leeway: margin) {
            return t.access
        }
        return try await refreshAccessToken()
    }

    /// 当前 Token（只读，调试用）
    public func current() -> Token? { token }

    /// 距离过期的秒数（负数表示已过期）
    public func secondsUntilExpiry() -> TimeInterval? {
        guard let e = token?.expiry else { return nil }
        return e.timeIntervalSinceNow
    }

    /// 是否认为当前处于“已认证”状态
    public var isAuthenticated: Bool {
        if let t = token { return isValid(t, leeway: defaultLeeway) }
        return false
    }

    // MARK: - Refresh

    /// 强制刷新（忽略进行中的刷新任务并重新发起）
    public func forceRefresh() async throws -> String {
        refreshTask?.cancel()
        refreshTask = nil
        return try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws -> String {
        if let t = refreshTask {
            return try await t.value
        }

        let task = Task<String, Error> {
            defer { refreshTask = nil }
            guard let rt = token?.refresh else {
                throw LWNetworkError(kind: .unauthorized)
            }
            guard let refresher = refresher else {
                throw LWNetworkError(kind: .unauthorized)
            }
            let new = try await refresher(rt)
            await self.update(new)
            return new.access
        }
        refreshTask = task
        return try await task.value
    }

    // MARK: - Helpers

    private func isValid(_ token: Token, leeway: TimeInterval) -> Bool {
        token.expiry > Date().addingTimeInterval(leeway)
    }
}
