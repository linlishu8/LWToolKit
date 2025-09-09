import Foundation

/**
 LWErrorMapper
 ----------------
 作用：
 将网络层返回的 `(HTTP code, data)` 统一映射为项目内的 `LWError`：
 - 若返回体可解析为通用的 `{code,message}`（兼容多种后端键名），映射为 `.business`；
 - 否则回落为 `.network`，并尝试以 UTF-8 字符串显示原始文本，便于排查。

 使用示例：
 ```swift
 // 假设你拿到了 response/statusCode 与 data
 let httpCode = response.statusCode
 let error = LWErrorMapper.map(code: httpCode, data: data)

 // 统一处理
 switch error {
 case let .business(code, message):
     // 展示后端业务错误文案
     showToast(message)
 case let .network(code, message):
     // 统一网络错误提示或重试
     showToast("网络异常 (\(code))：\(message)")
 }
 ```

 注意事项：
 - `APIError` 解析对键名做了兼容（如：code/errorCode/status/errcode；message/msg/error/errorMessage/detail）。
 - 若后端把 `code` 写成字符串（如 `"404"`），会尝试自动转为 Int。
 - 若返回体不是 JSON 或结构不匹配，会视作 `.network` 并带上原始文本片段。
 */
public struct LWErrorMapper {

    // MARK: - API Error Model (tolerant decoding)

    public struct APIError: Decodable {
        public let code: Int
        public let message: String

        public init(code: Int, message: String) {
            self.code = code
            self.message = message
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: DynamicCodingKeys.self)
            self.code = try Self.decodeInt(from: c, keys: ["code", "errorCode", "status", "errcode"])
            self.message = (Self.decodeString(from: c, keys: ["message", "msg", "error", "errorMessage", "detail", "description"]) ?? "")
        }

        private static func decodeInt(from c: KeyedDecodingContainer<DynamicCodingKeys>, keys: [String]) throws -> Int {
            for k in keys {
                let key = DynamicCodingKeys(stringValue: k)!
                if let v = try? c.decode(Int.self, forKey: key) { return v }
                if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
            }
            throw DecodingError.keyNotFound(DynamicCodingKeys(stringValue: keys.first!)!, .init(codingPath: c.codingPath, debugDescription: "No int found in keys \(keys)"))
        }

        private static func decodeString(from c: KeyedDecodingContainer<DynamicCodingKeys>, keys: [String]) -> String? {
            for k in keys {
                let key = DynamicCodingKeys(stringValue: k)!
                if let v = try? c.decode(String.self, forKey: key) { return v }
            }
            return nil
        }
    }

    // MARK: - Mapping

    /// 依据 HTTP 状态码与响应体映射为 LWError
    /// - Parameters:
    ///   - code: HTTP 状态码（或你自定义的网络错误码）
    ///   - data: 响应体（可为 nil）
    ///   - decoder: 可自定义 JSONDecoder（时区、日期策略等）
    public static func map(code: Int, data: Data?, decoder: JSONDecoder = JSONDecoder()) -> LWError {
        guard let data = data else {
            return .network(code: code, message: "No body")
        }
        if let api = try? decoder.decode(APIError.self, from: data) {
            // message 可能为空，兜底一条通用提示
            let msg = api.message.isEmpty ? "Unknown error" : api.message
            return .business(code: api.code, message: msg)
        }
        let text = String(data: data, encoding: .utf8) ?? "(\(data.count) bytes)"
        return .network(code: code, message: text)
    }

    /// 便捷重载：直接传 HTTPURLResponse
    public static func map(_ response: HTTPURLResponse?, data: Data?, decoder: JSONDecoder = JSONDecoder()) -> LWError {
        let code = response?.statusCode ?? -1
        return map(code: code, data: data, decoder: decoder)
    }

    // MARK: - Helpers

    /// 动态键，用于兼容多种后端字段名
    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int?
        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
