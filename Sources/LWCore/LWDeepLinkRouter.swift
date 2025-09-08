import Foundation
public final class LWDeepLinkRouter {
    public static let shared = LWDeepLinkRouter()
    public typealias Handler = (URL,[String:String])->Bool
    private var routes:[String:Handler]=[:]
    public func register(host:String, handler:@escaping Handler){ routes[host.lowercased()] = handler }
    @discardableResult public func open(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.reduce(into:[String:String]()){ $0[$1.name]=$1.value } ?? [:]
        return routes[host]?(url, params) ?? false
    }
}
