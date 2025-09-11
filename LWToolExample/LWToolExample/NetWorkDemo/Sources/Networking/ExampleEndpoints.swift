
/*
 作用：示例端点（公共/鉴权）、分页、查询参数、上传与下载；统一使用 HTTPHeaders。
 使用示例：
   let u: User = try await AppNetwork.shared.client.request(UserAPI.getUser(id: "42"), as: User.self)
*/
import Foundation
import Alamofire
import LWToolKit

// MARK: - 辅助：通用头部构造（按需加入鉴权标记）
private func makeHeaders(requiresAuth: Bool, extra: HTTPHeaders = HTTPHeaders()) -> HTTPHeaders {
    var h = extra
    if requiresAuth {
        // 供 LWAuthInterceptor 识别为“需要鉴权”的请求
        h.add(name: "__Requires-Auth__", value: "1")
    }
    return h
}

// MARK: - 1) GET /v1/users/:id  —— 公共接口，不需要鉴权
public struct GetUserEndpoint: LWEndpoint {
    public let baseURL: URL
    public let id: String
    public var path: String { "/v1/users/\(id)" }
    public var method: HTTPMethod { .get }
    public var task: LWTask { .requestPlain }
    public var requiresAuth: Bool { false }
    public var headers: HTTPHeaders { makeHeaders(requiresAuth: requiresAuth, extra: ["Accept": "application/json"]) }
    public init(baseURL: URL, id: String) { self.baseURL = baseURL; self.id = id }
}

// MARK: - 2) GET /v1/me  —— 需要鉴权
public struct MeEndpoint: LWEndpoint {
    public let baseURL: URL
    public var path: String { "/v1/me" }
    public var method: HTTPMethod { .get }
    public var task: LWTask { .requestPlain }
    // 默认 requiresAuth = true，这里显式声明更直观
    public var requiresAuth: Bool { true }
    public var headers: HTTPHeaders { makeHeaders(requiresAuth: requiresAuth) }
    public init(baseURL: URL) { self.baseURL = baseURL }
}

// MARK: - 3) POST /v1/me  —— JSON 修改昵称，需要鉴权
public struct UpdateProfileEndpoint: LWEndpoint {
    public struct Body: Encodable { public let name: String }
    public let baseURL: URL
    public let body: Body
    public var path: String { "/v1/me" }
    public var method: HTTPMethod { .post }
    public var task: LWTask { .requestJSONEncodable(body) }
    public var requiresAuth: Bool { true }
    public var headers: HTTPHeaders {
        makeHeaders(requiresAuth: requiresAuth, extra: ["Content-Type": "application/json", "Accept": "application/json"])
    }
    public init(baseURL: URL, name: String) { self.baseURL = baseURL; self.body = Body(name: name) }
}

// MARK: - 4) GET /v1/feed?page=&page_size=  —— 分页，公共接口
public struct FeedListEndpoint: LWEndpoint {
    public let baseURL: URL
    public let page: Int
    public let pageSize: Int
    public var path: String { "/v1/feed" }
    public var method: HTTPMethod { .get }
    public var task: LWTask { .requestParameters(["page": page, "page_size": pageSize], encoding: URLEncoding.queryString) }
    public var requiresAuth: Bool { false }
    public var headers: HTTPHeaders { makeHeaders(requiresAuth: requiresAuth) }
    public init(baseURL: URL, page: Int, pageSize: Int) {
        self.baseURL = baseURL; self.page = page; self.pageSize = pageSize
    }
}

// MARK: - 5) POST /v1/me/avatar  —— 上传头像（multipart），需要鉴权
public struct UploadAvatarEndpoint: LWEndpoint {
    public let baseURL: URL
    public let fileURL: URL
    public var path: String { "/v1/me/avatar" }
    public var method: HTTPMethod { .post }
    public var task: LWTask {
        let data = (try? Data(contentsOf: fileURL)) ?? Data()
        let part = LWMultipartFormData(name: "avatar",
                                       data: data,
                                       fileName: fileURL.lastPathComponent,
                                       mimeType: "application/octet-stream")
        return .uploadMultipart([part])
    }
    public var requiresAuth: Bool { true }
    public var headers: HTTPHeaders { makeHeaders(requiresAuth: requiresAuth) }
    public init(baseURL: URL, fileURL: URL) { self.baseURL = baseURL; self.fileURL = fileURL }
}

// MARK: - 6) GET /download  —— 下载文件，公共接口
public struct DownloadFileEndpoint: LWEndpoint {
    public let baseURL: URL
    public let path: String
    public var method: HTTPMethod { .get }
    public var task: LWTask { .download(destination: DownloadRequest.suggestedDownloadDestination()) }
    public var requiresAuth: Bool { false }
    public var headers: HTTPHeaders { makeHeaders(requiresAuth: requiresAuth) }
    public init(baseURL: URL, path: String) { self.baseURL = baseURL; self.path = path }
}

// MARK: - Demo 模型（可替换为你项目中的真实模型）
public struct User: Codable { public let id: String; public let name: String }
public struct FeedItem: Codable, Identifiable { public let id: String; public let title: String }
public struct FeedPage: Codable { public let items: [FeedItem]; public let hasMore: Bool }
public struct Ack: Codable { public let ok: Bool }
public struct DownloadOK: Codable { public let ok: Bool }
