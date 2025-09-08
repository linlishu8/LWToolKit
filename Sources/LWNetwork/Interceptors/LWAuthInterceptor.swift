import Foundation
import Alamofire
public final class LWAuthInterceptor: RequestInterceptor {
  public init() {}
  public func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
    Task { var req = urlRequest
      do {
        if let needs = req.value(forHTTPHeaderField: "__Requires-Auth__"), needs == "1" {
          let token = try await LWTokenStore.shared.validAccessToken()
          let sid = await LWSessionManager.shared.sessionId
          req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
          req.setValue(sid, forHTTPHeaderField: "X-Session-Id")
        }
        completion(.success(req))
      } catch { completion(.failure(error)) }
    }
  }
  public func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
    let code = request.response?.statusCode ?? (error as NSError).code
    if code == 401 { Task { do { _ = try await LWTokenStore.shared.validAccessToken(); completion(.retry) } catch { completion(.doNotRetryWithError(error)) } }; return }
    if (500..<600).contains(code), request.retryCount < 2 { completion(.retryWithDelay(pow(2.0, Double(request.retryCount)))) ; return }
    completion(.doNotRetry)
  }
}
