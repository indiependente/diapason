import Foundation

/// One audio item from Jellyfin.
struct Track: Identifiable, Hashable, Sendable, Decodable {
    /// Jellyfin stores durations as 100 ns ticks.
    static let ticksPerSecond: Double = 10_000_000

    let id: String
    let title: String
    let artist: String
    let album: String
    let albumID: String?
    let trackNumber: Int?
    let duration: TimeInterval
    /// The item that has the primary image: the track itself, or its album.
    let artworkItemID: String?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case title = "Name"
        case artists = "Artists"
        case album = "Album"
        case albumID = "AlbumId"
        case trackNumber = "IndexNumber"
        case runTimeTicks = "RunTimeTicks"
        case imageTags = "ImageTags"
        case albumPrimaryImageTag = "AlbumPrimaryImageTag"
    }

    init(
        id: String,
        title: String,
        artist: String,
        album: String = "",
        albumID: String? = nil,
        trackNumber: Int? = nil,
        duration: TimeInterval = 0,
        artworkItemID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumID = albumID
        self.trackNumber = trackNumber
        self.duration = duration
        self.artworkItemID = artworkItemID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent([String].self, forKey: .artists)?.joined(separator: ", ") ?? ""
        album = try container.decodeIfPresent(String.self, forKey: .album) ?? ""
        albumID = try container.decodeIfPresent(String.self, forKey: .albumID)
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .trackNumber)
        let ticks = try container.decodeIfPresent(Double.self, forKey: .runTimeTicks) ?? 0
        duration = ticks / Self.ticksPerSecond
        let tags = try container.decodeIfPresent([String: String].self, forKey: .imageTags) ?? [:]
        if tags["Primary"] != nil {
            artworkItemID = id
        } else if try container.decodeIfPresent(String.self, forKey: .albumPrimaryImageTag) != nil {
            artworkItemID = albumID
        } else {
            artworkItemID = nil
        }
    }
}

extension TimeInterval {
    /// Formats a duration as "m:ss", or "h:mm:ss" when it is one hour or longer.
    var trackFormatted: String {
        let total = Int(rounded(.down))
        let seconds = total % 60
        let minutes = total / 60 % 60
        let hours = total / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%d:%02d", minutes, seconds)
    }
}
