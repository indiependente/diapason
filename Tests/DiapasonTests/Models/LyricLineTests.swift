@testable import Diapason
import Foundation
import Testing

@Suite("LyricLine")
struct LyricLineTests {
    @Test("decodes text and converts start ticks to seconds")
    func decodes() throws {
        let json = #"{"Lyrics":[{"Text":"first","Start":5500000,"Cues":[]},{"Text":"plain"}]}"#
        let response = try JSONDecoder.jellyfin.decode(LyricsResponse.self, from: Data(json.utf8))
        #expect(response.lyrics == [LyricLine(text: "first", start: 0.55), LyricLine(text: "plain")])
    }

    @Test("currentIndex is the last line that has started")
    func currentIndex() {
        let lines = [LyricLine(text: "a", start: 1), LyricLine(text: "b", start: 5), LyricLine(text: "c", start: 9)]
        #expect(LyricLine.currentIndex(in: lines, at: 0.5) == nil)
        #expect(LyricLine.currentIndex(in: lines, at: 1) == 0)
        #expect(LyricLine.currentIndex(in: lines, at: 6) == 1)
        #expect(LyricLine.currentIndex(in: lines, at: 100) == 2)
        #expect(LyricLine.currentIndex(in: [LyricLine(text: "unsynced")], at: 10) == nil)
    }
}
