/* 
 作用：UIColor 十六进制扩展（与 Color 对齐）
 使用示例：
   let ui1 = UIColor(hex: "#222222")
   let ui2 = UIColor(hexInt: 0x3498db, alpha: 0.9)
 注意事项：iOS 14+。
*/
import UIKit

public extension UIColor {
    convenience init(hex: String, alpha: CGFloat? = nil) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8: (a,r,g,b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        let fa = alpha ?? CGFloat(a)/255.0
        self.init(red: CGFloat(r)/255.0, green: CGFloat(g)/255.0, blue: CGFloat(b)/255.0, alpha: fa)
    }

    convenience init(hexInt: UInt64, alpha: CGFloat = 1.0) {
        let r = CGFloat((hexInt & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((hexInt & 0x00FF00) >> 8)  / 255.0
        let b = CGFloat(hexInt & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
