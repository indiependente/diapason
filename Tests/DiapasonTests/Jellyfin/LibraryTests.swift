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
        #expect(library.album(for: track) == MusicCollection(id: "a1", name: "Record", kind: .album, artist: "Band"))
        #expect(library.artist(for: track) == Artist(id: "ar1", name: "Band"))
        #expect(library.album(for: Track(id: "t2", title: "x", artist: "y")) == nil)
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
