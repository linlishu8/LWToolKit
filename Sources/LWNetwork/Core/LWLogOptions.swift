import Foundation

/**
 LWLogOptions
 -------------
 作用：
 配置网络日志打印的选项（开关、采样、脱敏、体预览等）。供 LWAFLogger/LWAlamofireClient 使用。

 使用示例：
 ```swift
 var opts = LWLogOptions()
 opts.enabled = true
 opts.logHeaders = true
 opts.bodyPreviewBytes = 1024
 opts.redactHeaders = ["authorization", "cookie"]
 opts.redactBodyKeys = ["password", "token"]

 let logger = LWAFLogger(options: opts)
 ```
 */
public struct LWLogOptions {
    /// 是否启用日志
    public var enabled: Bool
    /// 是否打印请求头（默认 false）
    public var logHeaders: Bool
    /// 是否输出 cURL（默认 false）
    public var logCURL: Bool
    /// 响应体预览字节数（0 表示不打印）
    public var bodyPreviewBytes: Int
    /// 需要脱敏的请求头键集合（不区分大小写）
    public var redactHeaders: Set<String>
    /// 需要脱敏的 JSON 键集合（不区分大小写）
    public var redactBodyKeys: Set<String>
    /// 采样率（0~1，默认 1）
    public var sampleRate: Double
    /// 预留：启用性能看板（此包未使用，供上层扩展）
    public var enableSignpost: Bool

    public init(
        enabled: Bool = true,
        logHeaders: Bool = false,
        logCURL: Bool = false,
        bodyPreviewBytes: Int = 0,
        redactHeaders: Set<String> = ["authorization", "cookie", "set-cookie"],
        redactBodyKeys: Set<String> = ["password", "token", "access_token", "refresh_token"],
        sampleRate: Double = 1.0,
        enableSignpost: Bool = false
    ) {
        self.enabled = enabled
        self.logHeaders = logHeaders
        self.logCURL = logCURL
        self.bodyPreviewBytes = max(0, bodyPreviewBytes)
        self.redactHeaders = Set(redactHeaders.map { $0.lowercased() })
        self.redactBodyKeys = Set(redactBodyKeys.map { $0.lowercased() })
        self.sampleRate = max(0, min(1, sampleRate))
        self.enableSignpost = enableSignpost
    }
}
