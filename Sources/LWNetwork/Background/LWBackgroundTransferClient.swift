
import Foundation

public protocol LWBackgroundTransferDelegate: AnyObject {
  func bgProgress(id: String, bytesWritten: Int64, totalBytes: Int64)
  func bgFinished(id: String, fileURL: URL)
  func bgFailed(id: String, error: Error)
}

public final class LWBackgroundTransferClient: NSObject, URLSessionDownloadDelegate {
  public static let shared = LWBackgroundTransferClient()
  private let identifier = "com.example.lw.bg"
  private lazy var bgSession: URLSession = {
    let cfg: URLSessionConfiguration
    // Background session does not support custom URLProtocol; for demo.local fallback to default session
    if #available(iOS 13.0, *), useBackground {
      cfg = URLSessionConfiguration.background(withIdentifier: identifier)
    } else {
      cfg = URLSessionConfiguration.default
    }
    return URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
  }()

  private var useBackground: Bool = true
  private var tasks: [String: URLSessionDownloadTask] = [:]
  public weak var delegate: LWBackgroundTransferDelegate?

  public func setUseBackground(_ on: Bool) { self.useBackground = on }

  @discardableResult
  public func download(id: String, from url: URL) -> String {
    // fallback: if host == demo.local, force default session so our mock URLProtocol works
    if url.host == "demo.local" { useBackground = false }
    let task = bgSession.downloadTask(with: url)
    tasks[id] = task
    task.resume()
    return id
  }

  public func cancel(id: String) { tasks[id]?.cancel(); tasks[id] = nil }

  // MARK: URLSessionDownloadDelegate
  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
    let id = tasks.first(where: { $0.value == downloadTask })?.key ?? "unknown"
    delegate?.bgProgress(id: id, bytesWritten: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
  }

  public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    let id = tasks.first(where: { $0.value == downloadTask })?.key ?? "unknown"
    delegate?.bgFinished(id: id, fileURL: location)
    tasks[id] = nil
  }

  public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    guard let error else { return }
    let id = tasks.first(where: { $0.value == task })?.key ?? "unknown"
    delegate?.bgFailed(id: id, error: error)
    tasks[id] = nil
  }

  // AppDelegate hook for true background resume
  private static var pendingHandler: (() -> Void)?
  public static func handleEvents(for identifier: String, completionHandler: @escaping () -> Void) {
    guard identifier == LWBackgroundTransferClient.shared.identifier else { completionHandler(); return }
    pendingHandler = completionHandler
  }

  public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
    LWBackgroundTransferClient.pendingHandler?()
    LWBackgroundTransferClient.pendingHandler = nil
  }
}
