@testable import Diapason
import Testing

@Suite("PlayQueue")
struct PlayQueueTests {
    let tracks = ["a", "b", "c", "d", "e"].map { Track(id: $0, title: $0, artist: "") }

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

    @Test("setting the same shuffle state twice is a no-op")
    func shuffleIdempotent() {
        var queue = PlayQueue(tracks: tracks)
        queue.setShuffled(true)
        let order = queue.tracks
        queue.setShuffled(true)
        #expect(queue.tracks == order)
    }
}
