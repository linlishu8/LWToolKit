/* 
  作用：Token 模型与存储（示例用 UserDefaults；建议换 Keychain）。
*/
import Foundation

public struct AuthToken: Codable, Equatable {
    public let accessToken: String; public let refreshToken: String; public let expiresAt: Date
}
public actor TokenStore {
    public static let shared = TokenStore()
    private let key = "AppNetworkEZ.AuthToken"
    private var token: AuthToken?
    public func current() async -> AuthToken? {
        if token == nil, let data = UserDefaults.standard.data(forKey: key),
           let t = try? JSONDecoder().decode(AuthToken.self, from: data) { token = t }
        return token
    }
    public func save(_ t: AuthToken?) async throws {
        token = t
        if let t = t, let data = try? JSONEncoder().encode(t) {
            UserDefaults.standard.set(data, forKey: key)
        } else { UserDefaults.standard.removeObject(forKey: key) }
    }
}
