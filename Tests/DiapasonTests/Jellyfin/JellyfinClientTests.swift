@testable import Diapason
import Foundation
import Testing

@Suite("JellyfinClient", .serialized)
struct JellyfinClientTests {
    let server = URL(string: "http://jelly.local:8096")! // swiftlint:disable:this force_unwrapping

    var client: JellyfinClient {
        JellyfinClient(
            server: server,
            deviceID: "dev-1",
            userID: "u1",
            token: "tok",
            session: StubURLProtocol.session()
        )
    }

    @Test("stream URL carries the token and the item ID")
    func streamURL() throws {
        let url = client.streamURL(for: Track(id: "t9", title: "x", artist: "y"))
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/Audio/t9/universal")
        let items = try #require(components.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
        #expect(query["ApiKey"] == "tok")
        #expect(query["UserId"] == "u1")
        #expect(query["DeviceId"] == "dev-1")
        #expect(query["Container"]?.contains("flac") == true)
    }

    @Test("image URL points at the item's primary image")
    func imageURL() {
        let url = client.imageURL(for: "a1", size: 300)
        #expect(url
            .absoluteString == "http://jelly.local:8096/Items/a1/Images/Primary?maxHeight=300&maxWidth=300&quality=90")
    }

    @Test("authorization header follows the MediaBrowser scheme")
    func authorizationHeader() {
        #expect(client.authorization.hasPrefix("MediaBrowser Client=\"Diapason\", Device=\"Mac\", DeviceId=\"dev-1\""))
        #expect(client.authorization.hasSuffix("Token=\"tok\""))
        let anonymous = JellyfinClient(server: server, deviceID: "dev-1")
        #expect(!anonymous.authorization.contains("Token"))
    }

    @Test("playlists sends an authenticated Items query and decodes the page")
    func playlists() async throws {
        StubURLProtocol.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            #expect(components?.path == "/Items")
            #expect(components?.queryItems?.contains(URLQueryItem(name: "IncludeItemTypes", value: "Playlist")) == true)
            #expect(components?.queryItems?.contains(URLQueryItem(name: "UserId", value: "u1")) == true)
            #expect(request.value(forHTTPHeaderField: "Authorization")?.contains("Token=\"tok\"") == true)

            return (200, Data(#"{"Items":[{"Id":"p1","Name":"Mix","Type":"Playlist"}],"TotalRecordCount":1}"#.utf8))
        }
        let playlists = try await client.playlists()
        #expect(playlists.map(\.name) == ["Mix"])
    }

    @Test("playlist tracks use the Playlists endpoint, album tracks use ParentId")
    func tracks() async throws {
        StubURLProtocol.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            if components?.path == "/Playlists/p1/Items" {
                return (200, Data(#"{"Items":[{"Id":"t1","Name":"One"}]}"#.utf8))
            }
            let byParent = components?.queryItems?.contains(URLQueryItem(name: "ParentId", value: "a1")) == true
            if components?.path == "/Items", byParent {
                return (200, Data(#"{"Items":[{"Id":"t2","Name":"Two"}]}"#.utf8))
            }

            return (404, Data())
        }
        let fromPlaylist = try await client.tracks(in: MusicCollection(id: "p1", name: "P", kind: .playlist))
        let fromAlbum = try await client.tracks(in: MusicCollection(id: "a1", name: "A", kind: .album))
        #expect(fromPlaylist.map(\.id) == ["t1"])
        #expect(fromAlbum.map(\.id) == ["t2"])
    }

    @Test("artists come from the album artists endpoint, albums by artist filter on ArtistIds")
    func artists() async throws {
        StubURLProtocol.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            if components?.path == "/Artists/AlbumArtists" {
                return (200, Data(#"{"Items":[{"Id":"ar1","Name":"Sting"}]}"#.utf8))
            }
            let byArtist = components?.queryItems?.contains(URLQueryItem(name: "ArtistIds", value: "ar1")) == true
            if components?.path == "/Items", byArtist {
                return (200, Data(#"{"Items":[{"Id":"a1","Name":"Nothing Like The Sun","Type":"MusicAlbum"}]}"#.utf8))
            }

            return (404, Data())
        }
        let artists = try await client.artists()
        #expect(artists.map(\.name) == ["Sting"])
        let albums = try await client.albums(by: artists[0])
        #expect(albums.map(\.id) == ["a1"])
    }

    @Test("searchTracks queries audio items by term with media sources")
    func searchTracks() async throws {
        StubURLProtocol.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            let items = components?.queryItems ?? []
            #expect(components?.path == "/Items")
            #expect(items.contains(URLQueryItem(name: "SearchTerm", value: "let it")))
            #expect(items.contains(URLQueryItem(name: "IncludeItemTypes", value: "Audio")))
            #expect(items.contains(URLQueryItem(name: "Fields", value: "MediaSources")))

            return (200, Data(#"{"Items":[{"Id":"t1","Name":"Let It Happen"}]}"#.utf8))
        }
        let tracks = try await client.searchTracks("let it")
        #expect(tracks.map(\.title) == ["Let It Happen"])
    }

    @Test("track queries ask for media sources")
    func tracksRequestMediaSources() async throws {
        StubURLProtocol.handler = { request in
            let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
            #expect(components?.queryItems?.contains(URLQueryItem(name: "Fields", value: "MediaSources")) == true)

            return (200, Data(#"{"Items":[]}"#.utf8))
        }
        _ = try await client.tracks(in: MusicCollection(id: "p1", name: "P", kind: .playlist))
        _ = try await client.tracks(in: MusicCollection(id: "a1", name: "A", kind: .album))
    }

    @Test("authenticate posts the credentials and returns a session")
    func authenticate() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url?.path() == "/Users/AuthenticateByName")
            let body = try? JSONSerialization.jsonObject(with: request.bodyData ?? Data()) as? [String: String]
            #expect(body == ["Username": "jellyfin", "Pw": "secret"])

            return (200, Data(#"{"User":{"Id":"u1"},"AccessToken":"tok"}"#.utf8))
        }
        let anonymous = JellyfinClient(server: server, deviceID: "dev-1", session: StubURLProtocol.session())
        let credentials = try await anonymous.authenticate(username: "jellyfin", password: "secret")
        #expect(credentials == Credentials(server: server, username: "jellyfin", userID: "u1", token: "tok"))
    }

    @Test("401 maps to unauthorized")
    func unauthorized() async {
        StubURLProtocol.handler = { _ in (401, Data()) }
        await #expect(throws: JellyfinError.unauthorized) {
            try await client.albums()
        }
    }

    @Test("report posts the position in ticks")
    func report() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.url?.path() == "/Sessions/Playing/Progress")
            let body = try? JSONSerialization.jsonObject(with: request.bodyData ?? Data()) as? [String: Any]
            #expect(body?["ItemId"] as? String == "t1")
            #expect(body?["PositionTicks"] as? Int == 15_000_000)
            #expect(body?["IsPaused"] as? Bool == true)

            return (204, Data())
        }
        try await client.report(
            .progress,
            track: Track(id: "t1", title: "x", artist: "y"),
            position: 1.5,
            isPaused: true
        )
    }
}
