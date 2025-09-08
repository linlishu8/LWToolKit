import Foundation
import UIKit

/// Lightweight async image loader with in-memory caching.
public final class LWImageLoader {
    public static let shared = LWImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
        // Reasonable defaults for lightweight caching
        cache.countLimit = 512         // up to 512 images (adjust as needed)
        cache.totalCostLimit = 64 * 1_024 * 1_024 // ~64MB (rough heuristic)
    }

    /// Loads an image from URL. Uses memory cache by default.
    /// - Parameters:
    ///   - url: remote or file URL
    ///   - useCache: consult and populate memory cache
    /// - Returns: decoded UIImage
    public func load(from url: URL, useCache: Bool = true) async throws -> UIImage {
        let key = url as NSURL

        if useCache, let cached = cache.object(forKey: key) {
            return cached
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            // local file or non-HTTP response is fine; just decode
            if let img = UIImage(data: data, scale: UIScreen.main.scale) {
                if useCache { cache.setObject(img, forKey: key, cost: data.count) }
                return img
            }
            throw ImageLoaderError.decodeFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ImageLoaderError.httpStatus(code: http.statusCode)
        }
        guard let img = UIImage(data: data, scale: UIScreen.main.scale) else {
            throw ImageLoaderError.decodeFailed
        }
        if useCache { cache.setObject(img, forKey: key, cost: data.count) }
        return img
    }

    /// Remove one image from cache.
    public func removeCached(for url: URL) {
        cache.removeObject(forKey: url as NSURL)
    }

    /// Clear all cached images.
    public func removeAllCached() {
        cache.removeAllObjects()
    }

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
}