import Foundation
import Network

/**
 LWReachability
 ----------------
 作用：
 一个**基于 NWPathMonitor 的网络可达性工具**（iOS/tvOS 12+）。
 提供当前可达性 `isReachable`、网络代价/受限标记、常见接口类型判断（Wi‑Fi/蜂窝），
 以及**变更回调**与系统通知，适合在 App 内统一监听网络状态。

 使用示例：
 ```swift
 // 1) 直接判断是否可达
 if #available(iOS 12.0, tvOS 12.0, *) {
     if LWReachability.shared.isReachable {
         // 有网
     } else {
         // 断网
     }
 }

 // 2) 监听变更（闭包回调）
 if #available(iOS 12.0, tvOS 12.0, *) {
     let token = LWReachability.shared.addObserver { path in
         print("reachable:", path.status == .satisfied,
               "wifi:", LWReachability.shared.isOnWiFi,
               "cell:", LWReachability.shared.isOnCellular)
     }
     // 需要时可移除：LWReachability.shared.removeObserver(token)
 }

 // 3) 监听变更（Notification）
 // NotificationCenter.default.addObserver(forName: LWReachability.didUpdate, object: nil, queue: .main) { note in
 //     if let path = note.userInfo?["path"] as? NWPath {
 //         print("updated:", path.status)
 //     }
 // }
 ```

 注意事项：
 - NWPathMonitor 的回调默认不在主线程，本工具在内部监听队列中更新状态；
   若你需要更新 UI，请自行切到主线程。
 - `isConstrained` 与 `isExpensive` 依赖系统策略（如低数据模式、蜂窝网络）。
 */
@available(iOS 12.0, tvOS 12.0, *)
public final class LWReachability {

    // MARK: - Notification

    public static let didUpdate = Notification.Name("LWReachability.didUpdate")

    // MARK: - Singleton

    public static let shared = LWReachability()

    // MARK: - Internal state

    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "com.lw.reachability.monitor")
    private var _path: NWPath?

    private var observers: [UUID: (NWPath) -> Void] = [:]

    // MARK: - Init

    private init() {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            self._path = path

            // 通知回调者
            let callbacks = self.observers.values
            if !callbacks.isEmpty {
                for cb in callbacks { cb(path) }
            }

            // 系统通知
            NotificationCenter.default.post(name: LWReachability.didUpdate,
                                            object: self, userInfo: ["path": path])
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Observers

    /// 添加状态变更观察者（返回移除用的 token）
    @discardableResult
    public func addObserver(_ handler: @escaping (NWPath) -> Void) -> UUID {
        let id = UUID()
        queue.async { [weak self] in
            self?.observers[id] = handler
            if let p = self?._path {
                handler(p) // 立即回调一次当前状态（可选）
            }
        }
        return id
    }

    /// 移除观察者
    public func removeObserver(_ token: UUID) {
        queue.async { [weak self] in
            self?.observers.removeValue(forKey: token)
        }
    }

    // MARK: - Accessors

    /// 当前路径（线程安全快照）
    public var currentPath: NWPath? {
        var p: NWPath?
        queue.sync { p = _path }
        return p
    }

    /// 是否可达
    public var isReachable: Bool {
        (currentPath?.status == .satisfied)
    }

    /// 是否为蜂窝网络（当前可用接口包含 cellular）
    public var isOnCellular: Bool {
        guard let p = currentPath else { return false }
        return p.availableInterfaces.contains { $0.type == .cellular }
    }

    /// 是否为 Wi‑Fi（当前可用接口包含 wifi）
    public var isOnWiFi: Bool {
        guard let p = currentPath else { return false }
        return p.availableInterfaces.contains { $0.type == .wifi }
    }

    /// 是否为受限网络（如低数据模式）
    public var isConstrained: Bool {
        currentPath?.isConstrained ?? false
    }

    /// 是否为昂贵网络（蜂窝/热点等）
    public var isExpensive: Bool {
        currentPath?.isExpensive ?? false
    }
}
