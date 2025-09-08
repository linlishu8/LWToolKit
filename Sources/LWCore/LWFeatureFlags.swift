import Foundation
public final class LWFeatureFlags {
    public static let shared = LWFeatureFlags()
    private var local:[String:Any]=[:], remote:[String:Any]=[:]
    public func setup(local:[String:Any]){self.local=local}
    public func updateRemote(_ d:[String:Any]){remote=d}
    public func bool(_ k:String, default def:Bool=false)->Bool{ (remote[k] as? Bool) ?? (local[k] as? Bool) ?? def }
    public func string(_ k:String, default def:String="")->String{ (remote[k] as? String) ?? (local[k] as? String) ?? def }
}
