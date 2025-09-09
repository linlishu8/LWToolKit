//
//  LWToolKit.swift
//  LWLogger
//
//  Created by linlishu8 on 2025/8/1.
//

import Foundation
import OSLog

/**
 LWLogger
 ----------------
 作用：
 一个**超轻量的跨版本日志门面**。在 iOS 14+ 使用 `os.Logger` 输出（统一接入系统控制台、
 性能友好、可结构化），在更低系统版本自动回退到 `NSLog`。提供单一入口
 `LWLogger.debug(_:)`，方便在项目中统一替换与收敛调试日志。

 特点：
 - 自动兼容：iOS 14+ 走 `Logger`，更低版本用 `NSLog`
 - 简单易用：只有一个静态方法，不侵入业务
 - 隐私控制：对 `Logger` 的字符串插值采用 `privacy: .public`，避免默认私有导致控制台看不到内容

 注意：
 - `os.Logger` 的字符串插值**默认是 `.private`**，会在控制台被折叠。本实现显式声明为
   `.public`：`"\(s, privacy: .public)"`。如果内容包含敏感信息，请自行做脱敏或改为 `.private`。
 - 如需按模块分类（subsystem/category），可以扩展新的方法并使用
   `Logger(subsystem:category:)` 创建固定实例。
 - 若只想在 Debug 包输出，可配合 `#if DEBUG` 包裹调用方或方法体。

 使用示例：
 ```swift
 // 基本使用
 LWLogger.debug("App launched")

 // 插值输出（已设置为 .public）
 let userId = "12345"
 LWLogger.debug("Login success, userId=\(userId)")

 // 进阶：自定义分类（可作为你自己的扩展示例）
 // let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "app", category: "Network")
 // log.debug("\("GET /v1/profile", privacy: .public)")
*/

public enum LWLogger {
    /// 输出 Debug 级别日志（iOS 14+ 使用 os.Logger，低版本使用 NSLog）
    /// - Parameter s: 要打印的字符串；在 iOS 14+ 会以 `.public` 隐私级别写入 oslog
    public static func debug(_ s: String) {
        if #available(iOS 14.0, *) {
            Logger().debug("\(s, privacy: .public)")
        } else {
            NSLog("%@", s)
        }
    }
}


