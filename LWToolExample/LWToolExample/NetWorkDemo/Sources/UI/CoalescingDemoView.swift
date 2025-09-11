
/*
 作用：演示请求并发合并（Coalescing）：并发触发相同端点，底层合并一次网络请求。
 使用示例：
   CoalescingDemoView()
*/
import SwiftUI
import LWToolKit

public struct CoalescingDemoView: View {
    @State private var out = "Tap to start 10 concurrent GETs"
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Button("并发触发 10 次相同 GET") { Task { await run() } }
            ScrollView {
                Text(out)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("Coalescing")
    }
    private func run() async {
        await withTaskGroup(of: String.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        let ep = GetUserEndpoint(baseURL: AppEnvironment.current.baseURL, id: "42")
                        let u: User = try await AppNetwork.shared.client.request(ep)
                        return "✅ \(u.name)"
                    } catch {
                        return "❌ " + String(describing: error)
                    }
                }
            }
            var lines: [String] = []
            for await s in group { lines.append(s) }
            out = lines.joined(separator: "\n")
        }
    }
}
