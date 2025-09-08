import Foundation
public final class LWRateLimiter {
    private var timestamps:[String:[TimeInterval]] = [:]
    private let limit:Int; private let window:TimeInterval
    public init(limit:Int, window:TimeInterval){ self.limit=limit; self.window=window }
    public func allow(_ key:String)->Bool{
        let now=CFAbsoluteTimeGetCurrent(); var arr=(timestamps[key] ?? []).filter{ now-$0 <= window }
        if arr.count >= limit { timestamps[key]=arr; return false }
        arr.append(now); timestamps[key]=arr; return true
    }
}
