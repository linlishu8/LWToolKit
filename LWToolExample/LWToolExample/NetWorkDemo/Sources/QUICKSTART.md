# Quick Start（基于最新代码）

> 目标：5 分钟把网络层跑起来，并覆盖“多环境切换 / 鉴权请求 / 业务包裹自动解包 / 并发与串行 / 统一错误呈现”。

## 1) 启动初始化（推荐使用环境管理器）

```swift
import AppNetworkEZ

// 读取默认环境（Info.plist 的 APP_ENV > 上次选择 > .prod），并完成网络层 Bootstrap
AppEnvironment.shared.activateAtLaunch()

// （可选）注入错误呈现器 —— 由你的 UI 决定是 Toast 还是 Alert
final class MyPresenter: ErrorPresenter {
  func present(_ e: AppError) {
    // showToast / showAlert / 埋点...
  }
}
AppErrorRouter.setup(MyPresenter())
```

> 如需手动初始化也可继续：  
> `AppNetwork.shared.bootstrap(AppEZConfig.Params(baseURL: "https://api.example.com"))`

## 2) （可选）调试环境切换面板

```swift
#if DEBUG
EnvSwitcherView()   // SwiftUI 里直接放到调试菜单
#endif
```

## 3) 语义化调用（鉴权 GET）

```swift
struct Profile: Decodable { let id: String; let name: String }
let profile: Profile = try await Net.request(.get("/v1/profile", auth: .required))
```

## 4) 业务包裹自动解包（{code,message,data}）

```swift
let p2: Profile = try await AppAPI.getE("/v1/profile", auth: true)
```

## 5) 并发访问多个接口

```swift
struct Flags: Decodable { let features: [String: Bool] }
let (p, f): (Profile, Flags) = try await AppAPI.zip2(
  EZEndpoint(path:"/v1/profile", method:.get, requiresAuth:true, task:.requestPlain),
  EZEndpoint(path:"/v1/flags",   method:.get, requiresAuth:true, task:.requestPlain),
  as:(Profile.self, Flags.self)
)
```

## 6) 串行编排（登录三步）

```swift
let _ = try await AppAPI.loginPipeline(username: "demo", password: "pass")
// 获取住户ID → 登录 → 换 Token（成功后由拦截器负责后续鉴权）
```

## 7) 统一错误呈现（Toast / Alert / 静默）

```swift
// 已在 AppErrorRouter.setup(...) 注入 Presenter
// 调用处只需正常 try/await；错误会被路由到 Presenter
let me: Profile = try await Net.request(.get("/v1/profile", auth: .required))
```

## 8) 401 自动刷新后继续请求
- 对 `requiresAuth = true` 的端点，`LWAuthInterceptor` 自动注入 `Authorization`；  
- 若返回 401，将**刷新 Token 并重放原请求**；刷新失败才会上抛 `AppError.unauthorized`（由 UI 跳登录）。

## 9) 上传 / 下载

```swift
// 上传
struct UploadResp: Decodable { let id: String }
let parts: [LWMultipartFormData] = [
  LWMultipartFormData(name: "file", fileURL: localURL, fileName: "a.png", mimeType: "image/png")
]
let resp: UploadResp = try await AppAPI.upload("/v1/upload", auth: true, parts: parts)

// 下载
try await AppAPI.download("/v1/file", auth: true) { tmp, _ in
  let dest = FileManager.default.temporaryDirectory.appendingPathComponent("file.bin")
  return (dest, [.removePreviousFile, .createIntermediateDirectories])
}
```

## 10) 多环境 & Pinning
- 环境：`AppEnv.swift` 配置 `dev/staging/prod` 的 `baseURL / enablePinning / logSampling / X-Env`。  
- Pinning：在 `pinning.json` 列出各环境域名；通常 **Dev 关 / Staging、Prod 开**。  
