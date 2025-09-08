import Foundation
import Alamofire
public struct LWPinningSet: Codable { public let domain: String; public let primary: [Data]; public let backup: [Data] }
public typealias LWPinningSets = [String: LWPinningSet]
public enum LWPinningProvider { public static func loadLocalConfig() throws -> LWPinningSets { guard let url = Bundle.main.url(forResource: "pinning", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [:] } ; let d = JSONDecoder(); d.dataDecodingStrategy = .base64 ; let arr = try d.decode([LWPinningSet].self, from: data); var map: LWPinningSets = [:]; for s in arr { map[s.domain] = s } ; return map } }
