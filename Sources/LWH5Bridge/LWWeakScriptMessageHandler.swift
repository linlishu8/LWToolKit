/*
  作用：避免 WKUserContentController 强引用导致循环引用。
  使用示例：
    userContentController.add(WeakScriptMessageHandler(self), name: "YXTBridge")
  特点/注意事项：
    - iOS13 可用。
*/
import Foundation
import WebKit

final class LWWeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
