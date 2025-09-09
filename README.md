# LWToolKit

A modular toolbox for iOS apps with **Core**, **Media**, **UI**, and **Analytics** building blocks.

## Modules
- **LWCore**: debouncer, throttler, rate limiter, task queue with retries, reachability, keychain, memory/disk cache helpers, feature flags, A/B test, errors, localization, privacy & update check, deep link router, performance metrics, notifications.
- **LWMedia**: image loader & media/document pickers.
- **LWUI**: SwiftUI toast & alert helpers.
- **LWAnalytics**: logger & event tracker.

## Requirements
- iOS 14+
- Swift 5.9+

## Usage (SPM)
Add the package and select the products you need:
```swift
import LWCore
import LWMedia
import LWUI
import LWAnalytics
```

See `LWToolExample` for runnable demos.

LWCore（基础能力）

防抖 / 节流 / 限流

LWDebouncer：主线程防抖

LWThrottler：节流器

LWRateLimiter：滑动时间窗口限流

网络可达性：LWReachability（基于 NWPathMonitor）

Keychain 封装：LWKeychain（字符串 / Data / Codable 读写、Access Group、Accessible 选项）

缓存

LWMemoryCache：线程安全内存缓存（可 TTL）

LWURLCache：URLCache 快速配置与清理

持久化抽象：LWPersistence 协议 + InMemoryPersistence 示例

深链路由：LWDeepLinkRouter（按 host 分发、线程安全）

本地化门面：LWLocalization（统一入口、stringsdict 复数、运行时语言覆盖）

通知与推送：LWNotifications（权限申请、APNs 注册、角标管理）

隐私与追踪授权：LWPrivacyConsent（ATT 请求、IDFA 读取、跳转设置）

应用更新检查：LWAppUpdateChecker（App Store Lookup，普通/强更判断）

A/B 实验与特性开关

LWABTest：轻量分桶（支持 seed 稳定分桶）

LWFeatureFlags：特性开关 / 远端配置 + 调试 override

性能计时：LWPerfMetrics（mark/measure/begin/end/time）

重试策略：LWRetryPolicy（指数退避 + 抖动）

统一错误模型与映射

LWError：network / business 两类

LWErrorMapper：从 (HTTP code, data) 宽容解析 {code,message}

崩溃上报门面：LWCrashReporter（可挂接 Crashlytics / Sentry 等）

LWUI（常用 UI 组件，SwiftUI）

Toast：LWToast（位置/时长/动画、ViewModifier 绑定 String?）

Alert 模型：LWAlertItem + View.lwAlert(...)（支持从 Error 便捷构造）

LWMedia（媒体与选择器）

图片加载器：LWImageLoader（异步加载、内存缓存、降采样、可取消）

图片选择器：LWImagePicker（PHPicker 的 SwiftUI 封装，数量/过滤）

文档选择器：LWDocumentPicker（UIDocumentPicker 的 SwiftUI 封装，类型/多选/拷贝）

LWAnalytics（日志与事件）

统一日志门面：LWLogger（iOS14+ 用 os.Logger，低版本回退 NSLog，分类扩展 Logger.lwNetwork）

事件分发器：LWEventTracker（多 sink 并发安全，适配第三方统计 SDK）

LWNetwork（基于 Alamofire 的可插拔网络层）

抽象与核心

LWNetworking 协议：request<T: Decodable> / requestVoid / download / upload

LWEndpoint、LWNetworkConfig、LWMiddleware、LWRequestCoalescer（同请求合并）

日志脱敏：LWLogRedactor、日志分类：Logger.lwNetwork

Alamofire 客户端：LWAlamofireClient（统一构建 URLRequest、中间件链、ETag 缓存、下载等）

拦截与会话

LWAuthInterceptor：自动加 Authorization/X-Session-Id、401 刷新与重试、429/5xx 退避

LWSessionManager、LWTokenStore

中间件示例

LWETagMiddleware：If-None-Match / ETag 协同 URLCache

LWCacheMiddleware：简易正文缓存（TTL）

LWTelemetryMiddleware：traceId、时延/状态码/字节数记录与通知

LWTokenBucketLimiter & LWCircuitBreaker：令牌桶限流与断路器标记

可靠性与场景扩展

离线任务队列：LWOfflineQueue（落盘、优先级、指数退避）

后台传输：LWBackgroundTransferClient

SSE：LWEventSource（自动重连、Last-Event-ID）

WebSocket：LWWebSocket

安全：LWPinningProvider（证书锁定）、LWNetKeychain

观测与日志

LWAFLogger（Alamofire 适配打印） + Logger+LWNetwork

聚合子规格

LWToolKit/All：一次性依赖 LWCore、LWUI、LWMedia、LWAnalytics、LWNetwork 全部能力。
