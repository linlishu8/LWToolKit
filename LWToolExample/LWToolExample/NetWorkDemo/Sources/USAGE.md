# 使用方法（基于最新代码）

## 0. 多环境切换（新增能力）
- 配置环境：在 `AppEnv.swift` 填好各环境的域名与开关
  ```swift
  case .dev:     return "https://api-dev.example.com"
  case .staging: return "https://api-staging.example.com"
  case .prod:    return "https://api.example.com"
  ```
- 启动激活：
  ```swift
  AppEnvironment.shared.activateAtLaunch()
  ```
- 运行时切换（建议仅 Debug/TestFlight）：
  ```swift
  #if DEBUG
  AppEnvironment.shared.switch(to: .staging)
  #endif
  ```
- 自动行为：清 Token/Cookie/URLCache → 重新 Bootstrap → 发送通知 `appEnvDidChange`；请求头自动加 `X-Env`。

---

## 1. 可配置参数（集中在 `AppEZConfig.Params`）
- `baseURL`（必填）
- `retryLimit`（401/429/5xx 的指数退避最大次数）
- `requestTimeout`（请求超时秒数）
- `cacheTTL`（缓存 TTL，配合 ETag/缓存中间件）
- `enablePinning`（是否开启证书锁定，需提供 `pinning.json`）
- `logSampling`（日志采样率 0~1）
- `redactedHeaders`（敏感头脱敏清单）
- `defaultHeaders`（公共头：语言/App版本/设备系统/Accept）
- `middlewares`（可插拔中间件：遥测/缓存/验签/AB 等）
- `interceptor`（拦截器；默认 `LWAuthInterceptor`）
- **（配合环境）**：不同环境可有不同 `enablePinning`、`logSampling`、`X-Env` 头

**初始化：**
```swift
// 推荐
AppEnvironment.shared.activateAtLaunch()

// 或手动
AppNetwork.shared.bootstrap(
  AppEZConfig.Params(baseURL: "https://api.example.com")
)
```

---

## 2. 最少代码的请求方式

### 2.1 `Resource<T>` + `Net.request`（更语义）
```swift
struct Profile: Decodable { let id: String; let name: String }
let p: Profile = try await Net.request(.get("/v1/profile", auth: .required))
```
- `AuthRequirement`: `.required` / `.none`（替代布尔）  
- `RequestOptions`：`headers` / `idempotencyKey`（对可重试 POST 建议传入）

### 2.2 兼容旧方式（直接 `AppAPI.*`）
```swift
let p: Profile = try await AppAPI.get("/v1/profile", auth: true)
```

---

## 3. 业务包裹自动解包（*E 系列）
后端返回 `{ code, message, data }` 时，直接用 *E 版本方法：
```swift
let p: Profile = try await AppAPI.getE("/v1/profile", auth: true)
```
- `code != 0` → 抛 `AppError.business(code,message)`（被 `AppErrorRouter` 路由到 Presenter）

---

## 4. 多接口（并发/串行）

### 并发：`zip2/zip3`
```swift
struct Flags: Decodable { let features: [String: Bool] }
let (p, f): (Profile, Flags) = try await AppAPI.zip2(
  EZEndpoint(path:"/v1/profile", method:.get, requiresAuth:true, task:.requestPlain),
  EZEndpoint(path:"/v1/flags",   method:.get, requiresAuth:true, task:.requestPlain),
  as:(Profile.self, Flags.self)
)
```

### 串行：登录三步 `loginPipeline`
```swift
let token = try await AppAPI.loginPipeline(username: "user", password: "pass")
// 获取住户ID → 登录 → 换 Token（成功后交由拦截器处理鉴权）
```
> 可选：`Flow.sequence([step1, step2, ...])` 做更复杂的串行管线。

---

## 5. 401 自动刷新并重放
- `requiresAuth = true` 的请求会自动带 `Authorization`  
- 401 → 刷新 Token 成功后**重放原请求**；刷新失败才会上抛 `AppError.unauthorized`（UI 跳登录）  
- 建议 Token 使用 **Keychain** 持久化；`TokenStore` 示例可替换

---

## 6. 统一错误呈现（解耦）
```swift
final class MyPresenter: ErrorPresenter {
  func present(_ error: AppError) {
    switch error {
    case .business(_, let msg):  /* showToast(msg) */
    case .unauthorized:          /* showAlert("登录失效") -> 去登录 */
    case .http(let code, _):     /* showToast("网络错误 \(code)") */
    case .decoding:              /* showToast("解析失败") */
    case .network:               /* showToast("网络异常") */
    case .unknown:               /* showToast("未知错误") */
    }
  }
}
AppErrorRouter.setup(MyPresenter())
```

---

## 7. 上传 / 下载
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

---

## 8. Pinning（可选，建议在 Staging/Prod 开）
- 在 `pinning.json` 中为各域名配置 SPKI-SHA256 pins；  
- `AppEnv.enablePinning` 控制是否启用；  
- 灰度开启，配合 `pinning_fail` 失败打点和回滚开关。

---

## 9. FAQ
- **401 循环？** 刷新失败要清 Token 并引导登录；检查服务端刷新接口是否可用。  
- **解析失败？** 先用 `getE` 确认是否业务错误；再检查 `JSONCoders` 与后端日期/字段。  
- **POST 可重试？** 给 `RequestOptions(idempotencyKey: UUID().uuidString)`，配合服务端幂等处理。  
- **切换环境后仍命中缓存？** 切换已自动清理 URLCache；若使用第三方磁盘缓存，记得同时清理。  
