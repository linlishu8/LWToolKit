/*
  作用：桥接器配置，包括域名白名单、通道名、版本、包体限制、日志等。
  使用示例：
    let config = YXTBridgeConfig(allowedHosts: ["192.168.0.15"], logger: .print)
  特点/注意事项：
    - iOS13 WKWebView 无 App-Bound Domains（iOS14+），故使用白名单逻辑限制来源。
*/
import Foundation
import WebKit

public struct LWBridgeConfig {
    public var channelName: String = "YXTBridge"
    public var version: String = "1.0.0"
    public var allowedHosts: Set<String> = []
    public var maxPayloadBytes: Int = 512 * 1024 // 512KB
    public var logger: LWBridgeLogger = .none
    public var methodAllowList: Set<String>? = nil // e.g., ["user.info", "bridge.version"]

    public init(channelName: String = "YXTBridge",
                version: String = "1.0.0",
                allowedHosts: Set<String> = [],
                maxPayloadBytes: Int = 512*1024,
                logger: LWBridgeLogger = .none,
                methodAllowList: Set<String>? = nil) {
        self.channelName = channelName
        self.version = version
        self.allowedHosts = allowedHosts
        self.maxPayloadBytes = maxPayloadBytes
        self.logger = logger
        self.methodAllowList = methodAllowList
    }
}
