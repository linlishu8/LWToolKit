import SwiftUI

/**
 LWAlertItem
 -----------
 作用：
 一个用于 SwiftUI `.alert(item:)` 的轻量模型，包含 `title` 与可选的 `message`，
 并内置从 `Error` 便捷构造的方法。配套提供 `View.lwAlert(item:)` 便于展示。

 使用示例：
 ```swift
 struct DemoView: View {
     @State private var alert: LWAlertItem?

     var body: some View {
         VStack {
             Button("Show alert") {
                 alert = LWAlertItem(title: "操作失败", message: "请稍后重试")
             }

             Button("From Error") {
                 struct DemoError: LocalizedError { var errorDescription: String? { "网络异常" } }
                 alert = .from(DemoError())
             }
         }
         .lwAlert(item: $alert, dismissTitle: "好的")
         .padding()
     }
 }
 ```

 注意事项：
 - 该扩展使用 `.alert(item:content:)`（返回 `Alert` 的旧式 API），兼容 iOS 13+；
   若你仅面向 iOS 15+，也可改用新的 `.alert(_:isPresented:presenting:...)` 风格。
 */

public struct LWAlertItem: Identifiable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var message: String?

    public init(id: UUID = UUID(), title: String, message: String? = nil) {
        self.id = id
        self.title = title
        self.message = message
    }

    /// 从 Error 构造，优先使用 `LocalizedError.errorDescription`
    public static func from(_ error: Error, title: String = "错误") -> LWAlertItem {
        let message: String
        if let le = error as? LocalizedError, let desc = le.errorDescription {
            message = desc
        } else {
            message = error.localizedDescription
        }
        return LWAlertItem(title: title, message: message)
    }
}

public extension View {
    /// 便捷展示：`.alert(item:)`（iOS 13+）。
    func lwAlert(item: Binding<LWAlertItem?>,
                 dismissTitle: String = "OK",
                 onDismiss: (() -> Void)? = nil) -> some View {
        self.alert(item: item) { item in
            Alert(title: Text(item.title),
                  message: item.message.map(Text.init),
                  dismissButton: .default(Text(dismissTitle), action: { onDismiss?() }))
        }
    }
}
