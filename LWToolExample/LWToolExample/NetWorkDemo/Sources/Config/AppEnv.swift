import Foundation

/// 预置的三种环境；如需更多可自行扩展。
public enum AppEnv: String, CaseIterable, Codable {
    case dev
    case staging
    case prod

    /// 当前环境的 API 域名（请替换为你的真实域名）
    public var baseURL: String {
        switch self {
        case .dev:     return "https://api-dev.example.com"
        case .staging: return "https://api-staging.example.com"
        case .prod:    return "https://api.example.com"
        }
    }

    /// 是否启用证书锁定（通常 Dev 关、Staging/Prod 开）
    public var enablePinning: Bool {
        switch self {
        case .dev: return false
        case .staging, .prod: return true
        }
    }

    /// 日志采样率（可按环境差异化）
    public var logSampling: Double {
        switch self {
        case .dev: return 1.0
        case .staging: return 0.5
        case .prod: return 0.1
        }
    }

    /// 额外公共头（例如标记当前环境）
    public var extraHeaders: [String: String] {
        ["X-Env": rawValue]
    }
}
