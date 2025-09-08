import Foundation
public final class LWABTest { public static let shared = LWABTest(); private var buckets:[String:String]=[:]; public func bucket(for key:String, variants:[String])->String{ if let b=buckets[key]{return b}; let pick=variants.randomElement() ?? variants.first ?? "A"; buckets[key]=pick; return pick } }
