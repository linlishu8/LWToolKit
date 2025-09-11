
/*
 作用：演示 POST JSON、幂等键、（可扩展）离线队列；失败时提示领域错误。
 使用示例：
   PostDemoView()
*/
import SwiftUI
import Alamofire
import LWToolKit

public struct PostDemoView: View {
    @State private var name: String = "Andy"
    @State private var result: String = "准备提交 /v1/me"
    public init() {}
    public var body: some View {
        Form {
            TextField("新昵称", text: $name)
            Button("提交修改昵称") { Task { await submit() } }

            // Section 标题兼容处理
            if #available(iOS 15.0, *) {
                Section("Result") {
                    resultView
                }
            } else {
                Section(header: Text("Result")) {
                    resultView
                }
            }
        }
        .navigationTitle("POST JSON")
    }

    // 结果展示复用，内部做前景样式兼容
    @ViewBuilder private var resultView: some View {
        if #available(iOS 17.0, *) {
            Text(result).font(.footnote).foregroundStyle(.secondary)
        } else {
            Text(result).font(.footnote).foregroundColor(Color.secondary)
        }
    }

    private func submit() async {
        do {
            let ep = UpdateProfileEndpoint(baseURL: AppEnvironment.current.baseURL, name: name)
            struct Ack: Codable { let ok: Bool }
            let ack: Ack = try await AppNetwork.shared.client.request(ep)
            result = ack.ok ? "✅ 修改成功" : "❌ 服务未确认"
        } catch {
            result = "❌ " + AppNetworkError.from(error).userMessage
        }
    }
}
