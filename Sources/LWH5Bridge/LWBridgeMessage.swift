/*
  作用：统一请求/响应模型，定义 JSON-RPC 风格的消息体。
  使用示例：
    let req = BridgeRequest(id: "1", module: "user", method: "info", params: [:])
  特点/注意事项：
    - params/result 使用 AnyCodable，以兼容任意 JSON。
*/
import Foundation

public struct LWBridgeRequest: Codable {
    public let id: String
    public let module: String
    public let method: String
    public let params: [String: LWAnyCodable]?

    public init(id: String, module: String, method: String, params: [String: LWAnyCodable]?) {
        self.id = id
        self.module = module
        self.method = method
        self.params = params
    }
}

public struct LWBridgeResponse: Codable {
    public let id: String
    public let result: LWAnyCodable?
    public let error: LWBridgeErrorPayload?

    public init(id: String, result: LWAnyCodable?, error: LWBridgeErrorPayload?) {
        self.id = id
        self.result = result
        self.error = error
    }
}
