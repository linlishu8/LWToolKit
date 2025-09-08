import Foundation
public protocol LWEventTracking { func track(name: String, params: [String: Any]?) }
public final class LWEventTracker: LWEventTracking {
    public static let shared = LWEventTracker()
    private let queue = DispatchQueue(label: "lw.event.tracker")
    private var sinks: [(String,[String:Any]?)->Void] = []
    public func addSink(_ s:@escaping (String,[String:Any]?)->Void){ queue.sync{ sinks.append(s) } }
    public func track(name: String, params: [String: Any]? = nil){ queue.async{ self.sinks.forEach{ $0(name, params) } } }
}
