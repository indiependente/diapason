import Foundation

enum JellyfinError: Error, Equatable, LocalizedError {
    case invalidURL
    case unauthorized
    case notSignedIn
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: "The server address is not a valid URL."
        case .unauthorized: "The server rejected the credentials."
        case .notSignedIn: "Sign in to a Jellyfin server first."
        case let .http(code): "The server returned HTTP \(code)."
        }
    }
}
