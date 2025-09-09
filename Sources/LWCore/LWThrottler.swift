import Foundation

/**
 LWThrottler
 ----------------
 作用：
 一个**节流器**（Throttle）。在设定的 `interval` 时间间隔内，多次触发只会**最多执行一次**，
 与“防抖（Debounce）”不同：节流器是**定期地**放行一次，而防抖是**只执行最后一次**。
 内部使用串行队列保护状态，支持在任意线程安全调用。

 使用示例：
 ```swift
 // 1) 创建一个 500ms 的节流器
 let throttler = LWThrottler(0.5)

 // 2) 高频触发（例如滚动事件/按钮连点）
 func didScroll() {
     throttler.call {
         // 这里的代码在 500ms 内最多执行一次
         print("handleScroll")
     }
 }

 // 3) 在主线程执行（UI 更新场景）
 throttler.callOnMain {
     // 更新 UI
 }

 // 4) 判断是否处于冷却期 / 手动重置
 if throttler.isCoolingDown { /* 提示稍后重试 */ }
 throttler.reset() // 立即清除冷却计时
 ```

 注意事项：
 - `call` 在**允许**时同步执行回调；如需主线程回调请使用 `callOnMain`。
 - 与防抖（`LWDebouncer`）对比：节流适合“频繁上报/滚动统计”等**等间隔**触发场景；
   防抖适合“输入搜索”等**只取最后一次**场景。
 */
public final class LWThrottler {

    // MARK: - State
    private let interval: TimeInterval
    private let stateQueue = DispatchQueue(label: "lw.throttler.state")
    private var last: CFAbsoluteTime = 0

    public init(_ interval: TimeInterval) {
        self.interval = max(0, interval)
    }

    // MARK: - API

    /// 若不处于冷却期则执行；在**调用方线程**同步执行
    public func call(_ block: () -> Void) {
        if allow() {
            block()
        }
    }

    /// 若不处于冷却期则在**主线程**异步执行
    public func callOnMain(_ block: @escaping () -> Void) {
        if allow() {
            DispatchQueue.main.async(execute: block)
        }
    }

    /// 立即清空冷却状态
    public func reset() {
        stateQueue.sync { last = 0 }
    }

    /// 是否处于冷却期
    public var isCoolingDown: Bool {
        let now = CFAbsoluteTimeGetCurrent()
        return stateQueue.sync { (now - last) < interval }
    }

    // MARK: - Internal

    /// 检查并占用一次执行额度（原子操作）
    @discardableResult
    private func allow() -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        var allowed = false
        stateQueue.sync {
            if now - last >= interval {
                last = now
                allowed = true
            }
        }
        return allowed
    }
}
