@testable import Diapason
import Foundation
import Testing

@Suite("Track decoding")
struct TrackDecodingTests {
    static let playlistItem = """
    {"Id":"t1","Name":"Ladies Room","Artists":["Olivia Dean","Someone"],"Album":"Messy","AlbumId":"a1",
     "IndexNumber":3,"RunTimeTicks":2203722290,"ImageTags":{"Primary":"x"},"AlbumPrimaryImageTag":"y","Type":"Audio"}
    """

    static let albumChild = """
    {"Id":"t2","Name":"Hang In Long Enough","Artists":["Phil Collins"],"Album":"...But Seriously","AlbumId":"a2",
     "IndexNumber":1,"RunTimeTicks":2848933330,"ImageTags":{},"AlbumPrimaryImageTag":"z","Type":"Audio"}
    """

    @Test("decodes fields and converts ticks to seconds")
    func decodesPlaylistItem() throws {
        let track = try JSONDecoder().decode(Track.self, from: Data(Self.playlistItem.utf8))
        #expect(track.id == "t1")
        #expect(track.title == "Ladies Room")
        #expect(track.artist == "Olivia Dean, Someone")
        #expect(track.album == "Messy")
        #expect(track.trackNumber == 3)
        #expect(abs(track.duration - 220.372) < 0.001)
        #expect(track.artworkItemID == "t1")
    }

    @Test("falls back to album artwork when the track has none")
    func fallsBackToAlbumArtwork() throws {
        let track = try JSONDecoder().decode(Track.self, from: Data(Self.albumChild.utf8))
        #expect(track.artworkItemID == "a2")
    }

    @Test("decodes a collection")
    func decodesCollection() throws {
        let json = """
        {"Id":"p1","Name":"Reference","Type":"Playlist","ImageTags":{"Primary":"q"}}
        """
        let collection = try JSONDecoder().decode(MusicCollection.self, from: Data(json.utf8))
        #expect(collection.kind == .playlist)
        #expect(collection.subtitle == "Playlist")
        #expect(collection.hasArtwork)
    }

    @Test("formats durations", arguments: [(59.9, "0:59"), (220.4, "3:40"), (3661, "1:01:01")])
    func formatsDuration(seconds: Double, expected: String) {
        #expect(TimeInterval(seconds).trackFormatted == expected)
    }
}
