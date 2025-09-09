import Foundation

/**
 LWURLCache
 ----------------
 作用：
 一个**轻量的 URLCache 配置门面**。用于快速设置全局 `URLCache.shared` 的内存/磁盘容量，
 或将缓存挂到指定的 `URLSessionConfiguration` 上；同时提供清理与用量查询的便捷方法。

 使用示例：
 ```swift
 // 1) 全局配置（建议在 App 启动时调用）
 LWURLCache.configure(memoryMB: 64, diskMB: 256)  // 默认 64 / 256 MB

 // 2) 挂到自定义的 URLSession（不影响全局 shared）
 let cfg = URLSessionConfiguration.default
 LWURLCache.attach(to: cfg, memoryMB: 32, diskMB: 128, diskPath: "my.cache")
 let session = URLSession(configuration: cfg)

 // 3) 清理与查看用量
 LWURLCache.clearAll()
 let usage = LWURLCache.currentUsage()
 print("memory=\(usage.memory)B disk=\(usage.disk)B")
 ```

 注意事项：
 - `diskPath` 为磁盘缓存目录的子路径标识；同一标识会复用同一缓存目录。
 - 若你的应用需要严格控制离线缓存大小，建议根据产品需求调小 `diskMB`。
 - `URLCache` 的生效还受请求的 `Cache-Control` / `ETag` / `If-None-Match` 等头部影响。
 */
public enum LWURLCache {

    /// 配置全局共享的 URL 缓存（URLCache.shared）
    public static func configure(memoryMB: Int = 64,
                                 diskMB: Int = 256,
                                 diskPath: String = "lw.urlcache") {
        let mem = max(0, memoryMB) * 1024 * 1024
        let disk = max(0, diskMB) * 1024 * 1024
        URLCache.shared = URLCache(memoryCapacity: mem, diskCapacity: disk, diskPath: diskPath)
    }

    /// 将缓存挂到指定的 URLSessionConfiguration 上（不影响全局 shared）
    public static func attach(to configuration: URLSessionConfiguration,
                              memoryMB: Int = 32,
                              diskMB: Int = 128,
                              diskPath: String = "lw.urlcache.session") {
        let mem = max(0, memoryMB) * 1024 * 1024
        let disk = max(0, diskMB) * 1024 * 1024
        configuration.urlCache = URLCache(memoryCapacity: mem, diskCapacity: disk, diskPath: diskPath)
        // 默认策略即可；如需强制缓存可按需修改：configuration.requestCachePolicy = .returnCacheDataElseLoad
    }

    /// 清空当前全局缓存（内存 + 磁盘）
    public static func clearAll() {
        URLCache.shared.removeAllCachedResponses()
    }

    /// 当前全局缓存用量（字节数）
    public static func currentUsage() -> (memory: Int, disk: Int) {
        (URLCache.shared.currentMemoryUsage, URLCache.shared.currentDiskUsage)
    }
}
