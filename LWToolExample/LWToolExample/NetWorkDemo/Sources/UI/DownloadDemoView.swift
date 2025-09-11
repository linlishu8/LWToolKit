
/*
 作用：演示下载（可扩展为后台/断点续传）。
 使用示例：
   DownloadDemoView()
*/
import SwiftUI
import LWToolKit

public struct DownloadDemoView: View {
    @State private var result = "Tap to download"
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            // 按钮样式兼容处理
            if #available(iOS 15.0, *) {
                Button("下载测试文件") { Task { await start() } }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("下载测试文件") { Task { await start() } }
            }

            // 文本前景样式兼容处理
            Group {
                if #available(iOS 17.0, *) {
                    Text(result).font(.footnote).foregroundStyle(.secondary)
                } else {
                    Text(result).font(.footnote).foregroundColor(Color.secondary)
                }
            }
        }
        .padding()
        .navigationTitle("下载")
    }

    private func start() async {
        do {
            let ep = DownloadFileEndpoint(baseURL: AppEnvironment.current.baseURL, path: "/files/big.bin")
            let fileURL: URL = try await AppNetwork.shared.client.download(ep)
            result = "✅ 下载完成：\(fileURL.lastPathComponent)\n保存到：\(fileURL.path)"
        } catch {
            result = "❌ " + AppNetworkError.from(error).userMessage
        }
    }
}
