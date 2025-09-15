/* 
 作用：Color 十六进制扩展（支持 3/6/8 位、带 0x/# 前缀、可指定 alpha）
 使用示例：
   let c1 = Color(hex: "#1DA1F2")
   let c2 = Color(hex: "0xFFCC00", alpha: 0.8)
   let c3 = Color(hexInt: 0x3498db)
   let hex = Color.red.yxtHexString()   // "FF0000FF"（RGBA）
 注意事项：统一 sRGB 色域，iOS 14+。
*/
import SwiftUI

public extension Color {
    init(hex: String, alpha: Double? = nil) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0; Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a,r,g,b) = (255,(int>>8)*17, (int>>4 & 0xF)*17, (int & 0xF)*17)
        case 6: (a,r,g,b) = (255,int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8: (a,r,g,b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        let fa = alpha ?? Double(a)/255.0
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: fa)
    }

    init(hexInt: UInt64, alpha: Double = 1.0) {
        let r = Double((hexInt & 0xFF0000) >> 16) / 255.0
        let g = Double((hexInt & 0x00FF00) >> 8)  / 255.0
        let b = Double(hexInt & 0x0000FF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    func yxtHexString(includeAlpha: Bool = true) -> String {
        #if canImport(UIKit)
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        let R = Int(round(r*255)), G = Int(round(g*255)), B = Int(round(b*255)), A = Int(round(a*255))
        return includeAlpha ? String(format: "%02X%02X%02X%02X", R,G,B,A) : String(format: "%02X%02X%02X", R,G,B)
        #else
        return ""
        #endif
    }
}
