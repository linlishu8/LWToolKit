/*
  作用：可插拔日志输出；便于线上问题定位与调试。
  使用示例：
    let logger: YXTBridgeLogger = .print
    logger.log("message")
  特点/注意事项：
    - 可自定义实现闭包输出到你们现有的日志系统。
*/
import Foundation

public struct LWBridgeLogger {
    public let log: (_ message: String) -> Void

    public init(_ log: @escaping (String) -> Void) { self.log = log }

    public static let none = LWBridgeLogger { _ in }
    public static let print = LWBridgeLogger { msg in
        Swift.print("[H5Bridge] \(msg)")
    }
}
