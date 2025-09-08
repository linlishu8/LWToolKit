import Foundation
public final class LWPerfMetrics {
    public static let shared = LWPerfMetrics()
    private var marks:[String:CFAbsoluteTime]=[:]
    public func mark(_ k:String){ marks[k]=CFAbsoluteTimeGetCurrent() }
    public func measure(since k:String)->TimeInterval?{ marks[k].map{ CFAbsoluteTimeGetCurrent() - $0 } }
}
