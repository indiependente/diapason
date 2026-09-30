@testable import Diapason
import Foundation
import Testing

@Suite("PlayQueue")
struct PlayQueueTests {
    let tracks = ["a", "b", "c", "d", "e"].map { Track(id: $0, title: $0, artist: "") }

    func track(_ id: String) -> Track {
        Track(id: id, title: id, artist: "")
    }

    @Test("starts at the requested index and clamps it")
    func startIndex() {
        #expect(PlayQueue(tracks: tracks, index: 1).current?.id == "b")
        #expect(PlayQueue(tracks: tracks, index: 9).current?.id == "e")
        #expect(PlayQueue(tracks: tracks, index: -1).current?.id == "a")
        #expect(PlayQueue().current == nil)
    }

    @Test("advance walks forward and stops at the end")
    func advance() {
        var queue = PlayQueue(tracks: Array(tracks.prefix(3)))
        let steps = [queue.advance(), queue.advance(), queue.advance()]
        #expect(steps == [true, true, false])
        #expect(queue.current?.id == "c")
    }

    @Test("retreat walks backward and stops at the start")
    func retreat() {
        var queue = PlayQueue(tracks: tracks, index: 1)
        let steps = [queue.retreat(), queue.retreat()]
        #expect(steps == [true, false])
        #expect(queue.current?.id == "a")
        var empty = PlayQueue()
        let retreated = empty.retreat()
        #expect(!retreated)
    }

    @Test("restart goes back to the first track")
    func restart() {
        var queue = PlayQueue(tracks: tracks, index: 4)
        queue.restart()
        #expect(queue.current?.id == "a")
    }

    @Test("upcoming lists the entries after the current one")
    func upcoming() {
        let queue = PlayQueue(tracks: tracks, index: 3)
        #expect(queue.upcoming.map(\.track.id) == ["e"])
        #expect(PlayQueue(tracks: tracks, index: 4).upcoming.isEmpty)
    }

    @Test("jump makes an entry current")
    func jump() {
        var queue = PlayQueue(tracks: tracks)
        let target = queue.entries[3]
        let jumped = queue.jump(to: target.id)
        #expect(jumped)
        #expect(queue.current?.id == "d")
        let missed = queue.jump(to: UUID())
        #expect(!missed)
    }

    @Test("insertNext queues right after the current track, append at the end")
    func insertAndAppend() {
        var queue = PlayQueue(tracks: Array(tracks.prefix(3)), index: 1)
        queue.insertNext([track("x"), track("y")])
        queue.append([track("z")])
        #expect(queue.tracks.map(\.id) == ["a", "b", "x", "y", "c", "z"])
        #expect(queue.current?.id == "b")
        var empty = PlayQueue()
        empty.insertNext([track("x")])
        #expect(empty.current?.id == "x")
    }

    @Test("the same track can be queued twice")
    func duplicates() {
        var queue = PlayQueue(tracks: [track("a")])
        queue.append([track("a")])
        #expect(queue.tracks.count == 2)
        #expect(Set(queue.entries.map(\.id)).count == 2)
    }

    @Test("remove keeps the playing track current, or moves to the next one")
    func remove() {
        var queue = PlayQueue(tracks: tracks, index: 2)
        queue.remove(queue.entries[0].id)
        #expect(queue.current?.id == "c")
        #expect(queue.index == 1)
        queue.remove(queue.entries[3].id)
        #expect(queue.tracks.map(\.id) == ["b", "c", "d"])
        queue.remove(queue.entries[1].id)
        #expect(queue.current?.id == "d")
        queue.remove(queue.entries[1].id)
        #expect(queue.current == nil)
        #expect(queue.tracks.map(\.id) == ["b"])
    }

    @Test("moveUpcoming reorders relative to the upcoming list and keeps the current track")
    func move() {
        var queue = PlayQueue(tracks: tracks, index: 1)
        queue.moveUpcoming(fromOffsets: [2], toOffset: 0)
        #expect(queue.tracks.map(\.id) == ["a", "b", "e", "c", "d"])
        #expect(queue.current?.id == "b")
    }

    @Test("clearUpcoming drops everything after the current track")
    func clearUpcoming() {
        var queue = PlayQueue(tracks: tracks, index: 1)
        queue.clearUpcoming()
        #expect(queue.tracks.map(\.id) == ["a", "b"])
        #expect(queue.current?.id == "b")
        #expect(!queue.hasNext)
    }

    @Test("shuffle keeps the current track first and the same set of tracks")
    func shuffle() {
        var queue = PlayQueue(tracks: tracks, index: 2)
        queue.setShuffled(true)
        #expect(queue.isShuffled)
        #expect(queue.index == 0)
        #expect(queue.current?.id == "c")
        #expect(Set(queue.tracks) == Set(tracks))
        #expect(queue.tracks.count == tracks.count)
    }

    @Test("unshuffle restores the original order around the current track")
    func unshuffle() {
        var queue = PlayQueue(tracks: tracks, index: 2)
        queue.setShuffled(true)
        _ = queue.advance()
        let playing = queue.current
        queue.setShuffled(false)
        #expect(!queue.isShuffled)
        #expect(queue.tracks == tracks)
        #expect(queue.current == playing)
    }

    @Test("edits made while shuffled survive unshuffling")
    func editsSurviveUnshuffle() throws {
        var queue = PlayQueue(tracks: tracks, index: 0)
        queue.setShuffled(true)
        queue.insertNext([track("x")])
        queue.append([track("z")])
        try queue.remove(#require(queue.entries.first { $0.track.id == "e" }?.id))
        queue.setShuffled(false)
        #expect(queue.tracks.map(\.id) == ["a", "x", "b", "c", "d", "z"])
        #expect(queue.current?.id == "a")
    }

    @Test("setting the same shuffle state twice is a no-op")
    func shuffleIdempotent() {
        var queue = PlayQueue(tracks: tracks)
        queue.setShuffled(true)
        let order = queue.tracks
        queue.setShuffled(true)
        #expect(queue.tracks == order)
    }
}
