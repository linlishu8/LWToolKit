
//
//  AuthRefreshViewController.swift
//
/*
 作用：
   模拟 401 -> 触发刷新 -> 重放原请求 的流程（需在 LWAuthInterceptor 内实现刷新逻辑）。
 使用示例：
   点击按钮触发 /status/401，观察拦截器处理（刷新与重放）。
*/

import UIKit
import LWToolKit
import SnapKit

final class AuthRefreshViewController: UIViewController {
    private let log = LogView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "认证 / 刷新"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let b1 = makeActionButton("带鉴权请求（模拟 401）") { [weak self] in self?.authRequest() }
        let tip = UILabel()
        tip.text = "提示：请在 LWAuthInterceptor 中配置 refresh 逻辑（401 时拉取新 token 并重放）。"
        tip.font = .systemFont(ofSize: 12)
        tip.textColor = .secondaryLabel
        tip.numberOfLines = 0

        stack.addArrangedSubview(b1)
        stack.addArrangedSubview(tip)
        stack.addArrangedSubview(log)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func authRequest() {
        Task { @MainActor in
            let ep = DemoAPI.void(path: "/status/401", method: .get, requiresAuth: true)
            do {
                try await DemoNetwork.shared.client.requestVoid(ep)
                log.append("成功（未返回 401）")
            } catch {
                log.append("收到 401（期望由拦截器刷新并重放）：\(error)")
            }
        }
    }
}
