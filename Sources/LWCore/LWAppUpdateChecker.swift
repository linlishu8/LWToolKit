import Foundation

/**
 LWAppUpdateChecker
 ----------------
 作用：
 通过 Apple 的 App Store Lookup 接口（按 bundleId 查询）获取**最新上架版本号**、商店链接与更新说明，
 并结合「当前安装版本」与可选的最低支持版本 `forceBelow` 计算：
 1) `needsUpdate`：是否有可更新（当前版本 < 最新版本）；
 2) `needsForce`：是否需要强制更新（当前版本 < forceBelow）。

 使用示例：
 ```swift
 Task {
     let bundleId = Bundle.main.bundleIdentifier ?? "com.example.app"
     let minSupported = "3.2.0"   // 低于该版本强更，可按需从远端配置获取
     let country = "sg"           // 可选：指定上架区域

     if let r = await LWAppUpdateChecker.check(bundleId: bundleId,
                                               forceBelow: minSupported,
                                               country: country) {
         if r.needsForce {
             // 强制更新：弹不可关闭弹窗，点击跳转 r.trackViewURL
         } else if r.needsUpdate {
             // 可选更新：提示用户升级到 r.latest，可展示 r.releaseNotes
         } else {
             // 已是最新
         }
     }
 }
 ```

 注意事项：
 - 版本比较使用 `.numeric`，适用于 "1.2.10" vs "1.2.2" 之类的语义；若包含后缀（beta/rc），建议先规整版本字符串。
 - `needsForce` 仅与 *当前安装版本* 和 `forceBelow` 比较，与 App Store 最新版本无直接关系。
 - Lookup 接口可能返回空结果（包名错误、区域未上架等），需处理返回 `nil` 的情况。
 */
public enum LWAppUpdateChecker {

    // MARK: - Public Models

    public struct Result {
        /// App Store 最新版本号
        public let latest: String
        /// 是否需要强制更新（当前安装版本 < forceBelow）
        public let needsForce: Bool
        /// 是否存在可更新（当前安装版本 < 最新版本）
        public let needsUpdate: Bool
        /// App Store 详情页链接（可直接打开）
        public let trackViewURL: URL?
        /// 更新说明（可能为空）
        public let releaseNotes: String?
        /// App 的 trackId（数值 ID，调试或跳商店可用）
        public let appId: Int?
    }

    // MARK: - Public API

    /// 查询 App Store 最新版本，并计算是否需要强更与可更新
    /// - Parameters:
    ///   - bundleId: 要查询的应用 bundleId（默认取 `Bundle.main.bundleIdentifier`）
    ///   - forceBelow: 最低支持版本；当当前安装版本 < `forceBelow` 时判定为强更
    ///   - country: 上架地区（如 "sg"、"us"、"cn"）。不传则由苹果按默认地区返回
    /// - Returns: 查询结果；失败返回 `nil`
    public static func check(
        bundleId: String = (Bundle.main.bundleIdentifier ?? ""),
        forceBelow: String? = nil,
        country: String? = nil
    ) async -> Result? {

        guard let url = makeLookupURL(bundleId: bundleId, country: country) else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let lookup = try JSONDecoder().decode(LookupResponse.self, from: data)
            guard let app = lookup.results.first, !app.version.isEmpty else { return nil }

            let current = currentVersion
            let latest = app.version

            let needsUpdate: Bool = {
                guard let cur = current else { return true } // 未能读到当前版本，保守认为可更新
                return isVersion(cur, lessThan: latest)
            }()

            let needsForce: Bool = {
                guard let min = forceBelow, let cur = current else { return false }
                return isVersion(cur, lessThan: min)
            }()

            return Result(
                latest: latest,
                needsForce: needsForce,
                needsUpdate: needsUpdate,
                trackViewURL: app.trackViewUrl.flatMap(URL.init(string:)),
                releaseNotes: app.releaseNotes,
                appId: app.trackId
            )
        } catch {
            return nil
        }
    }

    /// 当前安装版本（CFBundleShortVersionString）
    public static var currentVersion: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    // MARK: - Private

    private static func makeLookupURL(bundleId: String, country: String?) -> URL? {
        var comps = URLComponents()
        comps.scheme = "https"
        comps.host = "itunes.apple.com"
        comps.path = "/lookup"
        var items = [URLQueryItem(name: "bundleId", value: bundleId)]
        if let c = country, !c.isEmpty {
            items.append(URLQueryItem(name: "country", value: c))
        }
        comps.queryItems = items
        return comps.url
    }

    /// 采用 `.numeric` 的字符串比较；支持 "1.2.10" vs "1.2.2"
    private static func isVersion(_ a: String, lessThan b: String) -> Bool {
        a.compare(b, options: .numeric) == .orderedAscending
    }

    // MARK: - Lookup Models

    private struct LookupResponse: Decodable {
        let resultCount: Int
        let results: [AppInfo]
    }

    private struct AppInfo: Decodable {
        let trackId: Int?
        let version: String
        let trackViewUrl: String?
        let releaseNotes: String?
    }
}
