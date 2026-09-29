@testable import Diapason
import MediaPlayer
import Testing

@Suite("NowPlayingInfo")
struct NowPlayingInfoTests {
    @Test("maps the track to the MediaPlayer keys")
    func mapsTrack() {
        let track = Track(id: "t", title: "Song", artist: "Band", album: "Record", duration: 200)
        let info = NowPlayingInfo.dictionary(track: track, elapsed: 42, rate: 1)
        #expect(info[MPMediaItemPropertyTitle] as? String == "Song")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Band")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Record")
        #expect(info[MPMediaItemPropertyPlaybackDuration] as? TimeInterval == 200)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval == 42)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 1)
        #expect(info[MPNowPlayingInfoPropertyMediaType] as? UInt == MPNowPlayingInfoMediaType.audio.rawValue)
    }
}
