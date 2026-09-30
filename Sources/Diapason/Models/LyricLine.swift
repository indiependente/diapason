import Foundation

/// One line of a song's lyrics. `start` is nil when the lyrics are not time-synced.
struct LyricLine: Hashable, Sendable, Decodable {
    let text: String
    let start: TimeInterval?

    private enum CodingKeys: CodingKey {
        case text, start
    }

    init(text: String, start: TimeInterval? = nil) {
        self.text = text
        self.start = start
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
        start = try container.decodeIfPresent(Double.self, forKey: .start).map { $0 / Track.ticksPerSecond }
    }

    /// The line to highlight at a playback time: the last one that has started. Nil before the first
    /// line, or when the lyrics are not synced.
    static func currentIndex(in lines: [LyricLine], at time: TimeInterval) -> Int? {
        lines.lastIndex { line in
            if let start = line.start {
                return start <= time
            }

            return false
        }
    }
}

/// The wire shape of `Audio/{id}/Lyrics`.
struct LyricsResponse: Decodable {
    let lyrics: [LyricLine]
}
