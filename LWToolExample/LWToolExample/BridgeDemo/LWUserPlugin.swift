/*
  作用：示例插件（UserPlugin），实现 user.info，返回 H5 需要的用户/环境信息。
  使用示例：
    let user = UserPlugin(providers: .init(
        accessToken: { tokenStore.accessToken },
        refreshToken: { tokenStore.refreshToken },
        userId: { currentUser.id },
        userType: { currentUser.type }
    ))
    bridge.register(plugin: user)
  特点/注意事项：
    - 通过闭包注入，避免直接耦合你们的鉴权/会话系统；便于单元测试。
*/
import Foundation
import LWToolKit

public final class LWUserPlugin: LWBridgePlugin {
    public struct Providers {
        public var accessToken: () -> String?
        public var refreshToken: () -> String?
        public var userId: () -> String?
        public var userType: () -> String?
        public var deviceOS: () -> String
        public var appVersion: () -> String
        public var acceptLanguage: () -> String

        public init(accessToken: @escaping () -> String? = { nil },
                    refreshToken: @escaping () -> String? = { nil },
                    userId: @escaping () -> String? = { nil },
                    userType: @escaping () -> String? = { nil },
                    deviceOS: @escaping () -> String = { "iOS" },
                    appVersion: @escaping () -> String = { "1.0.0" },
                    acceptLanguage: @escaping () -> String = { "zh-CN" }) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.userId = userId
            self.userType = userType
            self.deviceOS = deviceOS
            self.appVersion = appVersion
            self.acceptLanguage = acceptLanguage
        }
    }

    public let module: String = "user"
    private let providers: Providers

    public init(providers: Providers) {
        self.providers = providers
    }

    public func canHandle(method: String) -> Bool {
        return method == "info"
    }

    public func handle(method: String,
                       params: [String : LWAnyCodable]?,
                       completion: @escaping (Result<LWAnyCodable, LWBridgeError>) -> Void) {
        guard method == "info" else {
            completion(.failure(.notFound(module: module, method: method)))
            return
        }
        // 组装结构
        let res: [String: Any] = [
            "accessToken": providers.accessToken() as Any,
            "refreshToken": providers.refreshToken() as Any,
            "userId": providers.userId() as Any,
            "userType": providers.userType() as Any,
            "deviceOs": providers.deviceOS(),
            "appVersion": providers.appVersion(),
            "acceptLanguage": providers.acceptLanguage()
        ]
        completion(.success(LWAnyCodable(res)))
    }
}
