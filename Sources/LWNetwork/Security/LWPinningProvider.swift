import Foundation
import Alamofire

/**
 LWPinningSet / LWPinningSets / LWPinningProvider
 ------------------------------------------------
 作用：
 - **LWPinningSet**：描述某个域名的证书锁定集合（主证书 + 备份证书，DER 数据）。
 - **LWPinningProvider**：从 Bundle 中加载 `pinning.json`，并将其转换为
   Alamofire 可用的 `ServerTrustManager` / `ServerTrustEvaluating` 映射。

 `pinning.json` 文件格式示例（存放在 App target 的资源里）：
 ```json
 [
   {
     "domain": "api.example.com",
     "primary": [
       "MIID...AQAB",   // 证书 DER 的 Base64 编码
       "MIID...ABCD"
     ],
     "backup": [
       "MIIE...EFGH"
     ]
   },
   {
     "domain": "img.example.com",
     "primary": ["MIIE...WXYZ"],
     "backup": []
   }
 ]
 ```

 使用示例（配合 Alamofire）：
 ```swift
 // 1) 加载本地配置
 let sets = try LWPinningProvider.loadLocalConfig() // 默认加载 Bundle.main 中的 pinning.json

 // 2) 构造信任管理器，并交给 Alamofire.Session
 let trust = LWPinningProvider.trustManager(from: sets)
 let session = Session(serverTrustManager: trust)

 // 3) 交给你的客户端（如 LWAlamofireClient）使用该 Session
 // let client = LWAlamofireClient(config: cfg, interceptor: interceptor, monitors: [logger])
 // （在 LWAlamofireClient 中可以通过自定义 init 注入该 Session）
 ```

 注意事项：
 - 此方案为**证书锁定（Certificate Pinning）**：直接固定 DER 证书；若证书轮换，需及时更新并发版 App，
   或提前在 `backup` 中加入过渡证书。
 - 若你更倾向于**公钥锁定（Public Key Pinning）**，请自行改用 `PublicKeysTrustEvaluator`。
 - `loadLocalConfig` 若找不到文件将返回空集合 `[:]`（不抛错）；解析失败会抛出错误，便于在开发阶段尽早发现问题。
 */

// MARK: - Models

public struct LWPinningSet: Codable {
    public let domain: String
    public let primary: [Data] // DER
    public let backup: [Data]  // DER

    public init(domain: String, primary: [Data], backup: [Data]) {
        self.domain = domain
        self.primary = primary
        self.backup = backup
    }
}

public typealias LWPinningSets = [String: LWPinningSet]

// MARK: - Provider

public enum LWPinningProvider {

    /// 从 Bundle 中加载 pinning.json（DER Base64）
    /// - Parameters:
    ///   - name: 资源名（默认 "pinning"）
    ///   - ext: 扩展名（默认 "json"）
    ///   - bundle: 资源所在 Bundle（默认 .main）
    public static func loadLocalConfig(name: String = "pinning",
                                       ext: String = "json",
                                       in bundle: Bundle = .main) throws -> LWPinningSets {
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            return [:]
        }
        let decoder = JSONDecoder()
        decoder.dataDecodingStrategy = .base64
        let arr = try decoder.decode([LWPinningSet].self, from: data)
        var map: LWPinningSets = [:]
        for s in arr { map[s.domain] = s }
        return map
    }

    /// 将 PinningSets 转换为 Alamofire 的评估器字典（每个域名一个 PinnedCertificatesTrustEvaluator）
    /// - Parameters:
    ///   - sets: 证书锁定集合
    ///   - acceptSelfSignedCertificates: 是否接受自签名证书（默认 false）
    ///   - performDefaultValidation: 是否同时执行系统默认校验（推荐 true）
    ///   - validateHost: 是否校验主机名（推荐 true）
    public static func evaluators(from sets: LWPinningSets,
                                  acceptSelfSignedCertificates: Bool = false,
                                  performDefaultValidation: Bool = true,
                                  validateHost: Bool = true) -> [String: ServerTrustEvaluating] {
        var evaluators: [String: ServerTrustEvaluating] = [:]
        for (domain, set) in sets {
            let certs = certificates(from: set.primary + set.backup)
            let evaluator = PinnedCertificatesTrustEvaluator(
                certificates: certs,
                acceptSelfSignedCertificates: acceptSelfSignedCertificates,
                performDefaultValidation: performDefaultValidation,
                validateHost: validateHost
            )
            evaluators[domain] = evaluator
        }
        return evaluators
    }

    /// 基于 PinningSets 构造 ServerTrustManager
    public static func trustManager(from sets: LWPinningSets,
                                    acceptSelfSignedCertificates: Bool = false,
                                    performDefaultValidation: Bool = true,
                                    validateHost: Bool = true) -> ServerTrustManager {
        let evaluators = evaluators(from: sets,
                                    acceptSelfSignedCertificates: acceptSelfSignedCertificates,
                                    performDefaultValidation: performDefaultValidation,
                                    validateHost: validateHost)
        return ServerTrustManager(evaluators: evaluators)
    }

    /// 将 DER 数据数组转换为 SecCertificate 数组（无法解析的条目会被跳过）
    public static func certificates(from ders: [Data]) -> [SecCertificate] {
        ders.compactMap { SecCertificateCreateWithData(nil, $0 as CFData) }
    }
}
