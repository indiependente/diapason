/// An album artist from Jellyfin.
struct Artist: Identifiable, Hashable, Sendable, Decodable {
    let id: String
    let name: String
    let hasArtwork: Bool

    private enum CodingKeys: CodingKey {
        case id, name, imageTags
    }

    init(id: String, name: String, hasArtwork: Bool = false) {
        self.id = id
        self.name = name
        self.hasArtwork = hasArtwork
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        let tags = try container.decodeIfPresent([String: String].self, forKey: .imageTags) ?? [:]
        hasArtwork = tags["Primary"] != nil
    }
}
