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
    /// The album artist when the server has one, else the first track artist.
    let artistID: String?
    let trackNumber: Int?
    let duration: TimeInterval
    /// The item that has the primary image: the track itself, or its album.
    let artworkItemID: String?
    let media: MediaInfo?

    private enum CodingKeys: CodingKey {
        case id, name, artists, album, albumId, albumArtists, artistItems, indexNumber, runTimeTicks, imageTags
        case albumPrimaryImageTag, mediaSources
    }

    init(
        id: String,
        title: String,
        artist: String,
        album: String = "",
        albumID: String? = nil,
        artistID: String? = nil,
        trackNumber: Int? = nil,
        duration: TimeInterval = 0,
        artworkItemID: String? = nil,
        media: MediaInfo? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumID = albumID
        self.artistID = artistID
        self.trackNumber = trackNumber
        self.duration = duration
        self.artworkItemID = artworkItemID
        self.media = media
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .name)
        artist = try container.decodeIfPresent([String].self, forKey: .artists)?.joined(separator: ", ") ?? ""
        album = try container.decodeIfPresent(String.self, forKey: .album) ?? ""
        albumID = try container.decodeIfPresent(String.self, forKey: .albumId)
        let albumArtists = try container.decodeIfPresent([NamedItem].self, forKey: .albumArtists) ?? []
        let artistItems = try container.decodeIfPresent([NamedItem].self, forKey: .artistItems) ?? []
        artistID = (albumArtists.first ?? artistItems.first)?.id
        trackNumber = try container.decodeIfPresent(Int.self, forKey: .indexNumber)
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
        let sources = try container.decodeIfPresent([MediaSource].self, forKey: .mediaSources) ?? []
        media = sources.first.flatMap(MediaInfo.init)
    }
}

/// Codec details of the file behind a track.
struct MediaInfo: Hashable, Sendable {
    let codec: String
    /// Bits per second.
    let bitrate: Int?
    /// Hz.
    let sampleRate: Int?
    let bitDepth: Int?

    init(codec: String, bitrate: Int? = nil, sampleRate: Int? = nil, bitDepth: Int? = nil) {
        self.codec = codec
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
    }

    fileprivate init?(source: MediaSource) {
        guard let stream = source.mediaStreams?.first(where: { $0.type == "Audio" }) else {
            return nil
        }
        codec = stream.codec ?? source.container ?? "?"
        bitrate = stream.bitRate ?? source.bitrate
        sampleRate = stream.sampleRate
        bitDepth = stream.bitDepth
    }

    var kbps: Int? {
        bitrate.map { $0 / 1000 }
    }

    /// "FLAC 24/96", "MP3 44.1 kHz", or "AAC".
    var format: String {
        let name = codec.uppercased()
        guard let sampleRate else {
            return name
        }
        let khz = String(format: "%g", Double(sampleRate) / 1000)
        if let bitDepth {
            return "\(name) \(bitDepth)/\(khz)"
        }

        return "\(name) \(khz) kHz"
    }

    /// "FLAC 24/96 · 2747 kbps"
    var summary: String {
        [format, kbps.map { "\($0) kbps" }].compactMap(\.self).joined(separator: " · ")
    }
}

private struct NamedItem: Decodable {
    let id: String
    let name: String
}

private struct MediaSource: Decodable {
    let container: String?
    let bitrate: Int?
    let mediaStreams: [MediaStream]?
}

private struct MediaStream: Decodable {
    let type: String
    let codec: String?
    let bitRate: Int?
    let sampleRate: Int?
    let bitDepth: Int?
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
