@testable import Diapason
import Testing

@Suite("Preload choice")
struct PreloadTests {
    let tracks = ["a", "b", "c"].map { Track(id: $0, title: $0, artist: "") }

    @Test("repeat off buffers the next entry and nothing at the end")
    func repeatOff() {
        #expect(Player.trackToPreload(after: PlayQueue(tracks: tracks, index: 0), repeatMode: .off)?.id == "b")
        #expect(Player.trackToPreload(after: PlayQueue(tracks: tracks, index: 2), repeatMode: .off) == nil)
    }

    @Test("repeat all wraps to the first entry at the end")
    func repeatAll() {
        #expect(Player.trackToPreload(after: PlayQueue(tracks: tracks, index: 1), repeatMode: .all)?.id == "c")
        #expect(Player.trackToPreload(after: PlayQueue(tracks: tracks, index: 2), repeatMode: .all)?.id == "a")
    }

    @Test("repeat one buffers the current track again")
    func repeatOne() {
        #expect(Player.trackToPreload(after: PlayQueue(tracks: tracks, index: 1), repeatMode: .one)?.id == "b")
        #expect(Player.trackToPreload(after: PlayQueue(), repeatMode: .one) == nil)
    }
}
