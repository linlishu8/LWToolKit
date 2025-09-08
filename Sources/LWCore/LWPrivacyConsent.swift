import Foundation
import AppTrackingTransparency
public enum LWPrivacyConsent {
    public static func requestATTIfNeeded() async -> ATTrackingManager.AuthorizationStatus {
        if #available(iOS 14.5, *) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                await withCheckedContinuation { cont in ATTrackingManager.requestTrackingAuthorization { _ in cont.resume() } }
            }
            return ATTrackingManager.trackingAuthorizationStatus
        } else { return .authorized }
    }
}
