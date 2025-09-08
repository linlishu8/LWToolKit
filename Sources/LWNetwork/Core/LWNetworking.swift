import Foundation
import Alamofire
public protocol LWNetworking: Sendable { func request<T: Decodable>(_ endpoint: LWEndpoint, as: T.Type) async throws -> T; func requestVoid(_ endpoint: LWEndpoint) async throws; func upload<T: Decodable>(_ endpoint: LWEndpoint, as: T.Type) async throws -> T; func download(_ endpoint: LWEndpoint) async throws -> URL }
