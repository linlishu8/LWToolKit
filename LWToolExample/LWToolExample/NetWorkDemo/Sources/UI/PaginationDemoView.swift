
/*
 作用：演示分页拉取（page/pageSize），滚动触底继续加载，失败与空态提示。
 使用示例：
   PaginationDemoView()
*/
import SwiftUI
import LWToolKit

public struct PaginationDemoView: View {
    @State private var items: [FeedItem] = []
    @State private var page = 1
    @State private var loading = false
    @State private var hasMore = true

    public init() {}

    public var body: some View {
        List {
            ForEach(items) { it in
                Text("\(it.id) · \(it.title)")
            }

            if loading {
                ProgressView().frame(maxWidth: .infinity)
            } else if hasMore {
                Button("加载更多") {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity)
            } else {
                // iOS 14 回退到 foregroundColor
                Group {
                    if #available(iOS 15.0, *) {
                        Text("—— 已无更多 ——")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—— 已无更多 ——")
                            .foregroundColor(Color.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("分页")
        // iOS 14 兼容：用 onAppear 启动首批加载；iOS 15+ 可换成 .task
        .onAppear {
            if items.isEmpty {
                Task { await loadMore() }
            }
        }
    }

    private func loadMore() async {
        guard !loading, hasMore else { return }
        loading = true
        defer { loading = false }
        do {
            let ep = FeedListEndpoint(baseURL: AppEnvironment.current.baseURL, page: page, pageSize: 10)
            let pageResp: FeedPage = try await AppNetwork.shared.client.request(ep)
            items.append(contentsOf: pageResp.items)
            hasMore = pageResp.hasMore
            if hasMore { page += 1 }
        } catch {
            let e = AppNetworkError.from(error)
            toast("加载失败：" + e.userMessage)
        }
    }
}
