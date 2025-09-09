import Foundation

/**
 LWDebouncer
 ----------------
 作用：
 一个**主线程防抖工具**。在设定的 `delay` 时间窗口内多次调用 `call(_:)`，只会触发**最后一次**回调，
 常用于搜索框联想、按钮频繁点击、窗口尺寸变化等场景，避免高频操作带来的抖动与性能浪费。

 使用示例：
 ```swift
 // 1) 创建一个 300ms 的防抖实例（通常放在视图或控制器里持有）
 let debouncer = LWDebouncer(delay: 0.3)

 // 2) 在输入变化时调用（多次变更只会在 300ms 后触发最后一次）
 func searchTextDidChange(_ text: String) {
     debouncer.call {
         // 回调运行在主线程
         performSearch(keyword: text)
     }
 }

 // 3) 取消/立即执行
 debouncer.cancel() // 取消尚未触发的任务
 debouncer.flush()  // 立即执行一次并清空挂起任务（若存在）
 ```

 注意事项：
 - 回调在**主线程**执行；如果你的任务是耗时操作，请在回调内部自行切到后台队列。
 - `LWDebouncer` 是**线程安全**的；内部使用独立串行队列管理状态。
 - 若实例销毁，未触发的任务会自动取消，无需手动处理。
 */
public final class LWDebouncer {

    // MARK: - Private State

    private let delay: TimeInterval
    private let stateQueue = DispatchQueue(label: "lw.debouncer.state")
    private var work: DispatchWorkItem?

    // MARK: - Init

    /// - Parameter delay: 防抖延迟（秒）
    public init(delay: TimeInterval) {
        self.delay = delay
    }

    // MARK: - API

    /// 启动/重置一次防抖计时；窗口内仅最后一次会执行
    /// - Parameter block: 到期后要执行的回调（在主线程）
    public func call(_ block: @escaping () -> Void) {
        let item = DispatchWorkItem(block: block)

        stateQueue.sync {
            work?.cancel()
            work = item
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: item
        )
    }

    /// 取消尚未执行的任务
    public func cancel() {
        stateQueue.sync {
            work?.cancel()
            work = nil
        }
    }

    /// 立即执行并清空挂起任务（若存在）
    public func flush() {
        var item: DispatchWorkItem?
        stateQueue.sync {
            item = work
            work = nil
        }
        item?.perform()
    }

    /// 是否存在尚未触发的任务
    public var isScheduled: Bool {
        stateQueue.sync { work != nil && !(work!.isCancelled) }
    }

    deinit { cancel() }
}
