import Foundation

/**
 LWFeatureFlags
 ----------------
 作用：
 一个**轻量的特性开关与远端配置中心**门面。支持「本地默认配置」与「远端下发配置」两层并行，
 并提供类型化读取（Bool/Int/Double/String）。内部线程安全，读多写少的场景下性能友好。
 还支持调试期的**临时覆盖**（override），便于灰度与 QA 验证。优先级：override > remote > local > default。

 使用示例：
 ```swift
 // 1) 启动时注入本地默认配置（通常来自 plist/内置 JSON）
 LWFeatureFlags.shared.setup(local: [
     "new_paywall_enabled": false,
     "home_banner_title": "Welcome",
     "ab_test_weight": 20
 ])

 // 2) 收到后端下发（远端配置）时更新
 LWFeatureFlags.shared.updateRemote([
     "new_paywall_enabled": true,
     "home_banner_title": "Hello, Singapore!"
 ])

 // 3) 业务读取（支持容错转换）
 if LWFeatureFlags.shared.bool("new_paywall_enabled") {
     // 展示新版付费墙
 }
 let title = LWFeatureFlags.shared.string("home_banner_title", default: "Welcome")
 let weight = LWFeatureFlags.shared.int("ab_test_weight", default: 10)

 // 4) QA/调试：临时覆盖与清理
 LWFeatureFlags.shared.setOverride(true, for: "new_paywall_enabled")
 LWFeatureFlags.shared.clearOverride("new_paywall_enabled")
 LWFeatureFlags.shared.clearAllOverrides()

 // 5) 监听更新（可用于刷新 UI）
 NotificationCenter.default.addObserver(forName: LWFeatureFlags.didUpdate,
                                        object: nil, queue: .main) { note in
     // note.userInfo?["keys"] 为本次变更的键集合（Set<String>）
 }
 ```

 注意事项：
 - 读取方法具备**温和容错**：当值为字符串/数字时会尝试转换为目标类型（例如 "1"/"true" -> Bool）。
 - 线程安全：内部使用并发队列 + barrier 写入；可在任意线程调用。
 - 若你希望将 override 持久化（重启仍生效），可在外部自行同步到 UserDefaults，并在启动时恢复。
 */
public final class LWFeatureFlags {

    // MARK: - Notifications

    public static let didUpdate = Notification.Name("LWFeatureFlags.didUpdate")

    // MARK: - Singleton

    public static let shared = LWFeatureFlags()
    public init() {}

    // MARK: - Storage (thread-safe, read-heavy)

    private let queue = DispatchQueue(label: "lw.feature.flags", attributes: .concurrent)

    private var local: [String: Any] = [:]      // 内置默认
    private var remote: [String: Any] = [:]     // 远端下发
    private var overrides: [String: Any] = [:]  // 临时覆盖（优先级最高）

    // MARK: - Setup / Update

    /// 注入本地默认配置（整体替换）
    public func setup(local: [String: Any]) {
        write { [self] in
            self.local = local
        }
        notifyChanged(keys: Set(local.keys))
    }

    /// 替换远端配置（整体替换）
    public func updateRemote(_ data: [String: Any]) {
        write { [self] in
            self.remote = data
        }
        notifyChanged(keys: Set(data.keys))
    }

    /// 合并远端配置（增量更新）
    public func mergeRemote(_ data: [String: Any]) {
        var changed = Set<String>()
        write { [self] in
            for (k, v) in data {
                changed.insert(k)
                self.remote[k] = v
            }
        }
        notifyChanged(keys: changed)
    }

    // MARK: - Overrides (debug/QA)

    /// 设置/更新调试期覆盖值（传 nil 等价于清除）
    public func setOverride(_ value: Any?, for key: String) {
        var changed: String?
        write { [self] in
            let k = key
            if let v = value {
                overrides[k] = v
            } else {
                overrides.removeValue(forKey: k)
            }
            changed = k
        }
        if let k = changed { notifyChanged(keys: [k]) }
    }

    /// 清除某个覆盖值
    public func clearOverride(_ key: String) {
        setOverride(nil, for: key)
    }

    /// 清空所有覆盖值
    public func clearAllOverrides() {
        var keys: [String] = []
        write { [self] in
            keys = Array(overrides.keys)
            overrides.removeAll()
        }
        notifyChanged(keys: Set(keys))
    }

    // MARK: - Typed accessors

    public func bool(_ key: String, default def: Bool = false) -> Bool {
        if let v = value(for: key) { return castBool(v) ?? def }
        return def
    }

    public func int(_ key: String, default def: Int = 0) -> Int {
        if let v = value(for: key) { return castInt(v) ?? def }
        return def
    }

    public func double(_ key: String, default def: Double = 0) -> Double {
        if let v = value(for: key) { return castDouble(v) ?? def }
        return def
    }

    public func string(_ key: String, default def: String = "") -> String {
        if let v = value(for: key) { return castString(v) ?? def }
        return def
    }

    /// 读取原始值（合并后），仅调试用途
    public func any(_ key: String) -> Any? {
        read {
            if let v = overrides[key] { return v }
            if let v = remote[key] { return v }
            return local[key]
        }
    }

    // MARK: - Internals

    private func value(for key: String) -> Any? {
        read {
            if let v = overrides[key] { return v }
            if let v = remote[key] { return v }
            return local[key]
        }
    }

    private func read<T>(_ block: () -> T) -> T {
        queue.sync { block() }
    }

    private func write(_ block: @escaping () -> Void) {
        queue.async(flags: .barrier, execute: block)
    }

    private func notifyChanged<S: Sequence>(keys: S) where S.Element == String {
        let set = Set(keys)
        guard !set.isEmpty else { return }
        NotificationCenter.default.post(name: LWFeatureFlags.didUpdate, object: self, userInfo: ["keys": set])
    }

    // MARK: - Casting helpers (tolerant)

    private func castBool(_ v: Any) -> Bool? {
        switch v {
        case let b as Bool: return b
        case let n as NSNumber: return n != 0
        case let s as String:
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["1", "true", "yes", "y", "on"].contains(t) { return true }
            if ["0", "false", "no", "n", "off"].contains(t) { return false }
            return nil
        default: return nil
        }
    }

    private func castInt(_ v: Any) -> Int? {
        switch v {
        case let i as Int: return i
        case let n as NSNumber: return n.intValue
        case let s as String: return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }

    private func castDouble(_ v: Any) -> Double? {
        switch v {
        case let d as Double: return d
        case let f as Float: return Double(f)
        case let n as NSNumber: return n.doubleValue
        case let s as String: return Double(s.trimmingCharacters(in: .whitespacesAndNewlines))
        default: return nil
        }
    }

    private func castString(_ v: Any) -> String? {
        switch v {
        case let s as String: return s
        case let n as NSNumber: return n.stringValue
        case let b as Bool: return b ? "true" : "false"
        default: return String(describing: v)
        }
    }
}
