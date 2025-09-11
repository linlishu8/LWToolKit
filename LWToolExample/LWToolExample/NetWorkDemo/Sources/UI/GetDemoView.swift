
/*
 作用：演示 GET 请求、解码与错误映射；同时展示主线程 UI 更新与日志。
 使用示例：
   GetDemoView() 放入任意页面导航即可。
*/
import SwiftUI
import LWToolKit

public struct GetDemoView: View {
    @State private var output = "Tap to GET /v1/users/42"
    public init() {}
    public var body: some View {
        VStack(spacing: 16) {
            ScrollView { Text(output).frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.secondarySystemBackground)).cornerRadius(12) }
            Button("GET user 42") { Task { await run() } }
        }.padding()
    }
    private func run() async {
        do {
            let ep = GetUserEndpoint(baseURL: AppEnvironment.current.baseURL, id: "42")
            let user: User = try await AppNetwork.shared.client.request(ep)
            output = "✅ \(user.id) - \(user.name)"
        } catch {
            let e = AppNetworkError.from(error)
            output = "❌ \(e.userMessage)"
        }
    }
}
