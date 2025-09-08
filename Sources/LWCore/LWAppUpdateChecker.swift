import Foundation
public enum LWAppUpdateChecker {
    public struct Result { public let latest: String; public let needsForce: Bool }
    public static func check(bundleId: String, forceBelow: String? = nil) async -> Result? {
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleId)"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let latest = results.first?["version"] as? String else { return nil }
        let needsForce = (forceBelow.map { $0.compare(latest, options: .numeric) == .orderedAscending } ?? false)
        return Result(latest: latest, needsForce: needsForce)
    }
}
