import Foundation
import UIKit
import AppTrackingTransparency
import AdSupport

/**
 LWPrivacyConsent
 ----------------
 作用：
 统一封装 **App Tracking Transparency（ATT）** 授权申请与查询，
 在 iOS 14.5+ 弹出系统跟踪授权弹框，在更低系统版本下自动视为已授权（向后兼容）。
 还提供：
 - `currentATTStatus()`：获取当前授权状态；
 - `requestATTIfNeeded()`：仅在 `.notDetermined` 时请求授权；
 - `openSystemSettings()`：跳转到系统设置便于用户手动修改；
 - `idfaString`：便捷读取 IDFA（授权且可用时）。

 使用示例：
 ```swift
 // 1) 冷启动/回前台时按需请求（仅首次询问时会弹框）
 if #available(iOS 14.0, *) {
     let status = await LWPrivacyConsent.requestATTIfNeeded()
     print("ATT status:", status.rawValue)
 } else {
     // iOS 14 以下等价已授权
 }

 // 2) 仅查询当前状态
 if #available(iOS 14.0, *) {
     let status = LWPrivacyConsent.currentATTStatus()
     print(status.rawValue)
 }

 // 3) 打开系统设置（引导用户修改权限）
 LWPrivacyConsent.openSystemSettings()

 // 4) 读取 IDFA（需授权 + 非全零）
 let idfa = LWPrivacyConsent.idfaString
 ```

 注意事项：
 - 请在 Info.plist 中配置 `NSUserTrackingUsageDescription`，否则请求时将被拒绝；
   Debug 构建建议加断言提示。
 - `requestTrackingAuthorization` 需在**主线程**调用；本实现已使用 `@MainActor` 保证。
 - iOS 14.0~14.4 存在 API，但 Apple 要求 14.5+ 才会真正弹框；本实现对 14.0~14.4 直接返回当前状态。
 */
public enum LWPrivacyConsent {

    // MARK: - Status (query)

    /// 获取当前 ATT 状态（iOS 14 以下视为 authorized）
    public static func currentATTStatus() -> ATTrackingManager.AuthorizationStatus {
        if #available(iOS 14.0, *) {
            return ATTrackingManager.trackingAuthorizationStatus
        } else {
            // iOS < 14: ATT 不适用，视为 authorized
            return .authorized
        }
    }

    // MARK: - Request

    /// 若状态为 .notDetermined 则发起授权请求；否则直接返回当前状态
    @MainActor
    @available(iOS 14.0, *)
    public static func requestATTIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        // 14.5 之前系统不会真正弹框，这里统一返回当前值以避免误导
        guard #available(iOS 14.5, *) else {
            return ATTrackingManager.trackingAuthorizationStatus
        }

        // 可选：开发期检测 Info.plist 是否配置描述文案
        #if DEBUG
        if Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") == nil {
            assertionFailure("Missing NSUserTrackingUsageDescription in Info.plist")
        }
        #endif

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            await withCheckedContinuation { cont in
                ATTrackingManager.requestTrackingAuthorization { _ in
                    cont.resume()
                }
            }
        }
        return ATTrackingManager.trackingAuthorizationStatus
    }

    // MARK: - Utilities

    /// 打开系统设置（应用详情页）
    public static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// 便捷读取 IDFA（iOS14+ 需 ATT 授权；所有版本都需非全零 UUID）
    public static var idfaString: String? {
        let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")

        if #available(iOS 14.0, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else { return nil }
            let uuid = ASIdentifierManager.shared().advertisingIdentifier
            return (uuid == zeroUUID) ? nil : uuid.uuidString
        } else {
            // iOS 14 以下：不使用已弃用的 isAdvertisingTrackingEnabled，直接判断 UUID 非全零
            let uuid = ASIdentifierManager.shared().advertisingIdentifier
            return (uuid == zeroUUID) ? nil : uuid.uuidString
        }
    }
}
