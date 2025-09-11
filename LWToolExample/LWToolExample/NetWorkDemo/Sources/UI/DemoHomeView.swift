
/*
 作用：Demo 总入口，罗列所有网络场景；SwiftUI 版本，便于集成到现有 App（也提供 UIKit 容器）。
 使用示例：
   SwiftUI：NavigationStack { DemoHomeView() }
   UIKit：push DemoHomeViewController()
*/
import SwiftUI

public struct DemoHomeView: View {
    public init() {}
    public var body: some View {
        List {
            Section(header: Text("基础请求")) {
                NavigationLink("GET 基本请求 / 解码 / 错误映射", destination: GetDemoView())
                NavigationLink("POST JSON / 幂等键 / 离线队列占位", destination: PostDemoView())
                NavigationLink("分页（page/pageSize）", destination: PaginationDemoView())
                NavigationLink("缓存 / ETag / 304", destination: CacheDemoView())
            }
            Section(header: Text("鉴权 & 异常")) {
                NavigationLink("需要鉴权（requiresAuth）/ 401 刷新", destination: AuthDemoView())
                NavigationLink("错误分支（403/404/429/5xx 重试）", destination: ErrorsDemoView())
                NavigationLink("取消 / 超时", destination: CancelDemoView())
            }
            Section(header: Text("性能 & 可靠性")) {
                NavigationLink("请求并发合并（Coalescing）", destination: CoalescingDemoView())
                NavigationLink("限流 / 断路器 触发与恢复", destination: LimitBreakerDemoView())
            }
            Section(header: Text("传输")) {
                NavigationLink("上传（multipart/fileURL）", destination: UploadDemoView())
                NavigationLink("下载（后台/断点续传）", destination: DownloadDemoView())
            }
            Section(header: Text("实时")) {
                NavigationLink("SSE / WebSocket", destination: SSEWebSocketDemoView())
            }
        }
        .navigationTitle("LWNetwork 场景演示")
    }
}

