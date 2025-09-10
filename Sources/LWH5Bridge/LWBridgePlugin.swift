/*
  作用：定义插件协议与注册中心，按 module.method 进行路由。
  使用示例：
    bridge.register(plugin: UserPlugin(providers: ...))
  特点/注意事项：
    - 插件建议无状态或最小状态，线程安全；耗时任务放后台队列执行。
*/
import Foundation

public protocol LWBridgePlugin {
    var module: String { get }
    func canHandle(method: String) -> Bool
    func handle(method: String,
                params: [String: LWAnyCodable]?,
                completion: @escaping (Result<LWAnyCodable, LWBridgeError>) -> Void)
}

public final class BridgeRegistry {
    private var plugins: [String: LWBridgePlugin] = [:]
    private let lock = NSLock()

    public init() {}

    public func register(_ plugin: LWBridgePlugin) {
        lock.lock(); defer { lock.unlock() }
        plugins[plugin.module] = plugin
    }

    public func plugin(for module: String) -> LWBridgePlugin? {
        lock.lock(); defer { lock.unlock() }
        return plugins[module]
    }
}
