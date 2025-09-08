import Foundation
public actor LWRequestCoalescer { private var tasks:[LWRequestKey:Task<Data,Error>] = [:]
  public init() {}
  public func run(for key: LWRequestKey, _ block: @escaping @Sendable () async throws -> Data) async throws -> Data {
    if let t = tasks[key] { return try await t.value }
    let t = Task { try await block() }; tasks[key] = t
    do { let v = try await t.value; tasks[key] = nil; return v } catch { tasks[key] = nil; throw error }
  } }
public struct LWRequestKey: Hashable { public let method:String; public let url:String; public let bodyHash:Int
  public init(_ r: URLRequest){ method=r.httpMethod ?? "GET"; url=r.url?.absoluteString ?? ""; bodyHash=r.httpBody?.hashValue ?? 0 } }
