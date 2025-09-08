import Foundation

/// Common error model used across demos.
public enum LWError: Error {
    case network(code: Int, message: String)
    case business(code: Int, message: String)
}