import Foundation
struct LWAnyEncodable: Encodable { private let _encode: (Encoder) throws -> Void; init(_ v: Encodable) { _encode = v.encode }; func encode(to e: Encoder) throws { try _encode(e) } }
