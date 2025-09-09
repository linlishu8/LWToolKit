//
//  LWToolKit.swift
//  LWEventTracker
//
//  Created by linlishu8 on 2025/8/1.
//

import Foundation

/**
 LWEventTracker
 ----------------
 作用：
 一个**超轻量级的事件埋点/通知分发器**。你可以向它发送事件（名称 + 参数），
 并为它挂接多个“出口”（sink），比如：打印日志、上报第三方统计 SDK、
 写入本地文件、发送到服务器等。它用串行队列保证**线程安全**，不会和业务线程抢锁。

 特点：
 - 线程安全：内部用串行 `DispatchQueue` 管理 sinks 的读写与触发
 - 零依赖：只依赖 Foundation
 - 多路分发：可同时挂接多个 sink
 - 简单易用：一行添加 sink，一行上报事件

 ⚠️ 注意：
 - sink 的回调在 **内部串行队列** 上执行。如果需要更新 UI，请自行切到主线程：
   `DispatchQueue.main.async { ... }`
 - 这是一个“分发器”而非“存储器”，不会持久化事件。

 使用示例：
 ```swift
 // 1) 定义一个输出到控制台的 sink
 LWEventTracker.shared.addSink { name, params in
     print("📦 [Event] \(name)  params=\(params ?? [:])")
 }

 // 2) 定义一个转发到第三方 SDK 的 sink（示例）
 LWEventTracker.shared.addSink { name, params in
     // AnalyticsSDK.track(name: name, properties: params ?? [:])
 }

 // 3) 在业务代码里上报事件
 LWEventTracker.shared.track(name: "app_launch", params: [
     "from_background": false,
     "user_id": "12345"
 ])

 // 4) UI 回调注意切主线程
 LWEventTracker.shared.addSink { name, params in
     DispatchQueue.main.async {
         // 更新页面提示或埋点指示灯
     }
 }
*/
public protocol LWEventTracking { func track(name: String, params: [String: Any]?) }

public final class LWEventTracker: LWEventTracking {
    /// 全局单例（建议直接使用）
    public static let shared = LWEventTracker()

    /// 内部事件回调类型
    public typealias EventSink = (String, [String: Any]?) -> Void

    /// 串行队列：保证对 sinks 的增删与触发是线程安全的
    private let queue = DispatchQueue(label: "lw.event.tracker")

    /// 已注册的事件出口（sink）列表
    private var sinks: [EventSink] = []

    /// 注册一个 sink，用于接收之后的所有事件
    /// - Parameter s: 事件回调闭包
    public func addSink(_ s: @escaping EventSink) {
        queue.sync { sinks.append(s) }
    }

    /// 上报事件（异步在内部队列依次回调所有 sink）
    /// - Parameters:
    ///   - name: 事件名
    ///   - params: 事件参数（可选）
    public func track(name: String, params: [String: Any]? = nil) {
        queue.async { self.sinks.forEach { $0(name, params) } }
    }

}
