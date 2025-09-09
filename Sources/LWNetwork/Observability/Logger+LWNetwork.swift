import Foundation
import OSLog

/**
 Logger.lwNetwork
 ----------------
 作用：
 统一的网络日志分类 Logger，供网络层打印使用（如 LWAFLogger）。

 使用示例：
 ```swift
 Logger.lwNetwork.debug("message")
 Logger.lwNetwork.error("oops")
 ```
 */
public extension Logger {
    static let lwNetwork = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "lw.app",
        category: "network"
    )
}
