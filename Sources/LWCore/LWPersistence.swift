import Foundation

/**
 LWPersistence
 ----------------
 作用：
 定义一个**最小可用的通用持久化协议**，抽象出“保存实体”和“读取全部实体”的能力；
 同时提供：
 - 默认扩展：`saveAll(_:)` 批量保存；
 - 类型擦除：`AnyPersistence<Entity>` 便于依赖注入/组合；
 - 内存实现：`InMemoryPersistence<T>` 作为示例与单元测试替身。

 使用示例：
 ```swift
 // 1) 使用内存实现做仓库
 let repo = InMemoryPersistence<String>()
 try repo.save("A")
 try repo.save("B")
 let all = try repo.fetchAll()   // ["A", "B"]

 // 2) 批量保存
 try repo.saveAll(["C", "D"])

 // 3) 通过类型擦除对外暴露（隐藏具体实现）
 let anyRepo: AnyPersistence<String> = AnyPersistence(repo)
 try anyRepo.save("E")
 print(try anyRepo.fetchAll())

 // 4) 自定义实现（例如文件/数据库）
 // struct FileRepo: LWPersistence { ... }
 // let repo2 = AnyPersistence(FileRepo(...))
 ```

 注意事项：
 - 协议含 `associatedtype`，不能直接作为属性类型暴露给外部；如需隐藏实现细节，
   请使用 `AnyPersistence<Entity>` 进行**类型擦除**。
 - 错误处理：示例中提供了 `LWPersistenceError`，实际工程可按需扩展/替换。
 */

// MARK: - Protocol

public protocol LWPersistence {
    associatedtype Entity

    /// 保存一个实体
    func save(_ e: Entity) throws

    /// 读取所有实体
    func fetchAll() throws -> [Entity]
}

// MARK: - Default extension

public extension LWPersistence {

    /// 批量保存（遇到错误立即抛出）
    func saveAll(_ entities: [Entity]) throws {
        for e in entities { try save(e) }
    }
}

// MARK: - Common Error

public enum LWPersistenceError: Error, Equatable {
    case notFound
    case duplicate
    case encodingFailed
    case decodingFailed
    case underlying(String)
}

// MARK: - Type erasure

public struct AnyPersistence<E>: LWPersistence {
    public typealias Entity = E

    private let _save: (E) throws -> Void
    private let _fetchAll: () throws -> [E]

    public init<P: LWPersistence>(_ base: P) where P.Entity == E {
        _save = base.save
        _fetchAll = base.fetchAll
    }

    public init(save: @escaping (E) throws -> Void,
                fetchAll: @escaping () throws -> [E]) {
        _save = save
        _fetchAll = fetchAll
    }

    public func save(_ e: E) throws { try _save(e) }
    public func fetchAll() throws -> [E] { try _fetchAll() }
}

// MARK: - In-memory implementation (thread-safe)

public final class InMemoryPersistence<T>: LWPersistence {
    public typealias Entity = T

    private let queue = DispatchQueue(label: "lw.persistence.memory", attributes: .concurrent)
    private var storage: [T] = []

    public init() {}

    public func save(_ e: T) throws {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.append(e)
        }
    }

    public func fetchAll() throws -> [T] {
        var snapshot: [T] = []
        queue.sync { snapshot = storage }
        return snapshot
    }

    /// 清空存储（测试/调试用）
    public func removeAll() {
        queue.async(flags: .barrier) { [weak self] in
            self?.storage.removeAll()
        }
    }
}
