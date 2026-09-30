import Foundation
import Observation

/// The signed-in server and the collections it offers.
@Observable
@MainActor
final class Library {
    static let credentialsKey = "credentials"

    private(set) var client: JellyfinClient?
    private(set) var credentials: Credentials?
    private(set) var playlists: [MusicCollection] = []
    private(set) var albums: [MusicCollection] = []
    private(set) var artists: [Artist] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let store: any SecretStore
    private let deviceID: String
    private let session: URLSession

    init(store: any SecretStore, deviceID: String = Library.persistentDeviceID(), session: URLSession = .shared) {
        self.store = store
        self.deviceID = deviceID
        self.session = session
        if let stored = try? store.json(Credentials.self, for: Self.credentialsKey) {
            credentials = stored
            client = JellyfinClient(credentials: stored, deviceID: deviceID, session: session)
        }
    }

    var isSignedIn: Bool {
        client != nil
    }

    func signIn(server: String, username: String, password: String) async {
        guard let url = URL(string: server.trimmingCharacters(in: .whitespaces)), url.host() != nil else {
            errorMessage = JellyfinError.invalidURL.localizedDescription

            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let anonymous = JellyfinClient(server: url, deviceID: deviceID, session: session)
            let stored = try await anonymous.authenticate(username: username, password: password)
            try store.setJSON(stored, for: Self.credentialsKey)
            credentials = stored
            client = JellyfinClient(credentials: stored, deviceID: deviceID, session: session)
            errorMessage = nil
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        try? store.delete(key: Self.credentialsKey)
        credentials = nil
        client = nil
        playlists = []
        albums = []
        artists = []
    }

    func refresh() async {
        guard let client else {
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            async let playlists = client.playlists()
            async let albums = client.albums()
            async let artists = client.artists()
            (self.playlists, self.albums, self.artists) = try await (playlists, albums, artists)
            errorMessage = nil
        } catch JellyfinError.unauthorized {
            signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func albums(by artist: Artist) async throws -> [MusicCollection] {
        guard let client else {
            throw JellyfinError.notSignedIn
        }

        return try await client.albums(by: artist)
    }

    func tracks(in collection: MusicCollection) async throws -> [Track] {
        guard let client else {
            throw JellyfinError.notSignedIn
        }

        return try await client.tracks(in: collection)
    }

    func artworkURL(for itemID: String?, size: Int) -> URL? {
        guard let itemID, let client else {
            return nil
        }

        return client.imageURL(for: itemID, size: size)
    }

    /// Jellyfin keys sessions by device, so the ID must survive relaunches.
    static func persistentDeviceID() -> String {
        let key = "deviceID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)

        return fresh
    }
}
