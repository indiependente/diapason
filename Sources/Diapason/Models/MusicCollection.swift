import Foundation

/// A playlist or an album: a named group of tracks.
struct MusicCollection: Identifiable, Hashable, Sendable, Decodable {
    enum Kind: String, Sendable, Decodable {
        case playlist = "Playlist"
        case album = "MusicAlbum"
    }

    let id: String
    let name: String
    let kind: Kind
    let artist: String?
    let year: Int?
    let hasArtwork: Bool

    private enum CodingKeys: CodingKey {
        case id, name, type, albumArtist, productionYear, imageTags
    }

    init(id: String, name: String, kind: Kind, artist: String? = nil, year: Int? = nil, hasArtwork: Bool = false) {
        self.id = id
        self.name = name
        self.kind = kind
        self.artist = artist
        self.year = year
        self.hasArtwork = hasArtwork
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .type)
        artist = try container.decodeIfPresent(String.self, forKey: .albumArtist)
        year = try container.decodeIfPresent(Int.self, forKey: .productionYear)
        let tags = try container.decodeIfPresent([String: String].self, forKey: .imageTags) ?? [:]
        hasArtwork = tags["Primary"] != nil
    }

    var subtitle: String {
        artist ?? (kind == .playlist ? "Playlist" : "Album")
    }
}
