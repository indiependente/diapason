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
    let hasArtwork: Bool

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case kind = "Type"
        case artist = "AlbumArtist"
        case imageTags = "ImageTags"
    }

    init(
        id: String,
        name: String,
        kind: Kind,
        artist: String? = nil,
        hasArtwork: Bool = false
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.artist = artist
        self.hasArtwork = hasArtwork
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .kind)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        let tags = try container.decodeIfPresent([String: String].self, forKey: .imageTags) ?? [:]
        hasArtwork = tags["Primary"] != nil
    }

    var subtitle: String {
        artist ?? (kind == .playlist ? "Playlist" : "Album")
    }
}
