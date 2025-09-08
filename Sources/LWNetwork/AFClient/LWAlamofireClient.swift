import Foundation
import Alamofire
import OSLog
public final class LWAlamofireClient: LWNetworking, @unchecked Sendable {
  private let session: Session; private var config: LWNetworkConfig; private let decoder = JSONDecoder(); private let coalescer = LWRequestCoalescer()
  public init(config: LWNetworkConfig, interceptor: RequestInterceptor? = nil, monitors: [EventMonitor] = []) {
    self.config = config
    let conf = URLSessionConfiguration.default; conf.timeoutIntervalForRequest = config.timeout; conf.requestCachePolicy = .useProtocolCachePolicy; conf.httpAdditionalHeaders = HTTPHeaders.default.dictionary.merging(config.requestHeaders.dictionary){ $1 }
    if config.useETagCaching { conf.urlCache = URLCache(memoryCapacity: 20*1024*1024, diskCapacity: 100*1024*1024, diskPath: "lw.urlcache") }
    var monitorsAll = monitors; monitorsAll.append(LWAFLogger())
    self.session = Session(configuration: conf, interceptor: interceptor, eventMonitors: monitorsAll)
    if config.useETagCaching { self.config.middlewares.insert(LWETagMiddleware(), at: 0) }
  }
  public func request<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T { let d = try await perform(ep); return try decoder.decode(T.self, from: d) }
  public func requestVoid(_ ep: LWEndpoint) async throws { _ = try await perform(ep) }
  public func upload<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T { try await request(ep, as: T.self) }
  public func download(_ ep: LWEndpoint) async throws -> URL { let req = try buildRequest(from: ep); return try await session.download(req).serializingDownloadedFileURL().value }
  private func perform(_ ep: LWEndpoint) async throws -> Data {
    let req = try buildRequest(from: ep); for m in self.config.middlewares { m.willSend(req) }
    let middlewares = self.config.middlewares; let session = self.session
    return try await coalescer.run(for: LWRequestKey(req)) {
      let resp = await session.request(req).serializingData().response
      switch resp.result { case .success(let d):
        if let http = resp.response { for m in middlewares { m.didReceive(.success((http,d)), for: req) }; try Self.throwIfServerError(http, data: d) }
        return d
      case .failure(let e):
        let y = LWNetworkError(kind: .network, statusCode: resp.response?.statusCode, data: resp.data, underlying: e)
        for m in middlewares { m.didReceive(.failure(y), for: req) }; throw y
      }
    }
  }
  private func buildRequest(from ep: LWEndpoint) throws -> URLRequest {
    let url = ep.baseURL.appendingPathComponent(ep.path); var req = URLRequest(url: url); req.httpMethod = ep.method.rawValue; req.cachePolicy = ep.cachePolicy; req = self.config.middlewares.reduce(req){ $1.prepare($0) }
    switch ep.task {
      case .requestPlain: return try URLEncoding.default.encode(req, with: nil)
      case .requestParameters(let p, let enc): return try enc.encode(req, with: p)
      case .requestJSONEncodable(let e): req.httpBody = try JSONEncoder().encode(LWAnyEncodable(e)); req.setValue("application/json", forHTTPHeaderField: "Content-Type"); return req
      case .uploadMultipart, .download: return req
    }
  }
  private static func throwIfServerError(_ http: HTTPURLResponse, data: Data) throws {
    switch http.statusCode {
      case 200..<300, 304: return
      case 401: throw LWNetworkError(kind: .unauthorized, statusCode: http.statusCode, data: data)
      case 403: throw LWNetworkError(kind: .forbidden, statusCode: http.statusCode, data: data)
      case 404: throw LWNetworkError(kind: .notFound, statusCode: http.statusCode, data: data)
      case 408: throw LWNetworkError(kind: .timeout, statusCode: http.statusCode, data: data)
      case 429: throw LWNetworkError(kind: .rateLimited, statusCode: http.statusCode, data: data)
      case 500..<600: throw LWNetworkError(kind: .server, statusCode: http.statusCode, data: data)
      default: throw LWNetworkError(kind: .unknown, statusCode: http.statusCode, data: data)
    }
  }
}
