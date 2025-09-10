/*
 作用：WKWebView 与 JS 间的桥接核心，负责注入 bootstrap JS、接收消息、路由插件、回传结果。
 使用示例：
 let bridge = YXTBridge(webView: webView, config: YXTBridgeConfig(...))
 bridge.register(plugin: UserPlugin(providers: ...))
 特点/注意事项：
 - iOS13+ 兼容；串行队列处理消息；域名/方法白名单；统一错误响应。
 */
import Foundation
import WebKit

public final class LWWebBridge: NSObject, WKScriptMessageHandler {
    public let webView: WKWebView
    public let config: LWBridgeConfig
    private let registry = BridgeRegistry()
    private let queue = DispatchQueue(label: "com.yxt.bridge.queue")
    private var isInjected = false
    
    public init(webView: WKWebView, config: LWBridgeConfig) {
        self.webView = webView
        self.config = config
        super.init()
        install()
    }
    
    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: config.channelName)
    }
    
    private func install() {
        let ucc = webView.configuration.userContentController
        ucc.add(LWWeakScriptMessageHandler(self), name: config.channelName)
        injectBootstrapIfNeeded()
    }
    
    public func register(plugin: LWBridgePlugin) {
        registry.register(plugin)
    }
    
    private func injectBootstrapIfNeeded() {
        guard !isInjected else { return }
        isInjected = true
        let js = LWWebBridge.bootstrapJS(channel: config.channelName, version: config.version)
        let script = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        webView.configuration.userContentController.addUserScript(script)
        config.logger.log("bootstrap JS injected")
    }
    
    // MARK: - Message Handler
    
    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == config.channelName else { return }
        
        let rawBody: Any = message.body
        let rawHost: String = {
            if let h = message.frameInfo.request.url?.host, !h.isEmpty { return h }
            let h = message.frameInfo.securityOrigin.host
            return h
        }()
        
        queue.async { [weak self] in
            self?._handle(body: rawBody, host: rawHost)
        }
    }
    
    private func _handle(body: Any, host: String) {          // ← 修改点
        // Security: host allowlist（file:// 时 host 为空，直接放行）
        if !host.isEmpty {
            if !config.allowedHosts.isEmpty && !config.allowedHosts.contains(host) {
                respondError(id: nil, error: .forbidden(details: ["host": .init(host)]))
                config.logger.log("reject by host allowlist: \(host)")
                return
            }
        }
        
        // Size guard
        if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []),
           bodyData.count > config.maxPayloadBytes {
            respondError(id: nil, error: .oversizedPayload(size: bodyData.count))
            config.logger.log("reject by size: \(bodyData.count)")
            return
        }
        
        // Parse request
        guard let dict = body as? [String: Any],
              let id = dict["id"] as? String,
              let module = dict["module"] as? String,
              let method = dict["method"] as? String
        else {
            respondError(id: nil, error: .badRequest(message: "invalid body"))
            return
        }
        let params = dict["params"] as? [String: Any]
        let req = LWBridgeRequest(id: id, module: module, method: method,
                                  params: params?.mapValues { LWAnyCodable($0) })
        
        // Method allowlist (optional)
        if let allow = config.methodAllowList, !allow.contains("\(module).\(method)") {
            respondError(id: id, error: .forbidden(details: ["method": .init(method), "module": .init(module)]))
            return
        }
        
        guard let plugin = registry.plugin(for: module), plugin.canHandle(method: method) else {
            respondError(id: id, error: .notFound(module: module, method: method))
            return
        }
        
        config.logger.log("→ \(module).\(method) id=\(id) params=\(String(describing: params))")
        plugin.handle(method: method, params: req.params) { [weak self] result in
            switch result {
            case .success(let value):
                self?.respondSuccess(id: id, result: value)
            case .failure(let err):
                self?.respondError(id: id, error: err)
            }
        }
    }
    
    private func respondSuccess(id: String, result: LWAnyCodable) {
        let resp = LWBridgeResponse(id: id, result: result, error: nil)
        sendToJS(response: resp)
    }
    
    private func respondError(id: String?, error: LWBridgeError) {
        let resp = LWBridgeResponse(id: id ?? "_", result: nil, error: LWBridgeErrorPayload(error: error))
        sendToJS(response: resp)
    }
    
    private func sendToJS(response: LWBridgeResponse) {
        // 仍用 JSONEncoder，但失败时多给点上下文，便于定位哪类字段不兼容
        do {
            let data = try JSONEncoder().encode(response)
            let text = String(data: data, encoding: .utf8) ?? "{}"
            let js = "window.\(config.channelName).__nativeDispatch(\(text));"
            DispatchQueue.main.async { [weak self] in
                self?.webView.evaluateJavaScript(js) { [weak self] _, err in
                    if let err = err { self?.config.logger.log("evaluate JS failed: \(err)") }
                }
            }
        } catch {
            config.logger.log("encode response failed: \(error)")
            // 可选：在 DEBUG 下，把 result/error 简要 dump 出来，定位 Optional / 非 Encodable 字段
        }
    }
}

