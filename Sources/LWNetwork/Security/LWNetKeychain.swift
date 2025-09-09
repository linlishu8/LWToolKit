import Foundation
import Security

/**
 LWNetKeychain
 -------------
 作用：
 一个**面向网络 Token** 的 Keychain 极简封装，负责把 `LWTokenStore.Token` JSON 化后安全存储到系统钥匙串，
 并提供读取/删除接口。默认放在 `kSecClassGenericPassword` 下，`service = "com.example.lw.tokens"`，`account = "auth"`。

 使用示例：
 ```swift
 // 保存（例如在登录或刷新 token 后）
 let token = LWTokenStore.Token(accessToken: "abc", refreshToken: "def", expiresAt: Date())
 await LWNetKeychain.shared.saveToken(token)

 // 读取（发起请求前）
 if let t = await LWNetKeychain.shared.loadToken() {
     print("token:", t.accessToken)
 }

 // 删除（登出时）
 await LWNetKeychain.shared.removeToken()
 ```

 注意事项：
 - 使用 **AfterFirstUnlockThisDeviceOnly** 可见性，避免备份同步到其他设备；若需 iCloud Keychain，
   请根据业务调整 `kSecAttrAccessible` 与 `kSecAttrSynchronizable`。
 - 该实现是 “best-effort”：失败会静默忽略并返回 nil；若需要精确错误，请改用抛错版本。
 */
public final class LWNetKeychain {

    public static let shared = LWNetKeychain()
    private init() {}

    // MARK: - Constants

    private let service = "com.example.lw.tokens"
    private let account = "auth"

    // MARK: - Public API (async for symmetry with callers)

    /// 保存 Token（覆盖同键值）
    public func saveToken(_ token: LWTokenStore.Token) async {
        guard let data = try? JSONEncoder().encode(token) else { return }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        // 先删除旧项（忽略结果）
        SecItemDelete(base as CFDictionary)

        var add = base
        add[kSecValueData as String] = data
        // 仅本机可用，首解锁后可访问；如需更细粒度，请按需修改
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        _ = SecItemAdd(add as CFDictionary, nil)
    }

    /// 读取 Token（无则返回 nil）
    public func loadToken() async -> LWTokenStore.Token? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var out: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else { return nil }
        return try? JSONDecoder().decode(LWTokenStore.Token.self, from: data)
    }

    /// 删除 Token（无论是否存在都视为成功）
    public func removeToken() async {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
