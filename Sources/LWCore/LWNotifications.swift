#if canImport(UIKit) && (os(iOS) || os(tvOS))
import Foundation
import UserNotifications
import UIKit

public enum LWNotifications {
    public static func registerForRemoteNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert,.badge,.sound]) { _,_ in
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
}

#else
// Non-iOS/tvOS platforms: provide no-op shims if needed
#endif
