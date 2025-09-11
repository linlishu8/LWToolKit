
/*
 作用：统一管理接口域名/环境，便于 Dev/Staging/Prod 切换；并桥接到 LWEnvironment。
 使用示例：
   AppEnvironment.current = .staging
   let ep = LWAPI(env: AppEnvironment.current.lwEnv, path: "/v1/users/42", method: .get, task: .requestPlain, headers: HTTPHeaders(), requiresAuth: false)
*/
import Foundation
import Alamofire
import LWToolKit

public enum AppEnvironment: String, CaseIterable {
    case dev, staging, prod
    public static var current: AppEnvironment = .dev

    public var baseURL: URL {
        switch self {
        case .dev:     return URL(string: "https://api-dev.example.com")!
        case .staging: return URL(string: "https://api-staging.example.com")!
        case .prod:    return URL(string: "https://api.example.com")!
        }
    }
}
