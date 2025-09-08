import Foundation
final class LWETagStore { static let shared = LWETagStore(); private let lock = NSLock(); private var tags:[String:String]=[:]; func tag(for url: URL?) -> String? { guard let u=url?.absoluteString else {return nil}; lock.lock(); defer{lock.unlock()}; return tags[u] }; func set(_ t:String, for url:URL?){ guard let u=url?.absoluteString else{return}; lock.lock(); tags[u]=t; lock.unlock() } }
public struct LWETagMiddleware: LWMiddleware {
  public init() {}
  public func prepare(_ r: URLRequest) -> URLRequest { guard (r.httpMethod ?? "GET")=="GET" else { return r }; var req=r; if let t=LWETagStore.shared.tag(for:r.url){ req.setValue(t, forHTTPHeaderField:"If-None-Match") }; return req }
  public func willSend(_ request: URLRequest) {}
  public func didReceive(_ result: Result<(HTTPURLResponse, Data), LWNetworkError>, for request: URLRequest) { guard (request.httpMethod ?? "GET")=="GET" else { return }; if case .success((let http,_))=result, let t=http.value(forHTTPHeaderField:"Etag"), !t.isEmpty { LWETagStore.shared.set(t, for: request.url) } }
}
