/// The ordered tracks to play and the position in them.
struct PlayQueue: Equatable, Sendable {
    private(set) var tracks: [Track]
    private(set) var index: Int

    init(tracks: [Track] = [], index: Int = 0) {
        self.tracks = tracks
        self.index = tracks.isEmpty ? 0 : min(max(index, 0), tracks.count - 1)
    }

    var current: Track? {
        tracks.indices.contains(index) ? tracks[index] : nil
    }

    var hasNext: Bool {
        index + 1 < tracks.count
    }

    var hasPrevious: Bool {
        index > 0 && !tracks.isEmpty
    }

    /// Moves to the next track. Returns false at the end of the queue.
    mutating func advance() -> Bool {
        guard hasNext else {
            return false
        }
        index += 1

        return true
    }

    /// Moves to the previous track. Returns false at the start of the queue.
    mutating func retreat() -> Bool {
        guard hasPrevious else {
            return false
        }
        index -= 1

        return true
    }
}
