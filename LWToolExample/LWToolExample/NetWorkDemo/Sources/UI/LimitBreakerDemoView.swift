
/*
 作用：演示令牌桶/断路器：快速触发大量请求，观察底层限流与断路器状态（以日志/错误表现）。
 使用示例：
   LimitBreakerDemoView()
*/
import SwiftUI
import LWToolKit

public struct LimitBreakerDemoView: View {
    @State private var out = "Tap to burst requests"
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            Button("突发 50 次请求") { Task { await burst() } }
            ScrollView {
                Text(out)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
        .padding()
        .navigationTitle("限流 / 断路器")
    }

    private func burst() async {
        await withTaskGroup(of: String.self) { group in
            for i in 0..<50 {
                group.addTask {
                    do {
                        let ep = GetUserEndpoint(baseURL: AppEnvironment.current.baseURL, id: "\(i)")
                        let _: User = try await AppNetwork.shared.client.request(ep)
                        return "✅ \(i)"
                    } catch {
                        return "❌ \(i) " + String(describing: error)
                    }
                }
            }
            var lines: [String] = []
            for await s in group { lines.append(s) }
            out = lines.joined(separator: ", ")
        }
    }
}
