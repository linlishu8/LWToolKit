import Foundation

/**
 LWPerfMetrics
 ----------------
 作用：
 一个**轻量级性能计时器**。支持用字符串键打点（`mark`），并计算自打点以来的耗时（`measure`）；
 也提供 `begin/end` 语义与包装函数 `time(_:)`，便于对某段代码的执行时间进行测量。
 内部使用并发队列 + barrier 写入，保证线程安全，适合在开发期/测试期快速埋点分析。

 使用示例：
 ```swift
 // 1) 基于 mark/measure 的自由计时
 LWPerfMetrics.shared.mark("cold_start")
 // ... do work ...
 if let t = LWPerfMetrics.shared.measure(since: "cold_start", remove: true) {
     print(String(format: "cold start took %.2f ms", t * 1000))
 }

 // 2) begin/end 语义（end 默认会移除该键）
 LWPerfMetrics.shared.begin("db_load")
 // ... query DB ...
 let dbCost = LWPerfMetrics.shared.end("db_load") ?? 0

 // 3) 直接计时一段代码块
 let (elapsed, value) = LWPerfMetrics.shared.time("parse_json") {
     try JSONDecoder().decode(Model.self, from: data)
 }
 print("parse_json:", elapsed, "s")

 // 4) 清理
 LWPerfMetrics.shared.reset("db_load")
 LWPerfMetrics.shared.resetAll()
 ```

 注意事项：
 - `measure` 返回的是**调用时刻**与上次 `mark/begin` 的时间差，不会自动重置；
   若希望一次性测量后清理，可传 `remove: true` 或使用 `end`。
 - 计时单位为秒；打印时可乘以 1000 以获得毫秒。
 */
public final class LWPerfMetrics {

    // MARK: - Singleton
    public static let shared = LWPerfMetrics()
    public init() {}

    // MARK: - Storage (thread-safe)
    private let queue = DispatchQueue(label: "lw.perf.metrics", attributes: .concurrent)
    private var marks: [String: CFAbsoluteTime] = [:]

    // MARK: - API (mark / measure)

    /// 记录一个打点时间（以当前时刻）
    public func mark(_ key: String) {
        let now = CFAbsoluteTimeGetCurrent()
        queue.async(flags: .barrier) { [weak self] in
            self?.marks[key] = now
        }
    }

    /// 自某个打点起计算耗时
    /// - Parameters:
    ///   - key: 打点键
    ///   - remove: 是否在计算后移除该打点（默认 false）
    /// - Returns: 耗时（秒）；若未打点则返回 nil
    public func measure(since key: String, remove: Bool = false) -> TimeInterval? {
        let now = CFAbsoluteTimeGetCurrent()
        var start: CFAbsoluteTime?
        queue.sync { start = marks[key] }
        guard let s = start else { return nil }
        if remove {
            queue.async(flags: .barrier) { [weak self] in
                self?.marks.removeValue(forKey: key)
            }
        }
        return now - s
    }

    // MARK: - API (begin / end)

    /// 与 mark 同义
    public func begin(_ key: String) { mark(key) }

    /// 结束并返回耗时（默认会清理该键）
    @discardableResult
    public func end(_ key: String, remove: Bool = true) -> TimeInterval? {
        measure(since: key, remove: remove)
    }

    // MARK: - API (wrap a block)

    /// 计时执行一段代码
    /// - Returns: (耗时, 代码返回值)
    public func time<T>(_ key: String? = nil, _ block: () throws -> T) rethrows -> (TimeInterval, T) {
        if let k = key { begin(k) }
        let t0 = CFAbsoluteTimeGetCurrent()
        let value = try block()
        let elapsed = CFAbsoluteTimeGetCurrent() - t0
        if let k = key { _ = end(k) }
        return (elapsed, value)
    }

    // MARK: - Maintenance

    /// 移除某个打点
    public func reset(_ key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.marks.removeValue(forKey: key)
        }
    }

    /// 清空所有打点
    public func resetAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.marks.removeAll()
        }
    }

    /// 当前存在的打点数量
    public var count: Int {
        var c = 0
        queue.sync { c = marks.count }
        return c
    }
}
