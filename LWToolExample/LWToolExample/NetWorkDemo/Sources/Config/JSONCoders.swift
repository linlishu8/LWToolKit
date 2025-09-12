import Foundation

/// 集中管理 JSON 编解码策略，避免在各处重复配置。
public enum JSONCoders {
    /// 统一解码器（默认 ISO8601 日期）
    public static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .useDefaultKeys
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// 统一编码器（默认 ISO8601 日期）
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .useDefaultKeys
        e.dateEncodingStrategy = .iso8601
        return e
    }
}
