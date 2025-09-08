import Foundation
import Network
public final class LWReachability { public static let shared = LWReachability(); private let monitor = NWPathMonitor(); private let q = DispatchQueue(label: "lw.reach"); public private(set) var isReachable = true; public func start(){ monitor.pathUpdateHandler = { [weak self] p in self?.isReachable = (p.status == .satisfied) }; monitor.start(queue: q) } ; public func stop(){ monitor.cancel() } }
