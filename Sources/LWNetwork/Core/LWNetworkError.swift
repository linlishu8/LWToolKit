import Foundation
public struct LWNetworkError: Error {
  public let kind: Kind; public let statusCode: Int?; public let data: Data?; public let underlying: Error?
  public init(kind: Kind, statusCode: Int? = nil, data: Data? = nil, underlying: Error? = nil) { self.kind = kind; self.statusCode = statusCode; self.data = data; self.underlying = underlying }
  public enum Kind { case network, timeout, cancelled, server, decoding, unauthorized, forbidden, notFound, rateLimited, invalidRequest, blocked, unknown }
  public var isRetryable: Bool { kind == .network || kind == .timeout || kind == .rateLimited }
}
