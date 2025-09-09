
//
//  NetworkDemoEnv.swift
//
/*
 作用：
   统一构建 LWAlamofireClient，并提供 Demo 所需的 API 构造方法。
 使用示例：
   let client = DemoNetwork.shared.client
   let ep = DemoAPI.get(path: "/get", query: ["foo":"bar"])
   let res: Model = try await client.request(ep, as: Model.self)
*/

import Foundation
import Alamofire
import LWToolKit

public final class DemoNetwork {
    public static let shared = DemoNetwork()
    public let client: LWAlamofireClient

    public init() {
        let config = LWNetworkConfig()
        let interceptor = LWAuthInterceptor() // 在 Auth 刷新 Demo 中说明如何配置
        self.client = LWAlamofireClient(config: config, interceptor: interceptor, monitors: [])
    }
}

public enum DemoAPI {
    static let httpBase = "https://httpbingo.org"

    // 将 [String:String] 转为 HTTPHeaders
    private static func toAFHeaders(_ dict: [String:String]) -> HTTPHeaders {
        var h = HTTPHeaders()
        for (k, v) in dict { h.add(name: k, value: v) }
        return h
    }

    public static func get(path: String,
                           query: [String: Any] = [:],
                           headers: [String:String] = [:],
                           requiresAuth: Bool = false) -> LWAPI {
        let h = toAFHeaders(headers)
        return LWAPI(env: .prod,
                     baseURL: URL(string: httpBase),
                     path: path,
                     method: .get,
                     task: .requestParameters(query, encoding: URLEncoding.queryString),
                     headers: h,
                     requiresAuth: requiresAuth)
    }

    public static func postJSON(path: String,
                                json: [String: Any] = [:],
                                headers: [String:String] = [:],
                                requiresAuth: Bool = false) -> LWAPI {
        var h = toAFHeaders(headers)
        // 明确指定 Content-Type
        h.add(name: "Content-Type", value: "application/json")
        return LWAPI(env: .prod,
                     baseURL: URL(string: httpBase),
                     path: path,
                     method: .post,
                     // 新版没有 `.requestJSON`；使用 JSONEncoding.default 或改 Encodable
                     task: .requestParameters(json, encoding: JSONEncoding.default),
                     headers: h,
                     requiresAuth: requiresAuth)
    }

    public static func void(path: String,
                            method: HTTPMethod,
                            requiresAuth: Bool = false) -> LWAPI {
        return LWAPI(env: .prod,
                     baseURL: URL(string: httpBase),
                     path: path,
                     method: method,
                     task: .requestPlain,
                     headers: HTTPHeaders(),
                     requiresAuth: requiresAuth)
    }
}

public extension Dictionary where Key == String, Value == Any {
    var prettyJSONString: String {
        guard JSONSerialization.isValidJSONObject(self),
              let data = try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted]),
              let s = String(data: data, encoding: .utf8) else { return String(describing: self) }
        return s
    }
}
