import Foundation

/// The ordered tracks to play and the position in them.
struct PlayQueue: Equatable, Sendable {
    /// A track's slot in the queue. The same track can be queued twice, so slots have their own identity.
    struct Entry: Identifiable, Hashable, Sendable {
        let id: UUID
        let track: Track

        init(_ track: Track) {
            id = UUID()
            self.track = track
        }
    }

    /// Entries in playback order.
    private(set) var entries: [Entry]
    private(set) var index: Int
    private(set) var isShuffled = false
    private var original: [Entry]

    init(tracks: [Track] = [], index: Int = 0) {
        entries = tracks.map(Entry.init)
        original = entries
        self.index = tracks.isEmpty ? 0 : min(max(index, 0), tracks.count - 1)
    }

    var tracks: [Track] {
        entries.map(\.track)
    }

    var currentEntry: Entry? {
        entries.indices.contains(index) ? entries[index] : nil
    }

    var current: Track? {
        currentEntry?.track
    }

    /// The entries after the current one.
    var upcoming: [Entry] {
        index + 1 < entries.count ? Array(entries[(index + 1)...]) : []
    }

    var hasNext: Bool {
        index + 1 < entries.count
    }

    var hasPrevious: Bool {
        index > 0 && !entries.isEmpty
    }

    // MARK: Position

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

    /// Makes the entry the current one. Returns false when it is not in the queue.
    mutating func jump(to id: Entry.ID) -> Bool {
        guard let position = entries.firstIndex(where: { $0.id == id }) else {
            return false
        }
        index = position

        return true
    }

    // MARK: Editing

    /// Queues tracks right after the current one.
    mutating func insertNext(_ tracks: [Track]) {
        let new = tracks.map(Entry.init)
        entries.insert(contentsOf: new, at: entries.isEmpty ? 0 : index + 1)
        if isShuffled {
            let after = original.firstIndex { $0.id == currentEntry?.id }.map { $0 + 1 } ?? original.count
            original.insert(contentsOf: new, at: after)
        }
        syncOriginal()
    }

    /// Queues tracks at the end.
    mutating func append(_ tracks: [Track]) {
        let new = tracks.map(Entry.init)
        entries.append(contentsOf: new)
        original.append(contentsOf: new)
        syncOriginal()
    }

    /// Removes an entry. The current index follows the playing track, or lands on the next one.
    mutating func remove(_ id: Entry.ID) {
        guard let position = entries.firstIndex(where: { $0.id == id }) else {
            return
        }
        entries.remove(at: position)
        original.removeAll { $0.id == id }
        if position < index {
            index -= 1
        }
        syncOriginal()
    }

    /// Reorders upcoming entries. Offsets are relative to `upcoming`, as a List's onMove gives them.
    mutating func moveUpcoming(fromOffsets source: IndexSet, toOffset destination: Int) {
        let base = index + 1
        let playing = currentEntry?.id
        entries.move(fromOffsets: IndexSet(source.map { $0 + base }), toOffset: destination + base)
        index = entries.firstIndex { $0.id == playing } ?? 0
        syncOriginal()
    }

    mutating func clearUpcoming() {
        guard hasNext else {
            return
        }
        let removed = Set(entries[(index + 1)...].map(\.id))
        entries.removeSubrange((index + 1)...)
        original.removeAll { removed.contains($0.id) }
        syncOriginal()
    }

    /// Shuffle keeps the current track playing and randomizes the rest after it.
    /// Turning shuffle off restores the original order around the current track.
    mutating func setShuffled(_ shuffled: Bool) {
        guard shuffled != isShuffled else {
            return
        }
        isShuffled = shuffled
        let playing = currentEntry
        if shuffled {
            entries = entries.filter { $0.id != playing?.id }.shuffled()
            if let playing {
                entries.insert(playing, at: 0)
            }
            index = 0
        } else {
            entries = original
            index = original.firstIndex { $0.id == playing?.id } ?? 0
        }
    }

    /// Without shuffle the playback order is the original order, so every edit is mirrored.
    private mutating func syncOriginal() {
        if !isShuffled {
            original = entries
        }
    }
}
