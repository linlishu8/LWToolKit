import Foundation
import Alamofire
import OSLog

/**
 LWAlamofireClient
 ----------------
 作用：
 一个基于 **Alamofire** 的轻量网络客户端实现，遵循 `LWNetworking` 协议。
 - 统一构建 `URLRequest`（支持 query/json/body 等常见任务类型）
 - 中间件链（`middlewares`）的请求预处理与响应回调（如鉴权、ETag、重试、打点）
 - 可选 ETag 缓存（配置 `useETagCaching` 时挂接 `URLCache` + `LWETagMiddleware`）
 - 请求合并（`LWRequestCoalescer`）：相同请求仅发一次，复用结果
 - 便捷的 `request<T: Decodable>` / `requestVoid` / `download` 方法

 使用示例：
 ```swift
 // 1) 定义网络配置
 var config = LWNetworkConfig(
     timeout: 15,
     requestHeaders: ["User-Agent": "LWApp/1.0"],
     useETagCaching: true,
     middlewares: [/* 你的中间件，如鉴权、重试、日志 */]
 )

 // 2) 创建客户端（可传入 AF 的拦截器与事件监控）
 let client = LWAlamofireClient(config: config, interceptor: nil, monitors: [])

 // 3) 发起请求（Decodable）
 struct User: Decodable { let id: String; let name: String }
 let ep = LWEndpoint(
     baseURL: URL(string: "https://api.example.com")!,
     path: "/v1/me",
     method: .get,
     task: .requestParameters(["expand": "profile"], URLEncoding.default),
     cachePolicy: .useProtocolCachePolicy
 )
 let user: User = try await client.request(ep, as: User.self)

 // 4) 下载
 let fileURL = try await client.download(ep)

 // 5) 无返回体
 try await client.requestVoid(ep)
 ```

 注意事项：
 - 该实现依赖于你的工程内定义的类型：`LWNetworking`, `LWNetworkConfig`, `LWEndpoint`,
   `LWNetworkError`, `LWAnyEncodable`, `LWRequestCoalescer`, `LWRequestKey` 与可选的 `LWETagMiddleware`、`LWAFLogger`。
 - `uploadMultipart` 的分支在此版本中未展开（`buildRequest` 会原样返回），如需支持请扩展为使用
   `session.upload(multipartFormData:...)` 的专用方法。
 - `request<T>` 使用 `JSONDecoder()` 解码，可按需在外部配置/注入策略（日期/键风格等）。
 */
public final class LWAlamofireClient: LWNetworking, @unchecked Sendable {

    // MARK: - Internal State

    private let session: Session
    private var config: LWNetworkConfig
    private let decoder = JSONDecoder()
    private let coalescer = LWRequestCoalescer()

    // MARK: - Init

    public init(config: LWNetworkConfig,
                interceptor: RequestInterceptor? = nil,
                monitors: [EventMonitor] = []) {
        self.config = config

        // URLSession 基础配置
        let conf = URLSessionConfiguration.default
        conf.timeoutIntervalForRequest = config.timeout
        conf.requestCachePolicy = .useProtocolCachePolicy
        conf.httpAdditionalHeaders = HTTPHeaders.default.dictionary.merging(config.requestHeaders.dictionary) { $1 }

        // 可选：ETag 缓存（挂接 URLCache）
        if config.useETagCaching {
            conf.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024,
                                     diskCapacity: 100 * 1024 * 1024,
                                     diskPath: "lw.urlcache")
        }

        // 事件监控（追加自定义 AF 日志器）
        var monitorsAll = monitors
        monitorsAll.append(LWAFLogger())

        self.session = Session(configuration: conf, interceptor: interceptor, eventMonitors: monitorsAll)

        // 可选：在中间件链前插入 ETag 中间件
        if config.useETagCaching {
            self.config.middlewares.insert(LWETagMiddleware(), at: 0)
        }
    }

    // MARK: - Public API

    public func request<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T {
        let data = try await perform(ep)
        return try decoder.decode(T.self, from: data)
    }

    public func requestVoid(_ ep: LWEndpoint) async throws {
        _ = try await perform(ep)
    }

    public func upload<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T {
        // 目前直接走与 request 相同的逻辑；如需 multipart 请自行扩展
        return try await request(ep, as: T.self)
    }

    public func download(_ ep: LWEndpoint) async throws -> URL {
        let req = try buildRequest(from: ep)
        return try await session.download(req).serializingDownloadedFileURL().value
    }

    // MARK: - Core

    private func perform(_ ep: LWEndpoint) async throws -> Data {
        let req = try buildRequest(from: ep)

        // willSend 钩子
        for m in self.config.middlewares { m.willSend(req) }

        let middlewares = self.config.middlewares
        let session = self.session

        return try await coalescer.run(for: LWRequestKey(req)) {
            let resp = await session.request(req).serializingData().response
            switch resp.result {
            case .success(let data):
                if let http = resp.response {
                    for m in middlewares { m.didReceive(.success((http, data)), for: req) }
                    try Self.throwIfServerError(http, data: data)
                }
                return data

            case .failure(let afError):
                let err = LWNetworkError(
                    kind: .network,
                    statusCode: resp.response?.statusCode,
                    data: resp.data,
                    underlying: afError
                )
                for m in middlewares { m.didReceive(.failure(err), for: req) }
                throw err
            }
        }
    }

    private func buildRequest(from ep: LWEndpoint) throws -> URLRequest {
        let url = ep.baseURL.appendingPathComponent(ep.path)
        var req = URLRequest(url: url)
        req.httpMethod = ep.method.rawValue
        req.cachePolicy = ep.cachePolicy

        // 中间件预处理（如公共头、鉴权等）
        req = self.config.middlewares.reduce(req) { $1.prepare($0) }

        // 根据任务类型编码
        switch ep.task {
        case .requestPlain:
            return try URLEncoding.default.encode(req, with: nil)

        case .requestParameters(let params, let encoding):
            return try encoding.encode(req, with: params)

        case .requestJSONEncodable(let encodable):
            req.httpBody = try JSONEncoder().encode(LWAnyEncodable(encodable))
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            return req

        case .uploadMultipart, .download:
            // 占位：如需支持 multipart，请在此返回合适的 URLRequest 或改用专用 upload 方法
            return req
        }
    }

    private static func throwIfServerError(_ http: HTTPURLResponse, data: Data) throws {
        switch http.statusCode {
        case 200..<300, 304:
            return
        case 401:
            throw LWNetworkError(kind: .unauthorized, statusCode: http.statusCode, data: data)
        case 403:
            throw LWNetworkError(kind: .forbidden, statusCode: http.statusCode, data: data)
        case 404:
            throw LWNetworkError(kind: .notFound, statusCode: http.statusCode, data: data)
        case 408:
            throw LWNetworkError(kind: .timeout, statusCode: http.statusCode, data: data)
        case 429:
            throw LWNetworkError(kind: .rateLimited, statusCode: http.statusCode, data: data)
        case 500..<600:
            throw LWNetworkError(kind: .server, statusCode: http.statusCode, data: data)
        default:
            throw LWNetworkError(kind: .unknown, statusCode: http.statusCode, data: data)
        }
    }
}
