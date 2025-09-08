import Foundation
public actor LWSessionManager { public static let shared = LWSessionManager(); public private(set) var sessionId = UUID().uuidString }
