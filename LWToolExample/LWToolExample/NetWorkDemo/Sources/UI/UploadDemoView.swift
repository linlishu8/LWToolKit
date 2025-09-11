
/*
 作用：演示 multipart 上传与进度（假定库支持进度回调/通知）。
 使用示例：
   UploadDemoView()
*/
import SwiftUI
import LWToolKit

public struct UploadDemoView: View {
    @State private var progress: Double = 0
    @State private var result = "选择文件后上传"
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: progress).padding(.horizontal)
            Button("模拟上传头像") { Task { await upload() } }
            Text(result).font(.footnote)
        }.padding().navigationTitle("上传")
    }
    private func upload() async {
        do {
            let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("avatar.bin")
            try? Data(repeating: 0xAB, count: 512_000).write(to: tmp)
            let ep = UploadAvatarEndpoint(baseURL: AppEnvironment.current.baseURL, fileURL: tmp)
            struct Ack: Codable { let ok: Bool }
            let ack: Ack = try await AppNetwork.shared.client.request(ep)
            result = ack.ok ? "✅ 上传成功" : "❌ 失败"
        } catch { result = "❌ " + AppNetworkError.from(error).userMessage }
    }
}
