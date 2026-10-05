@testable import Diapason
import Foundation
import Testing

@Suite("Library", .serialized)
@MainActor
struct LibraryTests {
    @Test("restores a stored session")
    func restoresSession() throws {
        let store = InMemorySecretStore()
        let stored = try Credentials(
            server: #require(URL(string: "http://jelly.local")),
            username: "me",
            userID: "u1",
            token: "tok"
        )
        try store.setJSON(stored, for: Library.credentialsKey)
        let library = Library(store: store, deviceID: "dev")
        #expect(library.isSignedIn)
        #expect(library.credentials == stored)
    }

    @Test("sign in stores credentials, sign out clears them")
    func signInAndOut() async throws {
        StubURLProtocol.handler = { request in
            switch request.url?.path() {
            case "/Users/AuthenticateByName": (200, Data(#"{"User":{"Id":"u1"},"AccessToken":"tok"}"#.utf8))
            default: (200, Data(#"{"Items":[]}"#.utf8))
            }
        }
        let store = InMemorySecretStore()
        let library = Library(store: store, deviceID: "dev", session: StubURLProtocol.session())
        await library.signIn(server: "http://jelly.local", username: "me", password: "pw")
        #expect(library.isSignedIn)
        #expect(library.errorMessage == nil)
        #expect(try store.json(Credentials.self, for: Library.credentialsKey)?.token == "tok")

        library.signOut()
        #expect(!library.isSignedIn)
        #expect(try store.data(for: Library.credentialsKey) == nil)
    }

    @Test("toggleFavorite flips the heart at once and reverts when the server refuses")
    func toggleFavorite() async throws {
        StubURLProtocol.handler = { request in
            request.url?.path().hasPrefix("/UserFavoriteItems") == true ? (500, Data()) : (
                200,
                Data(#"{"Items":[]}"#.utf8)
            )
        }
        let store = InMemorySecretStore()
        let stored = try Credentials(
            server: #require(URL(string: "http://jelly.local")),
            username: "me",
            userID: "u1",
            token: "tok"
        )
        try store.setJSON(stored, for: Library.credentialsKey)
        let library = Library(store: store, deviceID: "dev", session: StubURLProtocol.session())
        let track = Track(id: "t1", title: "Loved", artist: "x")
        library.toggleFavorite(track)
        #expect(library.isFavorite(track))
        try await Task.sleep(for: .milliseconds(300))
        #expect(!library.isFavorite(track))
        #expect(library.errorMessage != nil)
    }

    @Test("album(for:) and artist(for:) fall back to values built from the track")
    func lookups() {
        let library = Library(store: InMemorySecretStore(), deviceID: "dev")
        let track = Track(id: "t1", title: "Song", artist: "Band", album: "Record", albumID: "a1", artistID: "ar1")
        let album = MusicCollection(id: "a1", name: "Record", kind: .album, artist: "Band", artistID: "ar1")
        #expect(library.album(for: track) == album)
        #expect(library.artist(for: track) == Artist(id: "ar1", name: "Band"))
        #expect(library.album(for: Track(id: "t2", title: "x", artist: "y")) == nil)
    }

    @Test("artist(for album:) resolves the album artist, or nil without an artist ID")
    func albumArtist() {
        let library = Library(store: InMemorySecretStore(), deviceID: "dev")
        let album = MusicCollection(id: "a1", name: "Currents", kind: .album, artist: "Tame Impala", artistID: "ar1")
        #expect(library.artist(for: album) == Artist(id: "ar1", name: "Tame Impala"))
        #expect(library.artist(for: MusicCollection(id: "p1", name: "Mix", kind: .playlist)) == nil)
    }

    @Test("all songs load once and stay cached until the library refreshes")
    func allSongsCache() async throws {
        nonisolated(unsafe) var songRequests = 0
        StubURLProtocol.handler = { request in
            let items = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?.queryItems ?? []
            if items.contains(URLQueryItem(name: "SortBy", value: "AlbumArtist,Album,ParentIndexNumber,IndexNumber")) {
                songRequests += 1
            }

            return (200, Data(#"{"Items":[{"Id":"t1","Name":"One"}]}"#.utf8))
        }
        let store = InMemorySecretStore()
        let stored = try Credentials(
            server: #require(URL(string: "http://jelly.local")),
            username: "me",
            userID: "u1",
            token: "tok"
        )
        try store.setJSON(stored, for: Library.credentialsKey)
        let library = Library(store: store, deviceID: "dev", session: StubURLProtocol.session())
        _ = try await library.tracks(in: .allSongs)
        _ = try await library.tracks(in: .allSongs)
        #expect(songRequests == 1)
        await library.refresh()
        _ = try await library.tracks(in: .allSongs)
        #expect(songRequests == 2)
    }

    @Test("rejects a server string without a host")
    func rejectsBadServer() async {
        let library = Library(store: InMemorySecretStore(), deviceID: "dev")
        await library.signIn(server: "not a url", username: "me", password: "pw")
        #expect(!library.isSignedIn)
        #expect(library.errorMessage == JellyfinError.invalidURL.localizedDescription)
    }

    @Test("a rejected token signs the user out on refresh")
    func staleTokenSignsOut() async throws {
        StubURLProtocol.handler = { _ in (401, Data()) }
        let store = InMemorySecretStore()
        let stored = try Credentials(
            server: #require(URL(string: "http://jelly.local")),
            username: "me",
            userID: "u1",
            token: "old"
        )
        try store.setJSON(stored, for: Library.credentialsKey)
        let library = Library(store: store, deviceID: "dev", session: StubURLProtocol.session())
        await library.refresh()
        #expect(!library.isSignedIn)
    }
}
