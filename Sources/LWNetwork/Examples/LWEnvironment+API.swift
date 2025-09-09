import Foundation
import Alamofire

/**
 LWEnvironment & LWAPI
 --------------------
 作用：
 定义一个**简单可组合的端点描述**（`LWAPI`），用于快速构造遵循 `LWEndpoint` 的请求；
 并提供一个环境枚举 `LWEnvironment` 来选择基础域名（demo 默认均指向 `https://demo.local`，
 便于在本地 Mock/代理调试）。

 特点：
 - 轻量：仅填 `path / method / task` 即可。
 - 灵活：可直接覆盖 `baseURL`，或用 `env` 统一切环境。
 - 兼容：字段与 `LWEndpoint` 对齐，可直接用于 `LWAlamofireClient`。
 - 约定：当 `requiresAuth == true` 时，会自动在头里加入 `__Requires-Auth__: 1` 标记，
   方便你的鉴权中间件识别（可在中间件里读取并附加 token）。

 使用示例：
 ```swift
 // 1) GET /v1/me?expand=profile
 let me = LWAPI.get(
     env: .dev, path: "/v1/me",
     params: ["expand": "profile"]
 )

 // 2) POST JSON /v1/posts
 struct CreatePost: Encodable { let title: String; let body: String }
 let create = LWAPI.postJSON(
     env: .dev, path: "/v1/posts",
     body: CreatePost(title: "Hello", body: "World")
 )

 // 3) Multipart 上传
 let parts: [LWMultipartFormData] = [
     .text(name: "title", "Hello"),
     LWMultipartFormData(name: "image", data: pngData, fileName: "a.png", mimeType: "image/png")
 ]
 let upload = LWAPI.uploadMultipart(env: .dev, path: "/v1/upload", parts: parts)

 // 4) 下载
 let dl = LWAPI.download(env: .dev, path: "/files/a.pdf")

 // 5) 覆盖 baseURL（无需使用 env）
 let absolute = LWAPI(baseURL: URL(string: "https://api.example.com")!,
                      path: "/v1/me", method: .get)
 ```

 注意事项：
 - `LWEnvironment.baseURL` 默认返回 `https://demo.local`。若你使用本地服务/Charles，请保持该域名或相应修改。
 - 若你的项目不需要 `__Requires-Auth__` 约定，可在构造时传 `requiresAuth: false`，或在中间件里忽略该头。
 - 与 `LWTask` 结合使用：`.requestParameters` 支持任意 `ParameterEncoding`（如 `URLEncoding/JSONEncoding`）。
 */

// MARK: - Environment

public enum LWEnvironment {
    case dev, test, prod

    /// 默认全部指向 demo.local；如需区分不同环境，可改成 dev.demo.local / test.demo.local / prod.demo.local
    public var baseURL: URL {
        URL(string: "https://demo.local")!
    }
}

// MARK: - LWAPI

public struct LWAPI: LWEndpoint {
    public var baseURL: URL
    public var path: String
    public var method: HTTPMethod
    public var task: LWTask
    public var headers: HTTPHeaders
    public var cachePolicy: URLRequest.CachePolicy
    public var requiresAuth: Bool

    /// 主要构造器（可传 env 或直接覆盖 baseURL）
    public init(env: LWEnvironment = .dev,
                baseURL: URL? = nil,
                path: String,
                method: HTTPMethod = .get,
                task: LWTask = .requestPlain,
                headers: HTTPHeaders = [:],
                cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                requiresAuth: Bool = true) {
        self.baseURL = baseURL ?? env.baseURL
        self.path = path
        self.method = method
        self.task = task
        self.cachePolicy = cachePolicy
        self.requiresAuth = requiresAuth

        // 若需要鉴权，则在头部放置一个标记，供中间件识别并附加真实的 Authorization
        var h = headers
        if requiresAuth {
            h.add(name: "__Requires-Auth__", value: "1")
        }
        self.headers = h
    }
}

// MARK: - Conveniences

public extension LWAPI {
    /// 便捷：GET + query 参数
    static func get(env: LWEnvironment = .dev,
                    baseURL: URL? = nil,
                    path: String,
                    params: Parameters? = nil,
                    headers: HTTPHeaders = [:],
                    cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                    requiresAuth: Bool = true) -> LWAPI {
        LWAPI(env: env,
              baseURL: baseURL,
              path: path,
              method: .get,
              task: .requestParameters(params ?? [:], encoding: URLEncoding.default),
              headers: headers,
              cachePolicy: cachePolicy,
              requiresAuth: requiresAuth)
    }

    /// 便捷：POST JSON
    static func postJSON<E: Encodable>(env: LWEnvironment = .dev,
                                       baseURL: URL? = nil,
                                       path: String,
                                       body: E,
                                       headers: HTTPHeaders = [:],
                                       requiresAuth: Bool = true) -> LWAPI {
        var h = headers
        if h["Content-Type"] == nil { h.add(name: "Content-Type", value: "application/json") }
        return LWAPI(env: env,
                     baseURL: baseURL,
                     path: path,
                     method: .post,
                     task: .requestJSONEncodable(body),
                     headers: h,
                     requiresAuth: requiresAuth)
    }

    /// 便捷：Multipart 上传
    static func uploadMultipart(env: LWEnvironment = .dev,
                                baseURL: URL? = nil,
                                path: String,
                                parts: [LWMultipartFormData],
                                headers: HTTPHeaders = [:],
                                requiresAuth: Bool = true) -> LWAPI {
        LWAPI(env: env,
              baseURL: baseURL,
              path: path,
              method: .post,
              task: .uploadMultipart(parts),
              headers: headers,
              requiresAuth: requiresAuth)
    }

    /// 便捷：下载
    static func download(env: LWEnvironment = .dev,
                         baseURL: URL? = nil,
                         path: String,
                         destination: DownloadRequest.Destination? = nil,
                         headers: HTTPHeaders = [:],
                         requiresAuth: Bool = true) -> LWAPI {
        LWAPI(env: env,
              baseURL: baseURL,
              path: path,
              method: .get,
              task: .download(destination: destination),
              headers: headers,
              requiresAuth: requiresAuth)
    }
}
