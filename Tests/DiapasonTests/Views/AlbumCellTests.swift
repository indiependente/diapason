@testable import Diapason
import SwiftUI
import ViewInspector
import XCTest

@MainActor
final class AlbumCellTests: XCTestCase {
    func testShowsNameAndArtist() throws {
        let album = MusicCollection(id: "a1", name: "Messy", kind: .album, artist: "Olivia Dean")
        let cell = AlbumCell(album: album, artworkURL: nil)
        let stack = try cell.inspect().vStack()
        XCTAssertEqual(try stack.text(1).string(), "Messy")
        XCTAssertEqual(try stack.text(2).string(), "Olivia Dean")
    }
}
