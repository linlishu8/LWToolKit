import Foundation
import Alamofire

/**
 LWEndpoint / LWTask / LWMultipartFormData
 ----------------------------------------
 作用：
 定义网络层的**端点协议**与**请求任务类型**，以及一个轻量的表单文件片段结构，
 便于与 `LWAlamofireClient` 等客户端对接实现统一的请求描述。

 - `LWEndpoint`：抽象一个可发起的请求（基地址、路径、方法、任务、头、缓存策略、是否需要鉴权）。
 - `LWTask`：描述请求负载（纯请求、参数编码、JSON Encodable、Multipart 上传、下载）。
 - `LWMultipartFormData`：描述单个表单字段/文件，供 Multipart 上传使用。

 使用示例：
 ```swift
 // 1) 最简端点：GET /v1/me?expand=profile
 struct MeEndpoint: LWEndpoint {
     let baseURL = URL(string: "https://api.example.com")!
     let path = "/v1/me"
     let method: HTTPMethod = .get
     let task: LWTask = .requestParameters(["expand": "profile"], encoding: URLEncoding.default)
     // 其余使用协议扩展的默认值（headers/cachePolicy/requiresAuth）
 }

 // 2) JSON 提交
 struct CreatePost: Encodable { let title: String; let body: String }
 struct CreatePostEndpoint: LWEndpoint {
     let baseURL = URL(string: "https://api.example.com")!
     let path = "/v1/posts"
     let method: HTTPMethod = .post
     let task: LWTask = .requestJSONEncodable(CreatePost(title: "Hello", body: "World"))
 }

 // 3) Multipart 上传
 let part1 = LWMultipartFormData(name: "title", data: Data("hi".utf8))
 let part2 = LWMultipartFormData(name: "image", data: pngData,
                                 fileName: "pic.png", mimeType: "image/png")
 struct UploadEP: LWEndpoint {
     let baseURL = URL(string: "https://api.example.com")!
     let path = "/v1/upload"
     let method: HTTPMethod = .post
     let task: LWTask = .uploadMultipart([part1, part2])
 }
 ```

 注意事项：
 - `headers`/`cachePolicy`/`requiresAuth` 提供了**默认实现**，可按需在端点里覆盖。
 - `uploadMultipart` 需要客户端侧使用 `Alamofire.MultipartFormData` 逐个追加片段；
   如使用 `LWAlamofireClient`，请在其上传实现中遍历 `LWMultipartFormData` 生成 AF 的表单体。
 - `download(destination:)` 可指定 Alamofire 的目标落盘策略；传 `nil` 使用默认位置。
 */

// MARK: - Endpoint Protocol

public protocol LWEndpoint {
    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var task: LWTask { get }
    var headers: HTTPHeaders { get }
    var cachePolicy: URLRequest.CachePolicy { get }
    var requiresAuth: Bool { get }
}

// 默认实现（可在端点结构体中覆盖）
public extension LWEndpoint {
    var headers: HTTPHeaders { HTTPHeaders() }
    var cachePolicy: URLRequest.CachePolicy { .useProtocolCachePolicy }
    var requiresAuth: Bool { true }
}

// MARK: - Task Types

public enum LWTask {
    /// 纯请求，无参数（常用于简单 GET）
    case requestPlain

    /// 参数请求（支持 `.get/.post` 等；编码器由调用方传入，如 `URLEncoding.default` 或 `JSONEncoding.default`）
    case requestParameters(Parameters, encoding: ParameterEncoding)

    /// 将 Encodable 作为 JSON Body（使用外层的 JSONEncoder 编码）
    case requestJSONEncodable(Encodable)

    /// Multipart 上传
    case uploadMultipart([LWMultipartFormData])

    /// 下载任务，可自定义落盘位置策略
    case download(destination: DownloadRequest.Destination?)
}

// MARK: - Multipart Part

/// 表单字段/文件片段
public struct LWMultipartFormData {
    public let name: String
    public let data: Data
    public let fileName: String?
    public let mimeType: String?

    public init(name: String, data: Data, fileName: String? = nil, mimeType: String? = nil) {
        self.name = name
        self.data = data
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

// MARK: - Helpers

public extension LWMultipartFormData {
    /// 便捷构造纯文本字段（UTF-8）
    static func text(name: String, _ value: String, mimeType: String = "text/plain; charset=utf-8") -> LWMultipartFormData {
        LWMultipartFormData(name: name, data: Data(value.utf8), fileName: nil, mimeType: mimeType)
    }
}

public extension Array where Element == LWMultipartFormData {
    /// 追加到 Alamofire 的 MultipartFormData
    func append(to af: Alamofire.MultipartFormData) {
        for part in self {
            if let fname = part.fileName, let type = part.mimeType {
                af.append(part.data, withName: part.name, fileName: fname, mimeType: type)
            } else {
                af.append(part.data, withName: part.name)
            }
        }
    }
}
