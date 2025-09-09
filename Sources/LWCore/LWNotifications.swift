import Foundation
import UserNotifications
import UIKit

/**
 LWNotifications
 ----------------
 作用：
 一个**通知权限与推送注册的轻量门面**。封装了通知授权申请、APNs 远程推送注册、
 权限状态查询、跳转系统设置以及角标管理等常用操作。确保在主线程调用
 `UIApplication.shared.registerForRemoteNotifications()`。

 使用示例：
 ```swift
 // 1) 启动时申请权限并注册 APNs
 LWNotifications.requestAuthorizationAndRegister { granted, status in
     print("granted=\(granted), status=\(status.rawValue)")
 }

 // 2) 只查询当前权限
 LWNotifications.getAuthorizationStatus { status in
     print("current status:", status)
 }

 // 3) 用户手动打开系统设置
 LWNotifications.openSystemSettings()

 // 4) 设置与清除应用角标
 LWNotifications.setBadge(3)
 LWNotifications.clearBadge()

 // 5) AppDelegate / UIApplicationDelegate 中接收 device token
 // func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
 //     let token = deviceToken.map { String(format: "%02x", $0) }.joined()
 //     print("APNs token:", token)
 // }
 // func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
 //     print("APNs register failed:", error)
 // }
 ```

 注意事项：
 - iOS 的通知授权状态包括：`.authorized`、`.provisional`、`.ephemeral`、`.denied`、`.notDetermined`；
   本工具在 **authorized / provisional / ephemeral** 时会自动调用 `registerForRemoteNotifications()`。
 - 如果你需要自定义通知分类（actions/categories），请在调用授权前先注册 `UNUserNotificationCenter.current().setNotificationCategories(...)`。
 */
public enum LWNotifications {

    /// 申请通知权限并在授权成功（含 provisional/ephemeral）时注册 APNs
    /// - Parameters:
    ///   - options: 授权选项，默认 `.alert/.badge/.sound`
    ///   - completion: 回调授权结果与最终状态
    public static func requestAuthorizationAndRegister(
        options: UNAuthorizationOptions = [.alert, .badge, .sound],
        completion: ((Bool, UNAuthorizationStatus) -> Void)? = nil
    ) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: options) { granted, _ in
            center.getNotificationSettings { settings in
                let status = settings.authorizationStatus
                if shouldRegister(with: status) {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
                completion?(granted, status)
            }
        }
    }

    /// 查询当前通知授权状态
    public static func getAuthorizationStatus(_ completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    /// 跳转到系统设置（应用详情页）
    public static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// 设置应用角标数字
    public static func setBadge(_ number: Int) {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = number
        }
    }

    /// 清除应用角标与所有已送达通知
    public static func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
    }

    /// 辅助：根据授权状态判断是否应注册 APNs
    private static func shouldRegister(with status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional:
            return true
        case .ephemeral:
            // Apple 可能将临时授权用于 web 推送等；此处也选择注册
            return true
        default:
            return false
        }
    }
}
