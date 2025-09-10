/*
  作用：提供 AnyCodable/AnyEncodable/AnyDecodable，支持将任意 JSON 值在 Swift 中安全编码/解码。
  使用示例：
    let dict: [String: AnyCodable] = ["a": 1, "b": "str", "c": true]
    let data = try JSONEncoder().encode(dict)
    let obj = try JSONDecoder().decode([String: AnyCodable].self, from: data)
  特点/注意事项：
    - 仅针对 JSON 支持的类型（字典、数组、字符串、数值、布尔、null）。
    - 为保证 iOS13 兼容，未使用并发/actors 等新特性。
*/
import Foundation

public struct LWAnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) { self.value = value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self.value = NSNull() }
        else if let bool = try? container.decode(Bool.self) { self.value = bool }
        else if let int = try? container.decode(Int.self) { self.value = int }
        else if let double = try? container.decode(Double.self) { self.value = double }
        else if let string = try? container.decode(String.self) { self.value = string }
        else if let array = try? container.decode([LWAnyCodable].self) { self.value = array.map { $0.value } }
        else if let dict = try? container.decode([String: LWAnyCodable].self) {
            var result: [String: Any] = [:]
            for (k, v) in dict { result[k] = v.value }
            self.value = result
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON type")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull: try container.encodeNil()
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [Any]:
            try container.encode(v.map { LWAnyCodable($0) })
        case let v as [String: Any]:
            let enc = Dictionary(uniqueKeysWithValues: v.map { ($0, LWAnyCodable($1)) })
            try container.encode(enc)
        default:
            let ctx = EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported JSON type")
            throw EncodingError.invalidValue(value, ctx)
        }
    }
}

public typealias AnyEncodable = LWAnyCodable
public typealias AnyDecodable = LWAnyCodable
