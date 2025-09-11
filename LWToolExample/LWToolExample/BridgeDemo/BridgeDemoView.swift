/*
  作用：最小化 SwiftUI 示例视图，内嵌 WKWebView 并注册 YXTBridge 与 UserPlugin。
  使用示例：
    struct ContentView: View { var body: some View { BridgeDemoView() } }
  特点/注意事项：
    - 为演示方便，加载本地 index.html；替换为你的 http://192.168.0.15:5173/facilityCategory 也可。
*/
import SwiftUI
import WebKit
import LWToolKit

struct BridgeDemoView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator: NSObject { var bridge: LWWebBridge? }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let web = WKWebView(frame: .zero, configuration: config)

        // Bridge
        var cfg = LWBridgeConfig(channelName: "JSBridge", version: "1.0.0")
        cfg.allowedHosts = ["192.168.0.15"]
        cfg.bootstrap = .custom { channel, version in
            return """
            (function(){
              if (window.\(channel)) return;
              const pending = new Map();
              const uid = ()=>'cb_'+Date.now().toString(36)+Math.random().toString(36).slice(2);
              const okit = () => window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers["\(channel)"];
            
              function call(method, params, cb){
                if(!okit()){const e=new Error('no webkit');return typeof cb==='function'?cb({success:false,error:{message:String(e)}}):Promise.reject(e);}
                const parts=String(method||'').split('.'); const module=parts[0]||''; const name=parts[1]||'';
                const id=uid(); const body={id,module,method:name,params:params||{}};
                if(typeof cb==='function'){ pending.set(id,{cb}); okit().postMessage(body); return; }
                return new Promise((resolve,reject)=>{ pending.set(id,{resolve,reject}); okit().postMessage(body); });
              }
              function __nativeDispatch(resp){
                const p=resp&&pending.get(resp.id); if(!p) return; pending.delete(resp.id);
                const payload = resp.error ? {success:false,error:resp.error} : {success:true,data:resp.result};
                if(p.cb) p.cb(payload); else if(payload.success) p.resolve(payload); else p.reject(payload.error||{message:'unknown'});
              }
              window.\(channel) = {
                version: "\(version)",
                ready: (cb)=>{ try{cb&&cb();}catch(e){} },
                loadModule: (_m,cb)=>{ cb&&cb({success:true}); },
                call, __nativeDispatch, _resolve: function(){}
              };
            })();
            """
        }
        cfg.logger = .print
        let bridge = LWWebBridge(webView: web, config: cfg)
        context.coordinator.bridge = bridge
        
        let providers = LWUserPlugin.Providers(
            accessToken: { "yourAccessToken" },
            refreshToken: { "yourRefreshToken" },
            userId: { "u_123" },
            userType: { "member" },
            deviceOS: { "iOS" },
            appVersion: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" },
            acceptLanguage: { Locale.preferredLanguages.first ?? "zh-CN" }
        )
        bridge.register(plugin: LWUserPlugin(providers: providers))

        // Load local demo html
//        if let url = Bundle.main.url(forResource: "index", withExtension: "html") {
//            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
//        }
        web.load(URLRequest(url: URL(string: "http://192.168.0.15:5173/facilityCategory22")!))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
