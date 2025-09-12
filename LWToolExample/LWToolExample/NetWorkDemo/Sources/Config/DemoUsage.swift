/* 
  作用：端到端示例。
*/
import Foundation
import Alamofire

struct Profile: Decodable { let id: String; let name: String }
struct FeatureFlags: Decodable { let features: [String: Bool] }

func demoUsage() async {
    TestAppNetwork.shared.bootstrap(AppEZConfig.Params(baseURL: "https://api.example.com"))
    let _ = try? await AppAPI.loginPipeline(username: "demo", password: "pass")
    let (profile, flags): (Profile, FeatureFlags) = try! await AppAPI.zip2(
        EZEndpoint(path: "/v1/profile", method: .get, requiresAuth: true, task: .requestPlain),
        EZEndpoint(path: "/v1/flags", method: .get, requiresAuth: true, task: .requestPlain),
        as: (Profile.self, FeatureFlags.self)
    )
    print(profile, flags)
}
