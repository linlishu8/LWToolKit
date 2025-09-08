import Foundation
import Network

@available(iOS 12.0, tvOS 12.0, *)
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