private extension LWWebBridge {
    static func bootstrapJS(channel: String, version: String) -> String {
        // 提供 Promise & 回调两种风格；维护 pending map
        return #"""
        (function(){
            // 防止重复初始化
            if (window.\#(channel)) { return; }
            
            // 存储待处理的请求
            const pending = new Map();
            
            // 生成唯一ID
            const genId = () => (Date.now().toString(36) + Math.random().toString(36).slice(2, 10));
            
            // 类型检查工具函数
            const isFunction = (f) => typeof f === 'function';
            
            // 检查是否支持webkit消息机制
            const supportsWebKitMessages = () => {
                return window.webkit && 
                       window.webkit.messageHandlers && 
                       window.webkit.messageHandlers["\#(channel)"] &&
                       typeof window.webkit.messageHandlers["\#(channel)"].postMessage === 'function';
            };
        
            /**
             * 调用原生方法
             * @param {string} module - 模块名
             * @param {string} method - 方法名
             * @param {object} params - 参数
             * @param {function} [cb] - 回调函数，可选
             * @returns {Promise|undefined} 如果没有提供回调则返回Promise
             */
            const call = function(module, method, params, cb) {
                // 验证环境支持
                if (!supportsWebKitMessages()) {
                    const error = new Error('WebKit message handler not available');
                    if (isFunction(cb)) {
                        cb(null, error);
                        return;
                    } else {
                        return Promise.reject(error);
                    }
                }
                
                // 参数处理
                if (isFunction(params)) {
                    // 处理参数省略的情况
                    cb = params;
                    params = {};
                }
                params = params || {};
                
                const id = genId();
                const payload = { id, module, method, params };
                const hasCallback = isFunction(cb);
                
                try {
                    if (!hasCallback) {
                        // Promise风格
                        return new Promise((resolve, reject) => {
                            pending.set(id, { resolve, reject });
                            window.webkit.messageHandlers["\#(channel)"].postMessage(payload);
                        });
                    } else {
                        // 回调风格
                        pending.set(id, { cb });
                        window.webkit.messageHandlers["\#(channel)"].postMessage(payload);
                    }
                } catch (error) {
                    console.error('Failed to send message:', error);
                    if (hasCallback) {
                        cb(null, error);
                    } else {
                        return Promise.reject(error);
                    }
                }
            };
        
            /**
             * 处理原生返回的结果
             * @param {object} resp - 响应对象，包含id、result、error
             */
            const dispatch = function(resp) {
                if (!resp || !resp.id) {
                    console.error('Invalid response format:', resp);
                    return;
                }
                
                const item = pending.get(resp.id);
                if (!item) {
                    console.warn('No pending request found for id:', resp.id);
                    return;
                }
                
                // 从pending中移除
                pending.delete(resp.id);
                
                // 处理响应
                if (item.cb) {
                    // 回调风格
                    item.cb(resp.result || null, resp.error || null);
                } else if (resp.error) {
                    // Promise错误
                    item.reject(resp.error);
                } else {
                    // Promise成功
                    item.resolve(resp.result);
                }
            };
        
            // 暴露给window的接口
            window.\#(channel) = {
                version: "\#(version)",
                call: call,
                // 供原生调用的分发方法
                __nativeDispatch: dispatch
            };
        })();
        """#
    }
}
