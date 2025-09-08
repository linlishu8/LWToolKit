import Foundation
import Network

/// Simple reachability helper using NWPathMonitor (iOS 12+)
public final class LWReachability {
    public static let shared = LWReachability()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.lw.reachability.monitor")
    private var status: NWPath.Status = .requiresConnection

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.status = path.status
        }
        monitor.start(queue: queue)
    }

    public var isReachable: Bool { status == .satisfied }
}