
//
//  SSEDemoViewController.swift
//
/*
 作用：
   演示 SSE（服务端推送）思路。此处使用本地 Timer 模拟事件流，避免网络/ATS 影响。
 使用示例：
   点击“开始（本地模拟）”，观察日志；点击“停止”结束。
*/

import UIKit
import Combine
import SnapKit

final class SSEDemoViewController: UIViewController {
    private let log = LogView()
    private var timerCancellable: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SSE"
        view.backgroundColor = .systemBackground

        let start = makeActionButton("开始（本地模拟）") { [weak self] in self?.startMock() }
        let stop = makeActionButton("停止", primary: false) { [weak self] in self?.stop() }

        let h = UIStackView(arrangedSubviews: [start, stop])
        h.axis = .horizontal
        h.spacing = 12
        h.distribution = .fillEqually

        let tip = UILabel()
        tip.text = "在线 SSE 可参考 Wikimedia RecentChange：\nhttps://stream.wikimedia.org/v2/stream/recentchange"
        tip.font = .systemFont(ofSize: 12)
        tip.textColor = .secondaryLabel
        tip.numberOfLines = 0

        let v = UIStackView(arrangedSubviews: [h, log, tip])
        v.axis = .vertical
        v.spacing = 12

        view.addSubview(v)
        v.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func startMock() {
        stop()
        log.setText("")
        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            // 修复点：scan 闭包需要两个参数 (acc, output: Date)
            .scan(0) { acc, _ in acc + 1 }
            .sink { [weak self] i in
                self?.log.append("event #\(i) @ \(Date())")
            }
    }

    private func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        log.append("stopped")
    }
}
