/* 
 作用：只对指定角添加圆角
 使用示例：
   VStack { ... }
     .yxtCornerRadius(20, corners: [.topLeft, .topRight])
 注意事项：依赖 UIKit 的 UIRectCorner；iOS 14+。
*/
import SwiftUI
import UIKit

private struct LWRoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = []
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

public extension View {
    func lwRoundedCorner(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(LWRoundedCorner(radius: radius, corners: corners))
    }
}
