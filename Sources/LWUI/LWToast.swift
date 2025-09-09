import SwiftUI

/**
 LWToast
 -------
 作用：
 一个**轻量、可配置**的 SwiftUI Toast 组件。基于 `ViewModifier`，支持：
 - 绑定字符串 `@Binding String?` 来控制显示/隐藏；
 - 可选显示位置：顶部 / 居中 / 底部；
 - 自动消失（可自定义时长），也可点按立即关闭；
 - 平滑过渡动画与阴影、圆角样式。

 使用示例：
 ```swift
 struct DemoView: View {
     @State private var toast: String?

     var body: some View {
         VStack(spacing: 20) {
             Button("Show (bottom)") { toast = "保存成功 ✅" }
             Button("Show (top)") { toast = "已复制到剪贴板" }
         }
         .padding()
         // 可选：duration / position
         .lwToast(message: $toast, duration: 1.6, position: .bottom)
     }
 }
 ```

 注意事项：
 - 绑定值为 `nil` 时不显示；设置非空字符串会显示并在 `duration` 后自动清除回 `nil`。
 - 该组件尽量保持 iOS 14+ 兼容，不依赖 iOS 15 的新 `.presentationDetents` 等能力。
 */

public enum LWToastPosition {
    case top, center, bottom
}

public struct LWToastModifier: ViewModifier {
    @Binding var message: String?
    let duration: TimeInterval
    let position: LWToastPosition

    public init(message: Binding<String?>, duration: TimeInterval = 1.6, position: LWToastPosition = .bottom) {
        self._message = message
        self.duration = duration
        self.position = position
    }

    public func body(content: Content) -> some View {
        ZStack(alignment: alignment) {
            content

            if let msg = message {
                Text(msg)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.85))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 8, x: 0, y: 3)
                    .padding(edgePadding)
                    .transition(transition)
                    .zIndex(1)
                    .onAppear {
                        // 自动消失
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation(.easeInOut) { message = nil }
                        }
                    }
                    .onTapGesture {
                        withAnimation(.easeInOut) { message = nil }
                    }
                    .accessibilityAddTraits(.isStaticText)
            }
        }
        .animation(.easeInOut, value: message != nil)
    }

    // MARK: - Layout helpers

    private var alignment: Alignment {
        switch position {
        case .top: return .top
        case .center: return .center
        case .bottom: return .bottom
        }
    }

    private var edgePadding: EdgeInsets {
        switch position {
        case .top: return EdgeInsets(top: 44, leading: 20, bottom: 0, trailing: 20)   // 避开刘海
        case .center: return EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        case .bottom: return EdgeInsets(top: 0, leading: 20, bottom: 44, trailing: 20) // 避开 Home 指示条
        }
    }

    private var transition: AnyTransition {
        switch position {
        case .top: return .move(edge: .top).combined(with: .opacity)
        case .center: return .opacity
        case .bottom: return .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

// MARK: - Convenient API

public extension View {
    /// 便捷挂载 Toast。
    /// - Parameters:
    ///   - message: 绑定的文案（为 `nil` 时隐藏）
    ///   - duration: 自动消失时长
    ///   - position: 显示位置（默认底部）
    func lwToast(message: Binding<String?>,
                 duration: TimeInterval = 1.6,
                 position: LWToastPosition = .bottom) -> some View {
        modifier(LWToastModifier(message: message, duration: duration, position: position))
    }
}
