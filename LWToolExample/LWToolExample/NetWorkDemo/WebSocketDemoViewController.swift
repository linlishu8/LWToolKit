
//
//  WebSocketDemoViewController.swift
//
/*
 作用：
   演示 WebSocket 思路。默认使用本地模拟，也可改为连接 echo 通道。
 使用示例：
   点击“模拟连接”，输入文本并发送；可点击“关闭”。
*/

import UIKit
import Combine
import SnapKit

final class WebSocketDemoViewController: UIViewController {
    private let log = LogView()
    private var timer: AnyCancellable?
    private let input = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "WebSocket"
        view.backgroundColor = .systemBackground

        input.placeholder = "输入要发送的文本"
        input.borderStyle = .roundedRect

        let connect = makeActionButton("模拟连接") { [weak self] in self?.connectMock() }
        let close = makeActionButton("关闭", primary: false) { [weak self] in self?.closeMock() }
        let send = makeActionButton("发送", primary: false) { [weak self] in self?.sendMock() }

        let top = UIStackView(arrangedSubviews: [connect, close])
        top.axis = .horizontal
        top.spacing = 12
        top.distribution = .fillEqually

        let mid = UIStackView(arrangedSubviews: [input, send])
        mid.axis = .horizontal
        mid.spacing = 12
        send.setContentHuggingPriority(.required, for: .horizontal)

        let v = UIStackView(arrangedSubviews: [top, mid, log])
        v.axis = .vertical
        v.spacing = 12

        view.addSubview(v)
        v.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func connectMock() {
        log.append("connected (mock)")
        timer?.cancel()
        timer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.log.append("recv: tick @ \(Date())") }
    }

    private func closeMock() {
        timer?.cancel()
        timer = nil
        log.append("closed")
    }

    private func sendMock() {
        let text = input.text ?? ""
        guard !text.isEmpty else { return }
        log.append("send: \(text)")
        log.append("recv: \(text)")
        input.text = nil
    }
}
