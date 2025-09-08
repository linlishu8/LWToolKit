import Foundation
public actor LWTokenStore { public static let shared = LWTokenStore()
  public struct Token: Codable, Sendable { public var access:String; public var refresh:String; public var expiry:Date; public init(access:String, refresh:String, expiry:Date){ self.access=access; self.refresh=refresh; self.expiry=expiry } }
  private var refresher: (@Sendable (String) async throws -> Token)? = nil
  private var token: Token? = nil; private var refreshTask: Task<String, Error>? = nil
  public func setRefresher(_ f: @escaping @Sendable (String) async throws -> Token) { self.refresher = f }
  public func bootstrap(_ token: Token) async { self.token = token; await LWKeychain.shared.saveToken(token) }
  public func validAccessToken() async throws -> String { if let t=token, t.expiry > Date().addingTimeInterval(30) { return t.access } ; return try await refreshAccessToken() }
  public func update(_ new: Token) async { self.token = new; await LWKeychain.shared.saveToken(new) }
  private func refreshAccessToken() async throws -> String { if let t = refreshTask { return try await t.value } ; let task = Task { () throws -> String in defer { refreshTask = nil } ; guard let rt = token?.refresh else { throw LWNetworkError(kind:.unauthorized) } ; guard let refresher = refresher else { throw LWNetworkError(kind: .unauthorized) } ; let new = try await refresher(rt) ; await self.update(new) ; return new.access } ; refreshTask = task ; return try await task.value }
}
