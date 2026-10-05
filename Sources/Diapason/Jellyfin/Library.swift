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
    private(set) var favoriteIDs: Set<Track.ID> = []
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
        favoriteIDs = []
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
            async let favorites = client.favoriteTracks()
            (self.playlists, self.albums, self.artists) = try await (playlists, albums, artists)
            favoriteIDs = try await Set(favorites.map(\.id))
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

    func searchTracks(_ term: String) async throws -> [Track] {
        guard let client else {
            throw JellyfinError.notSignedIn
        }

        return try await client.searchTracks(term)
    }

    func tracks(in collection: MusicCollection) async throws -> [Track] {
        guard let client else {
            throw JellyfinError.notSignedIn
        }
        let tracks = try await client.tracks(in: collection)
        if collection.kind == .favorites {
            favoriteIDs = Set(tracks.map(\.id))
        }

        return tracks
    }

    func lyrics(for track: Track) async throws -> [LyricLine] {
        guard let client else {
            throw JellyfinError.notSignedIn
        }

        return try await client.lyrics(for: track)
    }

    func isFavorite(_ track: Track) -> Bool {
        favoriteIDs.contains(track.id)
    }

    /// Flips the heart at once and tells the server; a failed request flips it back.
    func toggleFavorite(_ track: Track) {
        guard let client else {
            return
        }
        let favorite = !favoriteIDs.contains(track.id)
        if favorite {
            favoriteIDs.insert(track.id)
        } else {
            favoriteIDs.remove(track.id)
        }
        Task {
            do {
                try await client.setFavorite(track.id, favorite)
            } catch {
                if favorite {
                    favoriteIDs.remove(track.id)
                } else {
                    favoriteIDs.insert(track.id)
                }
                errorMessage = error.localizedDescription
            }
        }
    }

    /// The loaded album when it is known, else one built from the track so navigation still works.
    func album(for track: Track) -> MusicCollection? {
        guard let albumID = track.albumID else {
            return nil
        }

        return albums.first { $0.id == albumID } ?? MusicCollection(
            id: albumID,
            name: track.album,
            kind: .album,
            artist: track.artist,
            artistID: track.artistID,
            hasArtwork: track.artworkItemID == albumID
        )
    }

    func artist(for track: Track) -> Artist? {
        guard let artistID = track.artistID else {
            return nil
        }

        return artists.first { $0.id == artistID } ?? Artist(id: artistID, name: track.artist)
    }

    /// The loaded artist when it is known, else one built from the album so navigation still works.
    func artist(for album: MusicCollection) -> Artist? {
        guard let artistID = album.artistID else {
            return nil
        }

        return artists.first { $0.id == artistID } ?? Artist(id: artistID, name: album.artist ?? "")
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
