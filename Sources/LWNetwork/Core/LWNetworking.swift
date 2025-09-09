import Foundation
import Alamofire

/**
 LWNetworking
 ----------------
 作用：
 定义统一的网络抽象协议，屏蔽底层实现（如 Alamofire、URLSession 等）。
 约定了 4 类常用操作：
 - `request(_:as:)`：请求并按 `Decodable` 解码为模型；
 - `requestVoid(_:)`：无返回体的请求；
 - `upload(_:as:)`：上传并解码响应；
 - `download(_:)`：下载文件到本地，返回目标 URL。

 通过该协议，上层只依赖抽象，便于在单元测试中注入 Mock，或替换不同网络栈实现。

 使用示例：
 ```swift
 struct User: Decodable { let id: String; let name: String }

 // 你的客户端需遵循 LWNetworking（例如 LWAlamofireClient）
 let client: LWNetworking = LWAlamofireClient(config: .init())

 // 1) 解码模型
 let user: User = try await client.request(MeEndpoint(), as: User.self)

 // 2) 利用协议扩展的类型推断便捷重载（见下方 extension）
 let user2: User = try await client.request(MeEndpoint())

 // 3) 无返回体
 try await client.requestVoid(DeleteAccountEndpoint())

 // 4) 上传并解码响应
 let resp: UploadResult = try await client.upload(UploadAvatarEndpoint(data: pngData))

 // 5) 下载
 let fileURL: URL = try await client.download(DownloadInvoicePDF(id: "123"))
 ```

 注意事项：
 - 该协议只定义接口，不限制实现细节；解码策略（日期、keyDecoding）交给实现方配置。
 - 协议扩展中提供了基于**类型推断**的便捷重载，可直接写 `try await client.request(ep)`。
 - `LWEndpoint`/`LWTask` 的定义见对应文件；实现方需正确处理其不同分支（parameters/json/multipart 等）。
 */
public protocol LWNetworking: Sendable {
    func request<T: Decodable>(_ endpoint: LWEndpoint, as: T.Type) async throws -> T
    func requestVoid(_ endpoint: LWEndpoint) async throws
    func upload<T: Decodable>(_ endpoint: LWEndpoint, as: T.Type) async throws -> T
    func download(_ endpoint: LWEndpoint) async throws -> URL
}

// MARK: - Sugar (type-inferred overloads)

public extension LWNetworking {
    /// 便捷：通过泛型推断返回类型
    func request<T: Decodable>(_ endpoint: LWEndpoint) async throws -> T {
        try await request(endpoint, as: T.self)
    }

    /// 便捷：上传并通过泛型推断返回类型
    func upload<T: Decodable>(_ endpoint: LWEndpoint) async throws -> T {
        try await upload(endpoint, as: T.self)
    }
}
