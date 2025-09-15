/* 
 作用：统一触感反馈（轻/中/重、成功/警告/错误）
 使用示例：
 LWHaptics.impact(.light)
 LWHaptics.notify(.success)
*/
import UIKit

public enum LWHaptics {
    public enum Impact { case light, medium, heavy, soft, rigid }
    public enum Notice { case success, warning, error }

    public static func impact(_ type: Impact) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = {
            switch type {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }()
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    public static func notify(_ type: Notice) {
        let gen = UINotificationFeedbackGenerator()
        switch type {
        case .success: gen.notificationOccurred(.success)
        case .warning: gen.notificationOccurred(.warning)
        case .error:   gen.notificationOccurred(.error)
        }
    }
}
