
/*
 作用：演示 SSE 与 WebSocket（若 LWNetwork 暴露 LWEventSource/LWWebSocket）。
 使用示例：
   SSEWebSocketDemoView()
*/
import SwiftUI
import LWToolKit

public struct SSEWebSocketDemoView: View {
    @State private var logs: [String] = []
    public init() {}
    public var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("连接 SSE") { connectSSE() }
                Button("连接 WS") { connectWS() }
            }
            ScrollView {
                Text(logs.joined(separator: "\n"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
            }
        }.padding().navigationTitle("SSE / WebSocket")
    }

    private func connectSSE() {
        let url = AppEnvironment.current.baseURL.appendingPathComponent("/events")
        let es = LWEventSource(url: url, headers: [:], onEvent: { event in
            logs.append("SSE: \(event.event) -> \(event.data)")
        }, onOpen: {
            logs.append("SSE opened")
        }, onError: { err in
            logs.append("SSE error: \(err.localizedDescription)")
        })
        es.connect()
    }

    private func connectWS() {
        let url = AppEnvironment.current.baseURL.appendingPathComponent("/ws")
        let ws = LWWebSocket(url: url, headers: [:], keepAliveInterval: 20)
        ws.onOpen = { logs.append("WS opened") }
        ws.onText = { text in logs.append("WS <= \(text)") }
        ws.onData = { data in logs.append("WS <= \(data.count) bytes") }
        ws.onError = { err in logs.append("WS error: \(err.localizedDescription)") }
        ws.onClose = { code, reason in
            logs.append("WS closed code=\(code?.rawValue ?? -1) reason=\(reason.flatMap { String(data: $0, encoding: .utf8) } ?? "-")")
        }
        ws.connect()
        Task { try? await ws.send("hello") }
    }
}
