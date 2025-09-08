import Foundation

/// A tiny in-memory cache with optional TTL (time-to-live).
/// Thread-safe via a concurrent queue + barrier writes.
public final class LWMemoryCache {
    public static let shared = LWMemoryCache()

    private struct Entry {
        let value: Any
        let expiry: Date?
    }

    private let queue = DispatchQueue(label: "com.lw.memorycache.queue", attributes: .concurrent)
    private var storage: [String: Entry] = [:]

    public init() {}

    /// Store a value for key with optional TTL (seconds). If ttl is nil, it never expires.
    public func set<T>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        let expiry = ttl.map { Date().addingTimeInterval($0) }
        let entry = Entry(value: value, expiry: expiry)
        queue.async(flags: .barrier) { [weak self] in
            self?.storage[key] = entry
        }
    }

    /// Read a typed value for key (returns nil if missing or expired).
    public func value<T>(forKey key: String) -> T? {
        var result: T?
        queue.sync {
            guard let entry = storage[key] else { return }
            if let expiry = entry.expiry, expiry <= Date() {
                // expired; treat as missing
                return
            }
            result = entry.value as? T
        }
        return result
    }

    public func removeValue(forKey key: String) {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeValue(forKey: key)
        }
    }

    public func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }

    /// Remove expired entries now.
    public func purgeExpired() {
        let now = Date()
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.storage = self.storage.filter { _, entry in
                guard let expiry = entry.expiry else { return TrueBool }
                return expiry > now
            }
        }
    }

    /// Current number of (not-yet-purged) entries (may include expired until purge is called).
    public var count: Int {
        var c = 0
        queue.sync { c = storage.count }
        return c
    }

    /// Subscript convenience (no TTL on set).
    public subscript<T>(key: String) -> T? {
        get { value(forKey: key) }
        set {
            if let v = newValue {
                set(v, forKey: key, ttl: nil)
            } else {
                removeValue(forKey: key)
            }
        }
    }
}

/// tiny helper because `true` can't be used as a function in filter above
private let TrueBool = true