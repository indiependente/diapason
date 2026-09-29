@testable import Diapason
import Testing

@Suite("PlayQueue")
struct PlayQueueTests {
    let tracks = ["a", "b", "c"].map { Track(id: $0, title: $0, artist: "") }

    @Test("starts at the requested index and clamps it")
    func startIndex() {
        #expect(PlayQueue(tracks: tracks, index: 1).current?.id == "b")
        #expect(PlayQueue(tracks: tracks, index: 9).current?.id == "c")
        #expect(PlayQueue(tracks: tracks, index: -1).current?.id == "a")
        #expect(PlayQueue().current == nil)
    }

    @Test("advance walks forward and stops at the end")
    func advance() {
        var queue = PlayQueue(tracks: tracks)
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
}
