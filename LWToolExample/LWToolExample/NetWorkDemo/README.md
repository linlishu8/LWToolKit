
# LWNetwork 全量场景 Demo（可直接集成到现有 App）

> **LWNetwork**：`LWAlamofireClient`、`LWAPI`、`LWTask`、`LWEnvironment`、`LWAuthInterceptor`、中间件链、SSE/WebSocket、证书锁定等。
> 每个 Swift 文件顶部均有中文注释块（包含【作用】【使用示例】），便于拷贝即用。

## 包含场景（覆盖常见分支）
- 成功 / 解码错误 / 传输错误 / 超时 / 取消
- 401 自动刷新（成功/失败），403/404/409/422/429/5xx 等状态码处理
- 指数退避重试、请求并发合并（coalescing）
- ETag / 304 Not Modified，内存 TTL 缓存 命中/未命中
- 公共/鉴权接口（`requiresAuth`）自动加 Token & `X-Session-Id`
- 分页（cursor/offset），查询参数拼接
- 上传（multipart/fileURL）、下载（含后台/断点续传）与进度监听
- 离线队列（写操作落盘排队，网络恢复后重放）
- 令牌桶限流（触发/恢复），断路器（打开/半开/关闭）
- 证书锁定（pinning.json），失败回退与提示
- SSE（Server-Sent Events）与 WebSocket（自动重连/心跳）
- 自定义错误映射与统一提示

## 结构
- `Sources/Networking/`：装配、环境、端点、错误映射、工具
- `Sources/UI/`：每个场景一个 SwiftUI Demo 页面 + 总入口 `DemoHomeView`
- `Sources/Hosting/`：`DemoHomeViewController`（便于 UIKit 工程 push）
- `Resources/pinning.json`：证书锁定模板

## 使用方式
1. 先把 **LWNetwork**（以及 Alamofire）接入（SPM 或 CocoaPods）。
2. 将本 Demo 的 `Sources`、`Resources` 拖入你的 App Target（勾选 *Copy items if needed*）。
3. 在 `APIEnvironment.swift` 中替换你的 Dev/Staging/Prod 域名。
4. 运行 `DemoHomeView`（SwiftUI）或 `DemoHomeViewController`（UIKit）即可。

> 注意：请求头一律使用 `HTTPHeaders`；有鉴权的端点把 `requiresAuth = true`，交由拦截器自动处理。

