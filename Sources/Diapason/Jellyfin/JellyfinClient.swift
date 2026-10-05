import Foundation

/// A playback event that the server records for play counts and history.
enum PlaybackEvent: String, Sendable {
    case start = "Sessions/Playing"
    case progress = "Sessions/Playing/Progress"
    case stopped = "Sessions/Playing/Stopped"
}

/// A thin client for the parts of the Jellyfin REST API that Diapason uses.
struct JellyfinClient: Sendable, Equatable {
    static let clientName = "Diapason"
    static let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"

    let server: URL
    let deviceID: String
    let userID: String?
    let token: String?
    let session: URLSession

    init(server: URL, deviceID: String, userID: String? = nil, token: String? = nil, session: URLSession = .shared) {
        self.server = server
        self.deviceID = deviceID
        self.userID = userID
        self.token = token
        self.session = session
    }

    init(credentials: Credentials, deviceID: String, session: URLSession = .shared) {
        self.init(
            server: credentials.server,
            deviceID: deviceID,
            userID: credentials.userID,
            token: credentials.token,
            session: session
        )
    }

    static func == (lhs: JellyfinClient, rhs: JellyfinClient) -> Bool {
        lhs.server == rhs.server && lhs.userID == rhs.userID && lhs.token == rhs.token
    }

    var authorization: String {
        var value = "MediaBrowser Client=\"\(Self.clientName)\", Device=\"Mac\", DeviceId=\"\(deviceID)\", Version=\"\(Self.version)\""
        if let token {
            value += ", Token=\"\(token)\""
        }

        return value
    }

    // MARK: Requests

    func authenticate(username: String, password: String) async throws -> Credentials {
        let response: AuthResponse = try await send(
            request("Users/AuthenticateByName", method: "POST", body: AuthBody(username: username, pw: password))
        )

        return Credentials(server: server, username: username, userID: response.user.id, token: response.accessToken)
    }

    func playlists() async throws -> [MusicCollection] {
        try await items(["IncludeItemTypes": "Playlist", "Recursive": "true", "SortBy": "SortName"])
    }

    func albums() async throws -> [MusicCollection] {
        try await items(["IncludeItemTypes": "MusicAlbum", "Recursive": "true", "SortBy": "SortName"])
    }

    func artists() async throws -> [Artist] {
        try await items(path: "Artists/AlbumArtists", ["SortBy": "SortName"])
    }

    func albums(by artist: Artist) async throws -> [MusicCollection] {
        try await items([
            "IncludeItemTypes": "MusicAlbum",
            "Recursive": "true",
            "ArtistIds": artist.id,
            "SortBy": "ProductionYear,SortName"
        ])
    }

    /// Songs whose title matches the term, across the whole library.
    func searchTracks(_ term: String, limit: Int = 100) async throws -> [Track] {
        try await items([
            "IncludeItemTypes": "Audio",
            "Recursive": "true",
            "SearchTerm": term,
            "Limit": "\(limit)",
            "Fields": "MediaSources"
        ])
    }

    /// Empty when the server has no lyrics for the track.
    func lyrics(for track: Track) async throws -> [LyricLine] {
        do {
            let response: LyricsResponse = try await send(request("Audio/\(track.id)/Lyrics"))

            return response.lyrics
        } catch JellyfinError.http(404) {
            return []
        }
    }

    /// Every song, in artist, album, and track order, so that playing the list plays the library through.
    func allTracks() async throws -> [Track] {
        try await items([
            "IncludeItemTypes": "Audio",
            "Recursive": "true",
            "SortBy": "AlbumArtist,Album,ParentIndexNumber,IndexNumber",
            "Fields": "MediaSources"
        ])
    }

    func favoriteTracks() async throws -> [Track] {
        try await items([
            "IncludeItemTypes": "Audio",
            "Recursive": "true",
            "Filters": "IsFavorite",
            "SortBy": "SortName",
            "Fields": "MediaSources"
        ])
    }

    func setFavorite(_ trackID: String, _ favorite: Bool) async throws {
        let request = try request(
            "UserFavoriteItems/\(trackID)",
            query: ["userId": userID ?? ""],
            method: favorite ? "POST" : "DELETE"
        )
        _ = try await data(for: request)
    }

    func tracks(in collection: MusicCollection) async throws -> [Track] {
        switch collection.kind {
        case .favorites:
            try await favoriteTracks()
        case .allSongs:
            try await allTracks()
        case .playlist:
            try await items(path: "Playlists/\(collection.id)/Items", ["Fields": "MediaSources"])
        case .album:
            try await items([
                "ParentId": collection.id,
                "SortBy": "ParentIndexNumber,IndexNumber,SortName",
                "Fields": "MediaSources"
            ])
        }
    }

    func report(_ event: PlaybackEvent, track: Track, position: TimeInterval, isPaused: Bool) async throws {
        let body = ReportBody(
            itemId: track.id,
            positionTicks: Int64(position * Track.ticksPerSecond),
            isPaused: isPaused
        )
        _ = try await data(for: request(event.rawValue, method: "POST", body: body))
    }

    // MARK: URLs

    /// Direct-plays the container when AVFoundation supports it, else the server transcodes to AAC.
    func streamURL(for track: Track) -> URL {
        url("Audio/\(track.id)/universal", [
            "UserId": userID ?? "",
            "DeviceId": deviceID,
            "ApiKey": token ?? "",
            "Container": "flac,mp3,aac,m4a,alac,wav,aiff",
            "TranscodingContainer": "aac",
            "TranscodingProtocol": "http",
            "AudioCodec": "aac"
        ])
    }

    func imageURL(for itemID: String, size: Int) -> URL {
        url("Items/\(itemID)/Images/Primary", ["maxWidth": "\(size)", "maxHeight": "\(size)", "quality": "90"])
    }

    // MARK: Private

    private func items<T: Decodable>(path: String = "Items", _ query: [String: String]) async throws -> [T] {
        var query = query
        query["UserId"] = userID
        let page: Page<T> = try await send(request(path, query: query))

        return page.items
    }

    private func url(_ path: String, _ query: [String: String]) -> URL {
        var components = URLComponents()
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }

        return components.url(relativeTo: server.appending(path: path))?.absoluteURL ?? server
    }

    private func request(
        _ path: String,
        query: [String: String] = [:],
        method: String = "GET",
        body: (some Encodable)? = nil as String?
    ) throws -> URLRequest {
        var request = URLRequest(url: url(path, query))
        request.httpMethod = method
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = try JSONEncoder.jellyfin.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        try await JSONDecoder.jellyfin.decode(T.self, from: data(for: request))
    }

    private func data(for request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200 ..< 300: return data
        case 401, 403: throw JellyfinError.unauthorized
        default: throw JellyfinError.http(status)
        }
    }
}

// MARK: Wire formats (keys map to PascalCase through JSONEncoder/JSONDecoder.jellyfin)

private struct AuthBody: Encodable {
    let username: String
    let pw: String
}

private struct AuthUser: Decodable {
    let id: String
}

private struct AuthResponse: Decodable {
    let user: AuthUser
    let accessToken: String
}

private struct ReportBody: Encodable {
    let itemId: String
    let positionTicks: Int64
    let isPaused: Bool
    let playMethod = "DirectStream"
    let canSeek = true
}

private struct Page<T: Decodable>: Decodable {
    let items: [T]
}
