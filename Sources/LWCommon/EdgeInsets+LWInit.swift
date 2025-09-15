/* 
 作用：EdgeInsets 横/纵便捷初始化
 使用示例：
   .padding(EdgeInsets(horizontal: 16, vertical: 12))
*/
import SwiftUI

public extension EdgeInsets {
    init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.init(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }
}
