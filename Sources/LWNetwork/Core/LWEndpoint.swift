import Foundation
import Alamofire
public protocol LWEndpoint { var baseURL: URL { get }; var path: String { get }; var method: HTTPMethod { get }; var task: LWTask { get }; var headers: HTTPHeaders { get }; var cachePolicy: URLRequest.CachePolicy { get }; var requiresAuth: Bool { get } }
public enum LWTask { case requestPlain, requestParameters(Parameters, encoding: ParameterEncoding), requestJSONEncodable(Encodable), uploadMultipart([LWMultipartFormData]), download(destination: DownloadRequest.Destination?) }
public struct LWMultipartFormData { public let name: String; public let data: Data; public let fileName: String?; public let mimeType: String?; public init(name: String, data: Data, fileName: String? = nil, mimeType: String? = nil) { self.name = name; self.data = data; self.fileName = fileName; self.mimeType = mimeType } }
