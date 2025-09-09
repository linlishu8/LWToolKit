
//
//  RetryResilienceViewController.swift
//
/*
 作用：
   通过 /status/500 触发 5xx，从而验证重试策略（若已在 Client 配置）。
   同时提供“令牌桶/断路器”演示位（需要你在 LWNetwork 的中间件中启用相应功能）。
 使用示例：
   点击“触发 500”，观察日志输出；如需定制重试策略，在构建 LWAlamofireClient 时配置。
*/

import UIKit
import LWToolKit
import SnapKit

final class RetryResilienceViewController: UIViewController {
    private let log = LogView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "重试 / 弹性"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let b1 = makeActionButton("触发 500 (/status/500)") { [weak self] in self?.trigger500() }
        let b2 = makeActionButton("令牌桶（示例位）", primary: false) { [weak self] in
            self?.log.append("令牌桶：请在中间件启用 TokenBucketLimiter 并观察速率限制效果")
        }
        let b3 = makeActionButton("断路器（示例位）", primary: false) { [weak self] in
            self?.log.append("断路器：请在中间件启用 CircuitBreaker 并观察熔断/半开/关闭状态变化")
        }

        [b1,b2,b3].forEach { stack.addArrangedSubview($0) }
        stack.addArrangedSubview(log)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func trigger500() {
        Task { @MainActor in
            let ep = DemoAPI.get(path: "/status/500")
            do {
                let _: Data = try await DemoNetwork.shared.client.request(ep, as: Data.self)
                log.append("意外成功（服务端返回 200？）")
            } catch {
                log.append("已触发错误（若配置了重试，应自动进行）：\(error)")
            }
        }
    }
}
