/* 
  作用：一键 Bootstrap，持有 LWAlamofireClient。
*/
import Foundation
import Alamofire
import LWToolKit

public final class TestAppNetwork {
    public static let shared = TestAppNetwork()
    private init() {}
    public private(set) var baseURLString: String = "https://api.example.com"
    public private(set) var client: LWAlamofireClient!
    @discardableResult
    public func bootstrap(_ p: AppEZConfig.Params) -> LWAlamofireClient {
        self.baseURLString = p.baseURL
        var cfg = LWNetworkConfig()
        cfg.retryLimit = p.retryLimit
        cfg.timeout = p.requestTimeout
        cfg.cacheTTL = p.cacheTTL
        cfg.requestHeaders = p.defaultHeaders
        cfg.useETagCaching = true
        cfg.middlewares = p.middlewares
        if p.enablePinning {
            do {
                let sets = try LWPinningProvider.loadLocalConfig(name: "pinning", ext: "json", in: .main)
                if !sets.isEmpty {
                    var pins: [String: [Data]] = [:]
                    for (domain, set) in sets {
                        pins[domain] = set.primary + set.backup
                    }
                    cfg.enablePinning = true
                    cfg.pinnedDomains = pins
                    cfg.pinningSets  = sets      
                } else {
                    print("[TestAppNetwork] ⚠️ pinning.json not found or empty; pinning disabled.")
                }
            } catch {
                print("[TestAppNetwork] ⚠️ Pinning load error: \(error)")
            }
        }
        var opts = LWLogOptions()
        opts.enabled = true               // 开关
        opts.logHeaders = false           // 打印请求头（默认 false）
        opts.logCURL = true               // 输出 cURL
        opts.sampleRate = p.logSampling   // 采样率 0...1
        opts.bodyPreviewBytes = 0         // 响应体预览字节数；>0 开启
        opts.redactHeaders = Set(p.redactedHeaders) // 需要脱敏的请求头 Key
        
        let logger = LWAFLogger(options: opts)
        let interceptor = p.interceptor ?? LWAuthInterceptor()
        let c = LWAlamofireClient(config: cfg, interceptor: interceptor, monitors: [logger])
        self.client = c
        return c
    }
}
