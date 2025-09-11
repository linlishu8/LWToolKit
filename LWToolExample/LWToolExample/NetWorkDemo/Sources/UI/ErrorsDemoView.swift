
/*
 作用：演示错误分支：403/404/429/5xx，含指数退避重试（仅示意，真实重试策略以拦截器/中间件为准）。
 使用示例：
   ErrorsDemoView()
*/
import SwiftUI
import LWToolKit
import Alamofire

// 一个调试端点：/debug/status/:code 返回对应状态
struct DebugStatusEndpoint: LWEndpoint {
    let baseURL: URL
    let code: Int
    var path: String { "/debug/status/\(code)" }
    var method: HTTPMethod { .get }
    var task: LWTask { .requestPlain }
    var requiresAuth: Bool { false }
    var headers: HTTPHeaders { ["Accept": "application/json"] }
}

public struct ErrorsDemoView: View {
    @State private var out = "Tap to trigger errors"
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Button("触发 404") { Task { await fire(code: 404) } }
            Button("触发 403") { Task { await fire(code: 403) } }
            Button("触发 429（带退避重试）") { Task { await fire(code: 429, retry: true) } }
            Button("触发 500（带退避重试）") { Task { await fire(code: 500, retry: true) } }
            ScrollView { Text(out).frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.secondarySystemBackground)).cornerRadius(12) }
        }.padding().navigationTitle("错误分支")
    }
    private func fire(code: Int, retry: Bool = false) async {
        let ep = DebugStatusEndpoint(baseURL: AppEnvironment.current.baseURL, code: code)
        var attempt = 0
        while true {
            do {
                struct R: Codable { let message: String }
                let r: R = try await AppNetwork.shared.client.request(ep)
                out = "✅ \(r.message)"; return
            } catch {
                let e = AppNetworkError.from(error)
                if retry, attempt < 3 {
                    switch e {
                    case .rateLimited,
                         .server(_):
                        attempt += 1
                        let delay = Backoff.exponential(attempt: attempt)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    default:
                        break
                    }
                }
                out = "❌ \(e.userMessage)"; return
            }
        }
    }
}
