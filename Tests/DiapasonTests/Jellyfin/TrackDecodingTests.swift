@testable import Diapason
import Foundation
import Testing

@Suite("Track decoding")
struct TrackDecodingTests {
    static let playlistItem = """
    {"Id":"t1","Name":"Ladies Room","Artists":["Olivia Dean","Someone"],"Album":"Messy","AlbumId":"a1",
     "IndexNumber":3,"RunTimeTicks":2203722290,"ImageTags":{"Primary":"x"},"AlbumPrimaryImageTag":"y","Type":"Audio",
     "MediaSources":[{"Container":"flac","Bitrate":2746914,"MediaStreams":[
        {"Type":"Audio","Codec":"flac","BitRate":2746914,"SampleRate":96000,"Channels":2,"BitDepth":24},
        {"Type":"EmbeddedImage","Codec":"mjpeg","BitDepth":8}]}]}
    """

    static let albumChild = """
    {"Id":"t2","Name":"Hang In Long Enough","Artists":["Phil Collins"],"Album":"...But Seriously","AlbumId":"a2",
     "IndexNumber":1,"RunTimeTicks":2848933330,"ImageTags":{},"AlbumPrimaryImageTag":"z","Type":"Audio"}
    """

    @Test("decodes fields and converts ticks to seconds")
    func decodesPlaylistItem() throws {
        let track = try JSONDecoder.jellyfin.decode(Track.self, from: Data(Self.playlistItem.utf8))
        #expect(track.id == "t1")
        #expect(track.title == "Ladies Room")
        #expect(track.artist == "Olivia Dean, Someone")
        #expect(track.album == "Messy")
        #expect(track.trackNumber == 3)
        #expect(abs(track.duration - 220.372) < 0.001)
        #expect(track.artworkItemID == "t1")
    }

    @Test("decodes the audio stream into media info")
    func decodesMediaInfo() throws {
        let track = try JSONDecoder.jellyfin.decode(Track.self, from: Data(Self.playlistItem.utf8))
        #expect(track.media == MediaInfo(codec: "flac", bitrate: 2_746_914, sampleRate: 96000, bitDepth: 24))
        #expect(track.media?.summary == "FLAC 24/96 · 2746 kbps")
    }

    @Test("media info is nil without media sources, and formats degrade gracefully")
    func mediaInfoFallbacks() throws {
        let track = try JSONDecoder.jellyfin.decode(Track.self, from: Data(Self.albumChild.utf8))
        #expect(track.media == nil)
        #expect(MediaInfo(codec: "mp3", bitrate: 320_000, sampleRate: 44100).format == "MP3 44.1 kHz")
        #expect(MediaInfo(codec: "aac").summary == "AAC")
    }

    @Test("falls back to album artwork when the track has none")
    func fallsBackToAlbumArtwork() throws {
        let track = try JSONDecoder.jellyfin.decode(Track.self, from: Data(Self.albumChild.utf8))
        #expect(track.artworkItemID == "a2")
    }

    @Test("decodes a collection")
    func decodesCollection() throws {
        let json = """
        {"Id":"p1","Name":"Reference","Type":"Playlist","ImageTags":{"Primary":"q"}}
        """
        let collection = try JSONDecoder.jellyfin.decode(MusicCollection.self, from: Data(json.utf8))
        #expect(collection.kind == .playlist)
        #expect(collection.subtitle == "Playlist")
        #expect(collection.hasArtwork)
    }

    @Test("decodes an artist")
    func decodesArtist() throws {
        let json = """
        {"Id":"ar1","Name":"Phil Collins","Type":"MusicArtist","ImageTags":{"Logo":"l"}}
        """
        let artist = try JSONDecoder.jellyfin.decode(Artist.self, from: Data(json.utf8))
        #expect(artist == Artist(id: "ar1", name: "Phil Collins", hasArtwork: false))
    }

    @Test("formats durations", arguments: [(59.9, "0:59"), (220.4, "3:40"), (3661, "1:01:01")])
    func formatsDuration(seconds: Double, expected: String) {
        #expect(TimeInterval(seconds).trackFormatted == expected)
    }
}
