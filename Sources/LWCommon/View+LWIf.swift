/* 
 作用：条件修饰（.if / .ifLet），让修饰链保持函数式风格
 使用示例：
   Text("Hello").if(isHighlighted) { $0.foregroundColor(.red) }
   Text("ID").ifLet(userId) { view, id in view.accessibilityIdentifier(id) }
*/
import SwiftUI

public extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    @ViewBuilder func ifLet<T, Content: View>(_ value: T?, transform: (Self, T) -> Content) -> some View {
        if let v = value { transform(self, v) } else { self }
    }
}
