
/*
 作用：演示需要鉴权的端点（requiresAuth=true），自动加 Token 与 401 刷新/重试。
 使用示例：
   AuthDemoView()
*/
import SwiftUI
import LWToolKit

public struct AuthDemoView: View {
    @State private var output = "Tap to GET /v1/me"
    public init() {}
    public var body: some View {
        VStack(spacing: 16) {
            ScrollView { Text(output).frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.secondarySystemBackground)).cornerRadius(12) }
            Button("GET /v1/me（需要鉴权）") { Task { await run() } }
        }.padding().navigationTitle("鉴权与刷新")
    }
    private func run() async {
        do {
            let ep = MeEndpoint(baseURL: AppEnvironment.current.baseURL)
            let me: User = try await AppNetwork.shared.client.request(ep)
            output = "✅ \(me.id) - \(me.name)"
        } catch {
            let e = AppNetworkError.from(error)
            output = "❌ \(e.userMessage)"
        }
    }
}

