
/*
 作用：提供 UIKit 容器，方便在现有控制器里 push 本 Demo 的 SwiftUI 页面。
 使用示例：
   let vc = DemoHomeViewController()
   navigationController?.pushViewController(vc, animated: true)
*/
import UIKit
import SwiftUI

public final class DemoHomeViewController: UIViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let root: AnyView
        if #available(iOS 16.0, *) {
            root = AnyView(NavigationStack { DemoHomeView() })
        } else {
            root = AnyView(NavigationView { DemoHomeView() })
        }

        let hosting = UIHostingController(rootView: root)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
        title = "LWNetwork Demo"
    }
}
