
/*
 作用：一些通用工具：指数退避重试、Idempotency-Key 生成、简易主线程 toast 占位等。
 使用示例：
   let delay = Backoff.exponential(attempt: n, base: 0.5, max: 10)
   let key = IdempotencyKey.make()
*/
import Foundation
import UIKit

public enum Backoff {
    public static func exponential(attempt: Int, base: TimeInterval = 0.5, factor: Double = 2.0, maxTime: TimeInterval = 30) -> TimeInterval {
        let v = base * pow(factor, Double(max(0, attempt - 1)))
        return min(v, maxTime)
    }
}

public enum IdempotencyKey {
    public static func make(prefix: String = "idem") -> String {
        "\(prefix)_\(UUID().uuidString)"
    }
}

// 临时 UI 辅助（你的项目可替换为 HUD/Toast 组件）
public func toast(_ text: String) {
    DispatchQueue.main.async {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.windowLevel = .alert + 1
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textColor = .white
        label.layer.cornerRadius = 12
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        let vc = UIViewController()
        vc.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor, constant: -120),
            label.widthAnchor.constraint(lessThanOrEqualTo: vc.view.widthAnchor, multiplier: 0.9)
        ])
        w.rootViewController = vc
        w.makeKeyAndVisible()
        UIView.animate(withDuration: 0.3, animations: { label.alpha = 1 }) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                w.isHidden = true
            }
        }
    }
}
