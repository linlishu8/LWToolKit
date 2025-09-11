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
        guard !isInjected, config.autoInjectBootstrap else { return }
        isInjected = true

        let js: String
        switch config.bootstrap {
        case .defaultNative:
            js = LWWebBridge.defaultBootstrapJS(channel: config.channelName, version: config.version)
        case .custom(let make):
            js = make(config.channelName, config.version)
        }

        let script = WKUserScript(
            source: js,
            injectionTime: config.injectionTime,
            forMainFrameOnly: config.forMainFrameOnly
        )
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
    
    private func _handle(body: Any, host: String) {    
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
  static func defaultBootstrapJS(channel: String, version: String) -> String {
    return #"""
    (function(){
      if (window.\#(channel)) return;
      const pending = new Map();
      const uid = () => 'cb_' + Date.now().toString(36) + Math.random().toString(36).slice(2);
      const okit = () => window.webkit && window.webkit.messageHandlers &&
                         window.webkit.messageHandlers["\#(channel)"];

      function call(method, params, cb){
        if (!okit()) {
          const e = new Error('no webkit');
          return typeof cb==='function' ? cb({success:false,error:{message:String(e)}}) : Promise.reject(e);
        }
        // 兼容 'user.info' → ('user','info')
        const parts = String(method||'').split('.');
        const module = parts[0] || ''; const name = parts[1] || '';
        const id = uid(); const body = { id, module, method: name, params: params || {} };

        if (typeof cb === 'function') {
          pending.set(id, { cb });
          okit().postMessage(body);
          return;
        }
        return new Promise((resolve, reject)=>{
          pending.set(id, { resolve, reject });
          okit().postMessage(body);
        });
      }

      // 原生仍然调用 __nativeDispatch({id,result,error})
      function __nativeDispatch(resp){
        const p = resp && pending.get(resp.id);
        if (!p) return;
        pending.delete(resp.id);
        const payload = resp.error
          ? { success:false, error: resp.error }
          : { success:true,  data:  resp.result };
        if (p.cb) p.cb(payload);
        else if (payload.success) p.resolve(payload);
        else p.reject(payload.error || {message:'unknown error'});
      }

      window.\#(channel) = {
        version: "\#(version)",
        ready: (cb)=>{ try{cb&&cb();}catch(e){} },
        loadModule: (_m, cb)=>{ cb && cb({success:true}); },
        call: call,
        __nativeDispatch: __nativeDispatch, // 原生会调这个
        _resolve: function(){}              // 兼容某些页面存在性检查
      };
    })();
    """#
  }
}
