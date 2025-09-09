
//
//  DemoHomeViewController.swift
//
/*
 作用：
   作为 Demo 主页，使用 UITableView 跳转到各功能演示的 ViewController。
 使用示例：
   let vc = DemoHomeViewController()
   navigationController?.pushViewController(vc, animated: true)
*/

import UIKit

final class DemoHomeViewController: UITableViewController {

    private enum Row {
        case http
        case transfer
        case etag
        case retry
        case auth
        case offline
        case sse
        case ws

        var title: String {
            switch self {
            case .http: return "HTTP 基础（GET/POST/Headers/JSON/Void）"
            case .transfer: return "下载 / 上传（multipart）"
            case .etag: return "缓存 / ETag 演示"
            case .retry: return "5xx 重试 / 令牌桶 / 断路器"
            case .auth: return "认证 / 401 刷新重放"
            case .offline: return "离线队列（示例）"
            case .sse: return "SSE（本地模拟）"
            case .ws: return "WebSocket（本地模拟）"
            }
        }

        var controller: UIViewController {
            switch self {
            case .http: return HTTPBasicsViewController()
            case .transfer: return TransferViewController()
            case .etag: return CacheETagViewController()
            case .retry: return RetryResilienceViewController()
            case .auth: return AuthRefreshViewController()
            case .offline: return OfflineQueueViewController()
            case .sse: return SSEDemoViewController()
            case .ws: return WebSocketDemoViewController()
            }
        }
    }

    private let rows: [Row] = [.http, .transfer, .etag, .retry, .auth, .offline, .sse, .ws]

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "LWNetwork Demos"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.tableFooterView = UIView()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rows.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var cfg = cell.defaultContentConfiguration()
        cfg.text = rows[indexPath.row].title
        cell.contentConfiguration = cfg
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let vc = rows[indexPath.row].controller
        navigationController?.pushViewController(vc, animated: true)
    }
}
