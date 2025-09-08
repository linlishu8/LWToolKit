import Foundation
public struct LWErrorMapper {
    public struct APIError: Decodable { public let code: Int; public let message: String }
    public static func map(code: Int, data: Data?) -> LWError {
        guard let data = data else { return .network(code: code, message: "No body") }
        if let api = try? JSONDecoder().decode(APIError.self, from: data) {
            return .business(code: api.code, message: api.message)
        }
        let text = String(data: data, encoding: .utf8) ?? "(\(data.count) bytes)"
        return .network(code: code, message: text)
    }
}
