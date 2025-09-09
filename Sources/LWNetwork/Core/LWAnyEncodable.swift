import Foundation

/**
 LWAnyEncodable
 ----------------
 作用：
 一个**类型擦除的 Encodable 包装器**。当你需要把不同具体类型（都遵循 `Encodable`）
 放进同一个集合（如 `[String: ...]` 或 `[... ]`）并统一用 `JSONEncoder` 编码时，
 使用 `LWAnyEncodable` 可以避免编译器的类型限制。

 使用示例：
 ```swift
 struct User: Encodable { let id: Int; let name: String }
 let payload: [String: LWAnyEncodable] = [
     "user": LWAnyEncodable(User(id: 1, name: "Andy")),
     "flag": LWAnyEncodable(true),
     "ts"  : LWAnyEncodable(Date().timeIntervalSince1970)
 ]

 let data = try JSONEncoder().encode(payload)
 // 现在可将 data 作为 JSON 请求体发送
 ```

 注意事项：
 - `LWAnyEncodable` 仅做**编码**的类型擦除；若需要“解码”的类型擦除，请另行定义 `AnyDecodable`。
 - 如果你的集合元素本身就是同一具体类型（例如 `[User]`），不需要使用 `LWAnyEncodable`。
 */

public struct LWAnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    public init<T: Encodable>(_ value: T) {
        self._encode = value.encode
    }

    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

// MARK: - Helpers

public extension Array where Element: Encodable {
    /// 将任意可编码数组映射为 `[LWAnyEncodable]`
    func asAnyEncodables() -> [LWAnyEncodable] {
        map(LWAnyEncodable.init)
    }
}

public extension Dictionary where Value: Encodable {
    /// 将字典的值映射为 `LWAnyEncodable`，便于统一 JSON 编码
    func asAnyEncodables() -> [Key: LWAnyEncodable] {
        mapValues(LWAnyEncodable.init)
    }
}
