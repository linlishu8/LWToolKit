
# LWNetworkDemos-UIKit （用于 LWToolExample）

这是 **UIKit / ViewController** 版本的 LWNetwork 功能演示集合。  
将 `LWNetworkDemos-UIKit/` 整个文件夹拖入 **LWToolExample**（勾选 *Copy items if needed*），
然后从你工程里的任意地方 `push` 或设为 `rootViewController = DemoHomeViewController()` 即可看到所有 Demo 列表。

> 目标 iOS 13+，纯代码（无 Storyboard）。建议在 Pod 中包含：
> ```ruby
> pod 'Alamofire'
> pod 'LWToolKit/LWNetwork'
> pod 'SnapKit'
> ```

## 覆盖能力
- HTTP 基础：GET / POST / Headers / Query / JSON 解码 / Void 请求
- 下载 / 上传（multipart）
- ETag / 缓存命中演示
- 5xx 重试（令牌桶 / 断路器占位）
- 401 刷新（拦截器配置指引）
- 离线队列（示例思路）
- SSE（本地模拟）
- WebSocket（本地模拟 & 回声思路）

> 演示所用测试服务：https://httpbingo.org  
> 若受 ATS 限制，请在 `Info.plist` 为该域名添加例外，或改用你们的调试域名。

## 使用
```swift
// 方式一：作为入口
window?.rootViewController = UINavigationController(rootViewController: DemoHomeViewController())

// 方式二：从现有页面进入
navigationController?.pushViewController(DemoHomeViewController(), animated: true)
```
