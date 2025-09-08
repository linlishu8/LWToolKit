import Foundation
import AppTrackingTransparency

public typealias ATTAuthorizationStatus = ATTrackingManager.AuthorizationStatus

public enum LWPrivacyConsent {
    @available(iOS 14.0, *)
    public static func requestATTIfNeeded() async -> ATTAuthorizationStatus {
        if #available(iOS 14.5, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                await withCheckedContinuation { cont in
                    ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() }
                }
            }
            return ATTrackingManager.trackingAuthorizationStatus
        } else {
            return .authorized
        }
    }
}
