import Foundation
import Alamofire
public enum LWEnvironment { case dev, test, prod; public var baseURL: URL { URL(string: "https://demo.local")! } }
public struct LWAPI: LWEndpoint { public var baseURL: URL; public var path: String; public var method: HTTPMethod; public var task: LWTask; public var headers: HTTPHeaders; public var cachePolicy: URLRequest.CachePolicy; public var requiresAuth: Bool
  public init(env: LWEnvironment, path: String, method: HTTPMethod = .get, task: LWTask = .requestPlain, headers: HTTPHeaders = [:], cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, requiresAuth: Bool = true) { self.baseURL = env.baseURL; self.path = path; self.method = method; self.task = task; self.headers = headers; self.cachePolicy = cachePolicy; self.requiresAuth = requiresAuth; if requiresAuth { self.headers.add(name: "__Requires-Auth__", value: "1") } } }
