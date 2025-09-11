
/*
 作用：演示取消与超时：创建可取消任务，触发超时映射。
 使用示例：
   CancelDemoView()
*/
import SwiftUI
import LWToolKit
import Alamofire

struct SlowEndpoint: LWEndpoint {
    let baseURL: URL
    var path: String { "/v1/slow" }
    var method: HTTPMethod { .get }
    var task: LWTask { .requestPlain }
    var requiresAuth: Bool { false }
}

public struct CancelDemoView: View {
    @State private var text = "Tap to start long request"
    @State private var task: Task<Void, Never>? = nil
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Button("开始长请求") {
                task?.cancel()
                task = Task { await longFetch() }
            }
            Button("取消当前请求") { task?.cancel() }
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("取消 / 超时")
    }
    private func longFetch() async {
        do {
            let ep = SlowEndpoint(baseURL: AppEnvironment.current.baseURL)
            // 这里复用 User 模型，仅为示例；真实项目可替换为对应模型
            let _: User = try await AppNetwork.shared.client.request(ep)
            text = "✅ 完成"
        } catch {
            // 使用你的统一错误映射
            let e = AppNetworkError.from(error)
            text = "❌ " + e.userMessage
        }
    }
}
