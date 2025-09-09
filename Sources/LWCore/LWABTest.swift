import Foundation

/**
 LWABTest
 ----------------
 作用：
 一个**超轻量 A/B 实验分桶器**。对同一个 `key`（实验名），在本次进程内为用户挑选并缓存一个变体
（如 "A" / "B" / "C"），用于快速在业务代码里做 UI/流程分流。默认随机选择一次后缓存，
也提供**基于 seed 的可复现分桶**方法，便于按 `userId` 等稳定因子实现跨会话的一致性。

 使用示例：
 ```swift
 // 1) 随机分桶（进程生命周期内保持一致）
 let variant = LWABTest.shared.bucket(for: "paywall_layout", variants: ["A", "B", "C"])
 if variant == "A" {
     // 展示 A 版付费墙
 } else {
     // 展示 B/C 版
 }

 // 2) 基于稳定 seed（如 userId）进行可复现分桶（跨会话稳定）
 let userId = "u_12345"
 let v2 = LWABTest.shared.bucket(for: "onboarding_flow", variants: ["control", "new"], seed: userId)

 // 3) 强制指定某实验当前桶位（紧急回滚/灰度开关）
 LWABTest.shared.setBucket("A", for: "paywall_layout")

 // 4) 查询/重置
 _ = LWABTest.shared.currentBucket(for: "paywall_layout")
 LWABTest.shared.reset("paywall_layout")     // 只清一个
 LWABTest.shared.reset()                     // 清空全部
*/
public final class LWABTest {
    // MARK: - Singleton
    public static let shared = LWABTest()

    // MARK: - Storage
    private let queue = DispatchQueue(label: "lw.abtest.buckets")
    private var buckets: [String: String] = [:]

    // MARK: - Public API

    /// 随机分桶（进程内缓存）
    /// - Parameters:
    ///   - key: 实验键（如："paywall_layout"）
    ///   - variants: 备选变体（如：["A","B","C"]）
    /// - Returns: 选中的变体；当 `variants` 为空时回退为 "A"
    @discardableResult
    public func bucket(for key: String, variants: [String]) -> String {
        var result: String!
        queue.sync {
            if let cached = buckets[key] {
                result = cached
                return
            }
            let pick = variants.randomElement() ?? variants.first ?? "A"
            buckets[key] = pick
            result = pick
        }
        return result
    }

    /// 基于稳定 seed 的可复现分桶（跨会话稳定，推荐传 userId / deviceId）
    /// - Parameters:
    ///   - key: 实验键
    ///   - variants: 备选变体
    ///   - seed: 稳定因子（如 userId）。同一 `(key, seed)` 将稳定映射到同一变体
    /// - Returns: 选中的变体；当 `variants` 为空时回退为 "A"
    @discardableResult
    public func bucket(for key: String, variants: [String], seed: String) -> String {
        guard !variants.isEmpty else { return "A" }
        let index = LWABTest.hashIndex(for: key + ":" + seed, modulo: variants.count)
        let pick = variants[index]
        // 若已有缓存则沿用；若未缓存则记录为本次会话的桶位
        queue.sync {
            if buckets[key] == nil {
                buckets[key] = pick
            }
        }
        return pick
    }

    /// 强制设置某实验的当前桶位（用于灰度/回滚/测试）
    public func setBucket(_ variant: String, for key: String) {
        queue.sync { buckets[key] = variant }
    }

    /// 获取某实验当前桶位（若尚未分桶则返回 nil）
    public func currentBucket(for key: String) -> String? {
        queue.sync { buckets[key] }
    }

    /// 重置分桶
    /// - Parameter key: 传入 key 只清该实验；为 nil 时清空全部
    public func reset(_ key: String? = nil) {
        queue.sync {
            if let k = key {
                buckets.removeValue(forKey: k)
            } else {
                buckets.removeAll()
            }
        }
    }

    // MARK: - Helpers

    private static func hashIndex(for text: String, modulo: Int) -> Int {
        var hasher = Hasher()
        hasher.combine(text)
        let h = hasher.finalize()
        // 转为非负数再取模
        let positive = Int(bitPattern: UInt(bitPattern: h))
        return positive % max(modulo, 1)
    }

}
