import Foundation

/// A signed-in Jellyfin user. Stored in the Keychain.
struct Credentials: Codable, Equatable, Sendable {
    let server: URL
    let username: String
    let userID: String
    let token: String
}
