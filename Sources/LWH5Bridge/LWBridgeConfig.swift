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
    public var channelName: String
    public var version: String
    public var allowedHosts: [String] = []
    public var methodAllowList: [String]? = nil// e.g., ["user.info", "bridge.version"]
    public var maxPayloadBytes: Int = 512 * 1024
    public var logger: LWBridgeLogger = .none

    public var autoInjectBootstrap: Bool = true
    public var bootstrap: Bootstrap = .defaultNative
    public var injectionTime: WKUserScriptInjectionTime = .atDocumentStart
    public var forMainFrameOnly: Bool = true

    public enum Bootstrap {
        /// 使用原有“二段式 call + __nativeDispatch”默认脚本
        case defaultNative
        /// 自定义：按项目返回要注入的 JS（channel/version 可用于插值）
        case custom((_ channel: String, _ version: String) -> String)
    }
    
    public init(channelName: String, version: String) {
        self.channelName = channelName
        self.version = version
    }
}
