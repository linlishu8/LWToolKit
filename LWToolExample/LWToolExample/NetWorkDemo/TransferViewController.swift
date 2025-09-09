
//
//  TransferViewController.swift
//
/*
 作用：
   演示下载与上传（multipart）。
 使用示例：
   点击“下载 1KB”与“上传 multipart”观察日志输出。
*/

import UIKit
import Alamofire
import LWToolKit
import SnapKit

final class TransferViewController: UIViewController {
    private let log = LogView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "下载 / 上传"
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12

        let b1 = makeActionButton("下载 1KB (/bytes/1024)") { [weak self] in self?.doDownload() }
        let b2 = makeActionButton("上传 multipart (/post)") { [weak self] in self?.doUpload() }

        [b1,b2].forEach { stack.addArrangedSubview($0) }
        stack.addArrangedSubview(log)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func doDownload() {
        Task { @MainActor in
            let ep = DemoAPI.get(path: "/bytes/1024")
            do {
                let url = try await DemoNetwork.shared.client.download(ep)
                let size = (try? Data(contentsOf: url).count) ?? 0
                log.append("下载完成：\(url.lastPathComponent) [\(size) bytes]")
            } catch {
                log.append("下载失败：\(error)")
            }
        }
    }

    private func doUpload() {
        Task { @MainActor in
            // 1) 组装分片（一个文本 + 一个文件Data）
            let textPart = LWMultipartFormData.text(name: "greeting", "hello")
            let fileData = Data("Hello Upload".utf8)
            let filePart = LWMultipartFormData(name: "file",
                                               data: fileData,
                                               fileName: "demo.txt",
                                               mimeType: "text/plain")

            let parts: [LWMultipartFormData] = [textPart, filePart]

            // 2) 用便捷工厂构造 API（覆盖 baseURL 指向 httpbingo）
            let api = LWAPI.uploadMultipart(
                env: .dev,
                baseURL: URL(string: DemoAPI.httpBase),
                path: "/post",
                parts: parts,
                headers: [:],
                requiresAuth: false
            )

            struct R: Decodable { let form: [String:String] }
            do {
                let r: R = try await DemoNetwork.shared.client.request(api, as: R.self)
                log.append("上传成功：form=\(r.form)")
            } catch {
                log.append("上传失败：\(error)")
            }
        }
    }
}
