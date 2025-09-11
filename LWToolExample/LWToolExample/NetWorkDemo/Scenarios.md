
# 场景与分支清单（对照 UI 页面）

- 成功：GetDemo、PostDemo、PaginationDemo、UploadDemo、DownloadDemo、AuthDemo（token 有效）
- 解码错误：GetDemo（服务器返回结构变化）→ 映射为 `.decode`
- 传输错误：断网/域名错误 → `.unreachable`
- 超时：CancelDemo（长请求触发超时）→ `.timeout`
- 取消：CancelDemo（用户点击“取消”）→ `.cancelled`
- 401：AuthDemo（token 过期）→ 自动刷新并重试，刷新失败 → `.notAuthenticated`
- 403：ErrorsDemo → `.forbidden`
- 404：ErrorsDemo → `.notFound`
- 409：可在 PostDemo 提交同一资源复现 → `.conflict`
- 422：服务器返回校验失败 → `.validation("xxx")`
- 429：ErrorsDemo（带退避重试）→ `.rateLimited(retryAfter)`
- 5xx：ErrorsDemo（带退避重试）→ `.server`
- ETag/缓存：CacheDemo（第二次命中内存缓存或 304）
- 并发合并：CoalescingDemo（10 次并发只打一网）
- 限流/断路器：LimitBreakerDemo（突发 50 次，观察错误/日志）
- 上传：UploadDemo（进度/失败重试）
- 下载：DownloadDemo（可扩展后台/断点续传）
- SSE/WS：SSEWebSocketDemo（连接、消息、错误、重连）
