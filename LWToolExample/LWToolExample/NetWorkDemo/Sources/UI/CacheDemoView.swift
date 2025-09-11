
/*
 作用：演示 ETag/缓存：相同请求再次触发时命中 304 或内存缓存，UI 显示命中来源（伪示例）。
 使用示例：
   CacheDemoView()
*/
import SwiftUI

public struct CacheDemoView: View {
    @State private var text = "Tap to fetch (ETag/Cache)"
    public init() {}
    public var body: some View {
        VStack(spacing: 16) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            Button("请求一次") { Task { await fetch() } }
            Button("再次请求（期望命中缓存/304）") { Task { await fetch() } }
        }
        .padding()
        .navigationTitle("缓存 / ETag")
    }

    private func fetch() async {
        do {
            let ep = GetUserEndpoint(baseURL: AppEnvironment.current.baseURL, id: "42")
            let user: User = try await AppNetwork.shared.client.request(ep)
            text = "✅ 来自网络或缓存：\(user.name)"
        } catch {
            text = "❌ " + String(describing: error)
        }
    }
}

