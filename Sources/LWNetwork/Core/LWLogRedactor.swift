//
//  LWLogRedactor.swift
//  LWToolKit
//
//  Created by June on 2025/9/9.
//

import Foundation

/**
 LWLogRedactor
 -------------
 作用：
 提供日志脱敏与体预览工具：
 - 头部脱敏（大小写不敏感）
 - JSON 体脱敏（递归处理字典/数组），并友好美化输出
 - 非 JSON 体按字节截断后直接输出 UTF-8 文本（失败则输出占位）

 使用示例：
 ```swift
 let safeHeaders = LWLogRedactor.headers(headers, redact: ["authorization"])
 let preview = LWLogRedactor.bodyPreview(data, limit: 1024, redactKeys: ["password"])
 ```
 */
public enum LWLogRedactor {

    /// 头部脱敏：命中键的值将替换为 `******`
    public static func headers(_ headers: [String: String], redact: Set<String>) -> [String: String] {
        guard !headers.isEmpty else { return headers }
        let redacts = Set(redact.map { $0.lowercased() })
        var out: [String: String] = [:]
        for (k, v) in headers {
            if redacts.contains(k.lowercased()) {
                out[k] = "******"
            } else {
                out[k] = v
            }
        }
        return out
    }

    /// 响应体预览（可选 JSON 脱敏）。limit 为最大字符数（近似字节控制）。
    public static func bodyPreview(_ data: Data?,
                                   limit: Int,
                                   redactKeys: Set<String>) -> String? {
        guard let data = data, !data.isEmpty else { return nil }
        let limit = max(0, limit)
        // 尝试当 JSON 处理
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let redacted = redactJSON(jsonObject, keys: Set(redactKeys.map { $0.lowercased() })) {
            if let pretty = try? JSONSerialization.data(withJSONObject: redacted, options: [.prettyPrinted]),
               var s = String(data: pretty, encoding: .utf8) {
                if limit > 0, s.count > limit {
                    let idx = s.index(s.startIndex, offsetBy: limit)
                    s = String(s[..<idx]) + " …(truncated)"
                }
                return s
            }
        }
        #if canImport(Foundation)
        // 退化为纯文本输出
        #endif
        if limit > 0 {
            let slice = data.prefix(limit)
            if var s = String(data: slice, encoding: .utf8) {
                if data.count > slice.count { s += " …(truncated)" }
                return s
            }
        } else if let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "<\(data.count) bytes binary>"
    }

    // MARK: - JSON 脱敏

    /// 递归脱敏 JSON 对象
    private static func redactJSON(_ obj: Any, keys: Set<String>) -> Any? {
        switch obj {
        case let dict as [String: Any]:
            var out: [String: Any] = [:]
            for (k, v) in dict {
                if keys.contains(k.lowercased()) {
                    out[k] = "******"
                } else {
                    out[k] = redactJSON(v, keys: keys) ?? v
                }
            }
            return out
        case let arr as [Any]:
            return arr.map { redactJSON($0, keys: keys) ?? $0 }
        default:
            return obj
        }
    }
}

