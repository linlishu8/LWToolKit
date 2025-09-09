import Foundation

/**
 LWLocalization
 ----------------
 作用：
 一个**轻量的本地化门面**，在 `NSLocalizedString` 基础上提供：
 - 统一入口：`localized(_:)` / 带参数格式化 / 复数（stringsdict）支持；
 - 可配置默认 `tableName` 与 `bundle`（便于框架/模块使用）；
 - 运行时**切换语言**（调试/预览用），无需修改系统语言。

 使用示例：
 ```swift
 // 1) 基本用法（等价于 NSLocalizedString）
 // Localizable.strings: "hello" = "你好";
 let s1 = LWLocalization.localized("hello")

 // 2) 参数格式化（支持 Locale）
 // "welcome_fmt" = "欢迎，%@（第 %d 位）";
 let s2 = LWLocalization.localized("welcome_fmt", "Andy", 3)

 // 3) 复数/数量（配合 .stringsdict）
 // key: "files_count" -> .stringsdict 按数量返回格式串
 let s3 = LWLocalization.localizedPlural("files_count", count: 1)   // "1 file"
 let s4 = LWLocalization.localizedPlural("files_count", count: 5)   // "5 files"

 // 4) 指定资源表与 bundle（适合 framework 内的资源包）
 LWLocalization.setTable("Auth")
 LWLocalization.setBundle(.main) // 或你自定义的资源包

 // 5) 运行时切换语言（仅调试/演示；正式环境请谨慎使用）
 // 传 "zh-Hans" / "en" / "ja" 等；传 nil 恢复系统语言
 LWLocalization.overrideLanguage("zh-Hans")
 let s5 = LWLocalization.localized("hello") // 将优先从 zh-Hans.lproj 中取
 LWLocalization.overrideLanguage(nil)       // 还原
 ```

 注意事项：
 - 复数支持依赖 `.stringsdict`，`localizedPlural` 会去拿 key 对应的格式串并带入 `count`；
   请确保你的 .stringsdict 配置正确（如 "%#@count@"）。
 - `overrideLanguage(_:)` 仅在资源包存在对应 `<lang>.lproj` 时生效；若找不到会回退默认语言。
 - 若你的项目把本地化资源打在独立的 bundle（如 SPM/Framework），请先 `setBundle(...)`。
 */
public enum LWLocalization {

    // MARK: - Config

    /// 默认表名（不设置则为 `nil`，即 Localizable.strings）
    private(set) public static var defaultTable: String? = nil

    /// 默认资源包（默认 `.main`；对框架可手动设置为资源包）
    private(set) public static var defaultBundle: Bundle = .main

    /// 运行时语言覆盖；若设置将优先从该语言对应的 .lproj 加载
    private static var overrideLangBundle: Bundle? = nil

    /// 设置默认表
    public static func setTable(_ table: String?) {
        defaultTable = table
    }

    /// 设置默认资源包
    public static func setBundle(_ bundle: Bundle) {
        defaultBundle = bundle
        // 覆盖语言时也基于新的默认 bundle 计算 lproj
        if overrideLangBundle != nil {
            // 重新构建覆盖 bundle
            _ = rebuildOverrideBundle()
        }
    }

    /// 运行时切换语言（传 nil 恢复系统语言）
    /// - Parameter languageCode: 语言代码，如 "zh-Hans"、"en"，需确保 bundle 中存在对应 lproj
    /// - Returns: 是否切换成功（若对应 lproj 不存在则返回 false 且不生效）
    @discardableResult
    public static func overrideLanguage(_ languageCode: String?) -> Bool {
        guard let code = languageCode, !code.isEmpty else {
            overrideLangBundle = nil
            return true
        }
        guard let b = rebuildOverrideBundle(for: code) else {
            return false
        }
        overrideLangBundle = b
        return true
    }

    // MARK: - Lookup

    /// 取本地化文案（等价于 NSLocalizedString，但支持默认 table/bundle & 语言覆盖）
    public static func localized(_ key: String,
                                 table: String? = nil,
                                 bundle: Bundle? = nil,
                                 value: String? = nil) -> String {
        let b = effectiveBundle(from: bundle)
        let t = table ?? defaultTable
        return NSLocalizedString(key, tableName: t, bundle: b, value: value ?? key, comment: "")
    }

    /// 取本地化并做参数格式化（使用当前 Locale）
    public static func localized(_ key: String,
                                 _ args: CVarArg...,
                                 table: String? = nil,
                                 bundle: Bundle? = nil) -> String {
        let format = localized(key, table: table, bundle: bundle)
        return String(format: format, locale: Locale.current, arguments: args)
    }

    /// 复数/数量形式（需要 .stringsdict 支持）
    public static func localizedPlural(_ key: String,
                                       count: Int,
                                       table: String? = nil,
                                       bundle: Bundle? = nil) -> String {
        let format = localized(key, table: table, bundle: bundle)
        return String.localizedStringWithFormat((format as NSString) as String, count)
    }

    // MARK: - Internal helpers

    private static func effectiveBundle(from custom: Bundle?) -> Bundle {
        if let c = custom { return overrideLangBundle ?? c }
        return overrideLangBundle ?? defaultBundle
    }

    @discardableResult
    private static func rebuildOverrideBundle(for code: String? = nil) -> Bundle? {
        let base = defaultBundle
        let lang = code ?? Locale.preferredLanguages.first ?? "en"
        guard let path = base.path(forResource: lang, ofType: "lproj"),
              let b = Bundle(path: path) else {
            overrideLangBundle = nil
            return nil
        }
        return b
    }
}
