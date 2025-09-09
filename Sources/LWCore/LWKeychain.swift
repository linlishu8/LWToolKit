import Foundation
import Security

/**
 LWKeychain
 ----------------
 作用：
 一个**轻量的 Keychain 封装**，用 (service, account) 二元键读写 `Data`，
 并提供 `String` / `Codable` 的便捷方法；支持按需指定 `accessGroup` 和 `accessible`
（默认 `kSecAttrAccessibleAfterFirstUnlock`），用于满足前后台持久读取的常见场景。

 使用示例：
 ```swift
 // 1) 写入/读取字符串
 _ = LWKeychain.set("token_abc", service: "auth", account: "access_token")
 let token = LWKeychain.getString(service: "auth", account: "access_token")

 // 2) 写入/读取任意 Data
 let bytes = Data([0x01, 0x02, 0x03])
 _ = LWKeychain.set(bytes, service: "cache", account: "blob")

 // 3) 写入/读取 Codable（JSON 编解码）
 struct Profile: Codable { let id: String; let name: String }
 let p = Profile(id: "u_1", name: "Andy")
 _ = LWKeychain.setCodable(p, service: "user", account: "profile")
 let p2: Profile? = LWKeychain.getCodable(service: "user", account: "profile")

 // 4) 删除
 _ = LWKeychain.remove(service: "auth", account: "access_token")
 ```

 注意事项：
 - 若使用 `accessGroup`，需在工程的 Keychain Sharing 中配置相同的访问组（Entitlements）。
 - iOS 端默认 `accessible = kSecAttrAccessibleAfterFirstUnlock`，可在仅前台读取的场景切换为
   `kSecAttrAccessibleWhenUnlocked`；如需仅本机可恢复可用 `...ThisDeviceOnly` 变体。
 - Keychain API 返回 OSStatus；本封装返回 Bool 以简化使用，如需详细错误可自行扩展。
 */
public enum LWKeychain {

    // MARK: - Core (Data)

    /// Save data for (service, account). Overwrites existing value.
    @discardableResult
    public static func set(_ data: Data,
                           service: String,
                           account: String,
                           accessGroup: String? = nil,
                           accessible: CFString = kSecAttrAccessibleAfterFirstUnlock) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        // Try update first; if not found then add
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
        ]
        let statusUpdate = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if statusUpdate == errSecSuccess { return true }
        if statusUpdate == errSecItemNotFound {
            var add = query
            add.merge(attrs) { $1 }
            let statusAdd = SecItemAdd(add as CFDictionary, nil)
            return statusAdd == errSecSuccess
        }
        return false
    }

    /// Read data for (service, account).
    public static func get(service: String,
                           account: String,
                           accessGroup: String? = nil) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    /// Delete item for (service, account). Returns true if deleted or not found.
    @discardableResult
    public static func remove(service: String,
                              account: String,
                              accessGroup: String? = nil) -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let group = accessGroup { query[kSecAttrAccessGroup as String] = group }

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Convenience: String

    @discardableResult
    public static func set(_ string: String,
                           service: String,
                           account: String,
                           accessGroup: String? = nil,
                           accessible: CFString = kSecAttrAccessibleAfterFirstUnlock) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return set(data, service: service, account: account, accessGroup: accessGroup, accessible: accessible)
    }

    public static func getString(service: String,
                                 account: String,
                                 accessGroup: String? = nil) -> String? {
        guard let data = get(service: service, account: account, accessGroup: accessGroup) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Convenience: Codable

    @discardableResult
    public static func setCodable<T: Codable>(_ value: T,
                                              service: String,
                                              account: String,
                                              accessGroup: String? = nil,
                                              accessible: CFString = kSecAttrAccessibleAfterFirstUnlock,
                                              encoder: JSONEncoder = JSONEncoder()) -> Bool {
        guard let data = try? encoder.encode(value) else { return false }
        return set(data, service: service, account: account, accessGroup: accessGroup, accessible: accessible)
    }

    public static func getCodable<T: Codable>(service: String,
                                              account: String,
                                              accessGroup: String? = nil,
                                              decoder: JSONDecoder = JSONDecoder()) -> T? {
        guard let data = get(service: service, account: account, accessGroup: accessGroup) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }
}
