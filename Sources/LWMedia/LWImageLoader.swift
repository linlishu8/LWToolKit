import Foundation
import UIKit
import ImageIO

/**
 LWImageLoader
 ----------------
 作用：
 一个**轻量的异步图片加载器**，带内存缓存（`NSCache`）与可选**降采样**（大图节省内存）。
 支持：内存缓存命中、HTTP/本地文件加载、主线程安全解码、取消（随 Task 取消）、
 以及预取与缓存清理。

 使用示例：
 ```swift
 // 1) 基本加载（含内存缓存）
 if #available(iOS 14.0, *) {
     let img = try await LWImageLoader.shared.load(from: url)
 }

 // 2) 指定目标像素尺寸进行降采样（避免一次性解码超大图）
 let avatar = try await LWImageLoader.shared.load(from: url, downsampleTo: CGSize(width: 200, height: 200))

 // 3) 预取（不关心返回值，只想把图放进缓存）
 await LWImageLoader.shared.prefetch([url1, url2, url3])

 // 4) 缓存管理
 LWImageLoader.shared.removeCached(for: url)
 LWImageLoader.shared.removeAllCached()
 ```

 注意事项：
 - `load(from:)` 可被**取消**：若外部 Task 被取消，将尽快停止并抛出取消。
 - 解码与 `UIScreen.main.scale` 访问在 **MainActor** 上执行，避免线程不安全调用。
 - 建议配合 `URLCache`（参见 `LWURLCache`）提升网络缓存命中率。
 */
@available(iOS 14.0, *)
public final class LWImageLoader {

    // MARK: - Singleton
    public static let shared = LWImageLoader()

    // MARK: - Dependencies
    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    // MARK: - Init
    public init(session: URLSession = .shared) {
        self.session = session
        // Reasonable defaults for lightweight caching
        cache.countLimit = 512                     // up to 512 images (adjust as needed)
        cache.totalCostLimit = 64 * 1_024 * 1_024  // ~64MB (rough heuristic)
    }

    // MARK: - Public API

    /// 加载图片（带内存缓存与可选降采样）
    /// - Parameters:
    ///   - url: 远程或本地 URL
    ///   - useCache: 是否读写内存缓存（默认 true）
    ///   - downsampleTo: 目标像素尺寸；传 nil 则全尺寸解码
    /// - Returns: 解码后的 UIImage
    public func load(from url: URL,
                     useCache: Bool = true,
                     downsampleTo targetPixelSize: CGSize? = nil) async throws -> UIImage {

        let key = cacheKey(for: url, target: targetPixelSize)
        if useCache, let cached = cache.object(forKey: key) {
            return cached
        }

        // 网络/文件加载
        try Task.checkCancellation()
        let (data, response) = try await session.data(from: url)

        try Task.checkCancellation()

        // 取屏幕 scale 与构造 UIImage 都在 MainActor 上执行
        let scale = await MainActor.run { UIScreen.main.scale }

        // 非 HTTP 响应：直接解码
        if (response as? HTTPURLResponse) == nil {
            guard let img = await decodeImage(data: data, scale: scale, target: targetPixelSize) else {
                throw ImageLoaderError.decodeFailed
            }
            if useCache { cache.setObject(img, forKey: key, cost: data.count) }
            return img
        }

        // 校验 HTTP 状态
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImageLoaderError.httpStatus(code: http.statusCode)
        }

        guard let img = await decodeImage(data: data, scale: scale, target: targetPixelSize) else {
            throw ImageLoaderError.decodeFailed
        }
        if useCache { cache.setObject(img, forKey: key, cost: data.count) }
        return img
    }

    /// 预取一组图片（忽略错误）
    public func prefetch(_ urls: [URL], downsampleTo targetPixelSize: CGSize? = nil) async {
        await withTaskGroup(of: Void.self) { group in
            for u in urls {
                group.addTask { [weak self] in
                    _ = try? await self?.load(from: u, useCache: true, downsampleTo: targetPixelSize)
                }
            }
        }
    }

    /// 从缓存中移除某个 URL 的图片（注意：不同降采样尺寸视为不同缓存键）
    public func removeCached(for url: URL, targetPixelSize: CGSize? = nil) {
        let key = cacheKey(for: url, target: targetPixelSize)
        cache.removeObject(forKey: key)
    }

    /// 清空所有缓存图片
    public func removeAllCached() {
        cache.removeAllObjects()
    }

    // MARK: - Errors

    public enum ImageLoaderError: Error, LocalizedError {
        case httpStatus(code: Int)
        case decodeFailed

        public var errorDescription: String? {
            switch self {
            case .httpStatus(let code): return "HTTP status \(code)"
            case .decodeFailed: return "Failed to decode image data"
            }
        }
    }

    // MARK: - Helpers

    private func cacheKey(for url: URL, target: CGSize?) -> NSURL {
        if let t = target, t != .zero {
            // 把尺寸拼到 key，避免不同目标尺寸之间相互污染
            let key = url.absoluteString + "#\(Int(t.width))x\(Int(t.height))"
            return NSURL(string: key) ?? (url as NSURL)
        }
        return url as NSURL
    }

    private func decodeImage(data: Data, scale: CGFloat, target: CGSize?) async -> UIImage? {
        // 若指定了目标像素尺寸，则做降采样；否则全尺寸解码
        if let target = target, target != .zero {
            return downsampledImage(from: data, scale: scale, targetPixelSize: target)
        } else {
            return await MainActor.run { UIImage(data: data, scale: scale) }
        }
    }

    /// 使用 ImageIO 对大图进行降采样，避免一次性解码超大像素导致内存暴涨
    private func downsampledImage(from data: Data, scale: CGFloat, targetPixelSize: CGSize) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false, // 延迟解码到缩略阶段
            kCGImageSourceShouldCacheImmediately: false
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else { return nil }

        // 目标像素（考虑屏幕 scale）
        let maxDimInPixels = max(targetPixelSize.width, targetPixelSize.height) * scale
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimInPixels)
        ]

        guard let cgimg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgimg, scale: scale, orientation: .up)
    }
}
