import Foundation

/// 通用响应包裹：用于承载 `{ "code": Int, "message": String, "data": T }`
/// - Note: 字段允许为可选，兼容既返回包裹又直接返回 `T` 的接口。
public struct Envelope<T: Decodable>: Decodable {
    public let code: Int?
    public let message: String?
    public let data: T?
}
