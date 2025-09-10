//
//  ViewController.swift
//  LWToolExample
//
//  Created by June on 2025/9/9.
//

import UIKit
import SwiftUI

final class ViewController: UIViewController {

    // 通过“规格数组”集中定义需要展示的按钮（标题 + 响应方法）
    private struct ButtonSpec {
        let title: String
        let action: Selector
    }
    
    // 想再加按钮？在这里追加即可（无需到处复制粘贴代码）。
    private let buttonSpecs: [ButtonSpec] = [
        .init(title: "Network Demos", action: #selector(openNetworkDemo)),
        .init(title: "Bridge Demos",  action: #selector(openBridgeDemo))
    ]

    private lazy var stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .leading   // 按钮设置固定宽度，左对齐更自然
        sv.spacing = 16
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        buildUI()
    }

    // MARK: - UI

    private func buildUI() {
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        // 按规格批量创建并添加按钮
        for spec in buttonSpecs {
            let btn = makeButton(title: spec.title, action: spec.action)
            stackView.addArrangedSubview(btn)
        }
    }

    /// 统一样式的按钮工厂方法（iOS 13 适配，不用 UIButton.Configuration）
    private func makeButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.setTitleColor(.black, for: .normal)
        btn.backgroundColor = .systemYellow
        btn.layer.cornerRadius = 10
        btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 160),
            btn.heightAnchor.constraint(equalToConstant: 44)
        ])
        // 轻微的按下高亮反馈
        btn.addTarget(self, action: #selector(handleHighlight(_:)), for: [.touchDown, .touchDragEnter])
        btn.addTarget(self, action: #selector(handleUnhighlight(_:)), for: [.touchUpInside, .touchCancel, .touchDragExit])
        return btn
    }

    // MARK: - Actions

    @objc private func handleHighlight(_ sender: UIButton) {
        sender.alpha = 0.7
    }
    @objc private func handleUnhighlight(_ sender: UIButton) {
        sender.alpha = 1.0
    }

    @objc private func openNetworkDemo() {
        let demo = DemoHomeViewController()
        if let nav = self.navigationController {
            nav.pushViewController(demo, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: demo)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }

    @objc func openBridgeDemo() {
        let root = BridgeDemoView()
        let hosting = UIHostingController(rootView: root)
        hosting.title = "Bridge Demos"
        if let nav = self.navigationController {
            nav.pushViewController(hosting, animated: true)
        } else {
            let nav = UINavigationController(rootViewController: hosting)
            nav.modalPresentationStyle = .fullScreen
            present(nav, animated: true)
        }
    }
}

