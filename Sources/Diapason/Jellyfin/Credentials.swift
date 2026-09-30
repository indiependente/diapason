import Foundation

/// A signed-in Jellyfin user. Stored by a `SecretStore`.
struct Credentials: Codable, Equatable, Sendable {
    let server: URL
    let username: String
    let userID: String
    let token: String
}
