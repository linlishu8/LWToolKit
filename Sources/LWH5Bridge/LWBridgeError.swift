/*
  作用：统一桥接错误模型；提供标准错误码、消息与可选详情。
  使用示例：
    completion(.failure(.forbidden(details: ["method": .init("info")])))
  特点/注意事项：
    - 错误会以 JSON 形式返回给 H5（code/message/details）。
*/
import Foundation

public enum LWBridgeError: Error {
    case badRequest(message: String)
    case notFound(module: String, method: String)
    case forbidden(details: [String: LWAnyCodable]?)
    case internalError(message: String)
    case timeout
    case oversizedPayload(size: Int)

    public var code: Int {
        switch self {
        case .badRequest: return 400
        case .forbidden: return 403
        case .notFound: return 404
        case .timeout: return 408
        case .oversizedPayload: return 413
        case .internalError: return 500
        }
    }

    public var message: String {
        switch self {
        case .badRequest(let m): return m
        case .forbidden: return "forbidden"
        case .notFound: return "not_found"
        case .timeout: return "timeout"
        case .oversizedPayload: return "payload_too_large"
        case .internalError(let m): return m
        }
    }

    public var details: [String: LWAnyCodable]? {
        switch self {
        case .notFound(let module, let method):
            return ["module": .init(module), "method": .init(method)]
        case .oversizedPayload(let size):
            return ["size": .init(size)]
        case .forbidden(let d): return d
        default: return nil
        }
    }
}

public struct LWBridgeErrorPayload: Codable {
    public let code: Int
    public let message: String
    public let details: [String: LWAnyCodable]?

    public init(error: LWBridgeError) {
        self.code = error.code
        self.message = error.message
        self.details = error.details
    }
}
