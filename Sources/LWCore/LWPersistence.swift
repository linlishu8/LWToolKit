import Foundation
public protocol LWPersistence { associatedtype Entity; func save(_ e: Entity) throws; func fetchAll() throws -> [Entity] }
