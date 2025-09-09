
//
//  OfflineQueueViewController.swift
//
/*
 作用：
   演示离线队列思路：将请求暂存为任务，待“恢复网络”后批量发送。
 使用示例：
   先“加入 3 个任务”，再“模拟恢复并发送”。
*/

import UIKit
import LWToolKit
import SnapKit

struct DemoOfflineTask {
    let id = UUID()
    let endpoint: LWAPI
}

final class OfflineQueueViewController: UIViewController, UITableViewDataSource {
    private let log = LogView()
    private let table = UITableView(frame: .zero, style: .plain)
    private var tasks: [DemoOfflineTask] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "离线队列（示例）"
        view.backgroundColor = .systemBackground

        let addBtn = makeActionButton("加入 3 个任务") { [weak self] in self?.enqueue3() }
        let flushBtn = makeActionButton("模拟恢复并发送", primary: false) { [weak self] in self?.flush() }

        let hstack = UIStackView(arrangedSubviews: [addBtn, flushBtn])
        hstack.axis = .horizontal
        hstack.spacing = 12
        hstack.distribution = .fillEqually

        table.dataSource = self
        table.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        table.rowHeight = 44

        let vstack = UIStackView(arrangedSubviews: [hstack, table, log])
        vstack.axis = .vertical
        vstack.spacing = 12

        view.addSubview(vstack)
        vstack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(16)
        }

        table.snp.makeConstraints { make in
            make.height.equalTo(160)
        }
    }

    private func enqueue3() {
        for i in 0..<3 {
            let ep = DemoAPI.postJSON(path: "/post", json: ["idx":"\(i)","ts":"\(Date().timeIntervalSince1970)"])
            tasks.append(DemoOfflineTask(endpoint: ep))
        }
        table.reloadData()
        log.append("已加入 \(tasks.count) 个任务")
    }

    private func flush() {
        Task { @MainActor in
            guard !tasks.isEmpty else { log.append("队列为空"); return }
            var ok = 0, fail = 0
            for t in tasks {
                do {
                    let _: Data = try await DemoNetwork.shared.client.request(t.endpoint, as: Data.self)
                    ok += 1
                } catch { fail += 1 }
            }
            tasks.removeAll()
            table.reloadData()
            log.append("发送完成：成功 \(ok)，失败 \(fail)")
        }
    }

    // UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { tasks.count }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = tasks[indexPath.row].endpoint.path
        cell.contentConfiguration = cfg
        return cell
    }
}
