import Foundation
public protocol LWCrashReporting { func record(_ error: Error, userInfo:[String:Any]?); func setUser(id:String?) }
public final class LWCrashReporter: LWCrashReporting {
    public init() {}
    public func record(_ error: Error, userInfo: [String : Any]?) { /* plug Crashlytics/Sentry */ }
    public func setUser(id: String?) { /* set user in SDK */ }
}
