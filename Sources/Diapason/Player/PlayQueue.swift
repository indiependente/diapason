/// The ordered tracks to play and the position in them.
struct PlayQueue: Equatable, Sendable {
    /// Tracks in playback order.
    private(set) var tracks: [Track]
    private(set) var index: Int
    private(set) var isShuffled = false
    private var original: [Track]

    init(tracks: [Track] = [], index: Int = 0) {
        self.tracks = tracks
        original = tracks
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

    /// Goes back to the first track, for repeat-all.
    mutating func restart() {
        index = 0
    }

    /// Shuffle keeps the current track playing and randomizes the rest after it.
    /// Turning shuffle off restores the original order around the current track.
    mutating func setShuffled(_ shuffled: Bool) {
        guard shuffled != isShuffled else {
            return
        }
        isShuffled = shuffled
        let playing = current
        if shuffled {
            tracks = tracks.filter { $0 != playing }.shuffled()
            if let playing {
                tracks.insert(playing, at: 0)
            }
            index = 0
        } else {
            tracks = original
            index = original.firstIndex { $0 == playing } ?? 0
        }
    }
}
