import Foundation
import Alamofire
import LWToolKit

/// 业务层的便捷 API：最少代码地完成 GET/POST/上传/下载；
/// 提供并发聚合（zip2/zip3）、串行登录编排（loginPipeline），
/// 以及带业务包裹自动解包的 *E 方法（getE/postJSONE/postFormE）。
public enum AppAPI {

    // MARK: - 兼容：直接返回 T 的接口
    /// GET（解析为 T）
    public static func get<T: Decodable>(_ path: String, auth: Bool = false, query: [String: Any]? = nil) async throws -> T {
        let ep = EZEndpoint(path: path, method: .get, requiresAuth: auth, task: .requestParameters(query ?? [:], encoding: URLEncoding.queryString))
        return try await request(ep, as: T.self)
    }

    /// POST JSON（解析为 T）
    public static func postJSON<T: Decodable>(_ path: String, auth: Bool = false, body: Encodable) async throws -> T {
        let ep = EZEndpoint(path: path, method: .post, requiresAuth: auth, task: .requestJSONEncodable(body))
        return try await request(ep, as: T.self)
    }

    /// POST 表单（解析为 T）
    public static func postForm<T: Decodable>(_ path: String, auth: Bool = false, params: [String: Any]) async throws -> T {
        let ep = EZEndpoint(path: path, method: .post, requiresAuth: auth, task: .requestParameters(params, encoding: URLEncoding.httpBody))
        return try await request(ep, as: T.self)
    }

    /// 上传（解析为 T）
    public static func upload<T: Decodable>(_ path: String, auth: Bool = false, parts: [LWMultipartFormData]) async throws -> T {
        let ep = EZEndpoint(path: path, method: .post, requiresAuth: auth, task: .uploadMultipart(parts))
        return try await request(ep, as: T.self)
    }

    /// 下载到指定目的地
    public static func download(_ path: String, auth: Bool = false, to dest: @escaping DownloadRequest.Destination) async throws {
        let ep = EZEndpoint(path: path, method: .get, requiresAuth: auth, task: .download(destination: dest))
        try await AppNetwork.shared.client.requestVoid(ep)
    }

    /// 统一错误路由（适用于非业务包裹）
    public static func request<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T {
        do {
            return try await AppNetwork.shared.client.request(ep, as: T.self)
        } catch {
            AppErrorRouter.route(error)
            throw error
        }
    }

    // MARK: - 新增：业务包裹自动解包（适配 {code,message,data}）
    /// GET + Envelope 自动解包（`code != 0` 抛 `AppError.business`）
    public static func getE<T: Decodable>(_ path: String, auth: Bool = false, query: [String: Any]? = nil) async throws -> T {
        try await requestE(EZEndpoint(path: path, method: .get, requiresAuth: auth, task: .requestParameters(query ?? [:], encoding: URLEncoding.queryString)), as: T.self)
    }

    /// POST JSON + Envelope 自动解包
    public static func postJSONE<T: Decodable>(_ path: String, auth: Bool = false, body: Encodable) async throws -> T {
        try await requestE(EZEndpoint(path: path, method: .post, requiresAuth: auth, task: .requestJSONEncodable(body)), as: T.self)
    }

    /// POST Form + Envelope 自动解包
    public static func postFormE<T: Decodable>(_ path: String, auth: Bool = false, params: [String: Any]) async throws -> T {
        try await requestE(EZEndpoint(path: path, method: .post, requiresAuth: auth, task: .requestParameters(params, encoding: URLEncoding.httpBody)), as: T.self)
    }

    /// 实现 Envelope 自动解包的核心逻辑
    private static func requestE<T: Decodable>(_ ep: LWEndpoint, as: T.Type) async throws -> T {
        do {
            let env: Envelope<T> = try await AppNetwork.shared.client.request(ep, as: Envelope<T>.self)
            if let code = env.code, code != 0 {
                let msg = env.message ?? "业务错误 \(code)"
                let appErr: AppError = (code == 401 ? .unauthorized : .business(code: code, message: msg))
                AppErrorRouter.route(appErr)
                throw appErr
            }
            if let v = env.data { return v }
            // 一些接口直接返回 T，无包裹；降级到 T 直解
            return try await AppNetwork.shared.client.request(ep, as: T.self)
        } catch {
            AppErrorRouter.route(error)
            throw error
        }
    }

    // MARK: - 聚合 & 编排
    /// 并发聚合两个接口
    public static func zip2<A: Decodable, B: Decodable>(_ a: LWEndpoint, _ b: LWEndpoint, as: (A.Type, B.Type)) async throws -> (A, B) {
        async let ra: A = request(a, as: A.self)
        async let rb: B = request(b, as: B.self)
        return try await (ra, rb)
    }

    /// 并发聚合三个接口
    public static func zip3<A: Decodable, B: Decodable, C: Decodable>(_ a: LWEndpoint, _ b: LWEndpoint, _ c: LWEndpoint, as: (A.Type, B.Type, C.Type)) async throws -> (A, B, C) {
        async let ra: A = request(a, as: A.self)
        async let rb: B = request(b, as: B.self)
        async let rc: C = request(c, as: C.self)
        return try await (ra, rb, rc)
    }

    /// 登录三步的串行编排（获取住户ID → 登录 → 换 Token）
    public static func loginPipeline(username: String, password: String) async throws -> AuthToken {
        struct Resident: Decodable { let residentId: String }
        struct Ticket: Decodable { let ticket: String }
        struct ExchangeOut: Decodable { let accessToken: String; let refreshToken: String; let expiresIn: TimeInterval }

        let r: Resident = try await get("/auth/resident-id")
        let t: Ticket = try await postJSON("/auth/login", body: ["username": username, "password": password, "residentId": r.residentId])
        let x: ExchangeOut = try await postJSON("/auth/token", body: ["ticket": t.ticket])

        let tok = AuthToken(accessToken: x.accessToken, refreshToken: x.refreshToken, expiresAt: Date().addingTimeInterval(x.expiresIn))
        try? await TokenStore.shared.save(tok)
        return tok
    }
}
