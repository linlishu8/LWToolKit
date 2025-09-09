
//
//  HTTPBasicsViewController.swift
//
/*
 作用：
   演示基础请求：GET + Query、POST + JSON、Headers、Void（204）。
 使用示例：
   进入页面后依次点击按钮观察日志输出。若需替换域名，修改 DemoAPI.httpBase。
*/

import UIKit
import Alamofire
import LWToolKit
import SnapKit

final class HTTPBasicsViewController: UIViewController {

    private let log = LogView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "HTTP 基础"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let b1 = makeActionButton("GET: /get?foo=bar") { [weak self] in self?.doGet() }
        let b2 = makeActionButton("POST JSON: /post {hello:world}") { [weak self] in self?.doPost() }
        let b3 = makeActionButton("自定义 Header: X-Demo:1") { [weak self] in self?.doHeaders() }
        let b4 = makeActionButton("Void 请求（/status/204）") { [weak self] in self?.doVoid() }

        [b1,b2,b3,b4].forEach { stack.addArrangedSubview($0) }
        stack.addArrangedSubview(log)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func doGet() {
        Task { @MainActor in
            let ep = DemoAPI.get(path: "/get", query: ["foo":"bar"])
            struct Res: Decodable { let args: [String:String]; let url: String }
            do {
                let r: Res = try await DemoNetwork.shared.client.request(ep, as: Res.self)
                log.append("GET 成功\nargs=\(r.args)\nurl=\(r.url)")
            } catch {
                log.append("GET 失败: \(error)")
            }
        }
    }

    private func doPost() {
        Task { @MainActor in
            let ep = DemoAPI.postJSON(path: "/post", json: ["hello":"world"])
            struct Res: Decodable { let json: [String:String]?; let url: String }
            do {
                let r: Res = try await DemoNetwork.shared.client.request(ep, as: Res.self)
                log.append("POST 成功\njson=\(r.json ?? [:])\nurl=\(r.url)")
            } catch {
                log.append("POST 失败: \(error)")
            }
        }
    }

    private func doHeaders() {
        Task { @MainActor in
            let ep = DemoAPI.get(path: "/get", query: [:], headers: ["X-Demo":"1"])
            struct Res: Decodable { let headers: [String:String] }
            do {
                let r: Res = try await DemoNetwork.shared.client.request(ep, as: Res.self)
                let xs = r.headers.filter { $0.key.hasPrefix("X-") }
                log.append("Header 成功：\(xs)")
            } catch {
                log.append("Header 失败: \(error)")
            }
        }
    }

    private func doVoid() {
        Task { @MainActor in
            let ep = DemoAPI.void(path: "/status/204", method: .get)
            do {
                try await DemoNetwork.shared.client.requestVoid(ep)
                log.append("Void 成功 (204)")
            } catch {
                log.append("Void 失败: \(error)")
            }
        }
    }
}
