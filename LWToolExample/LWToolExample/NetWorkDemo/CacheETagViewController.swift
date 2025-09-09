
//
//  CacheETagViewController.swift
//
/*
 作用：
   演示 ETag 命中：第一次 200，随后 304 Not Modified（视客户端实现）。
 使用示例：
   连续点击按钮两次，观察日志中文本差异。
*/

import UIKit
import LWToolKit
import SnapKit

final class CacheETagViewController: UIViewController {
    private let log = LogView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ETag 演示"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let b1 = makeActionButton("请求 /etag/abc123") { [weak self] in self?.doETag() }
        stack.addArrangedSubview(b1)
        stack.addArrangedSubview(log)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func doETag() {
        Task { @MainActor in
            let ep = DemoAPI.get(path: "/etag/abc123")
            do {
                let data: Data = try await DemoNetwork.shared.client.request(ep, as: Data.self)
                log.append("200 OK：length=\(data.count)")
            } catch {
                log.append("可能为 304 Not Modified 或其它错误：\(error)")
            }
        }
    }
}
