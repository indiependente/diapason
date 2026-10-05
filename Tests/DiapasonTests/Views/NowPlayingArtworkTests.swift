@testable import Diapason
import SwiftUI
import ViewInspector
import XCTest

@MainActor
final class NowPlayingArtworkTests: XCTestCase {
    func testLargeArtworkOffersCollapse() throws {
        var toggled = false
        let view = NowPlayingArtwork(image: nil, isLarge: true) { toggled = true }
        let cover = try view.inspect().find(viewWithAccessibilityIdentifier: "artworkCollapseButton")
        try cover.callOnTapGesture()
        XCTAssertTrue(toggled)
        XCTAssertEqual(try cover.accessibilityLabel().string(), "Show Smaller Artwork")
    }

    func testSmallArtworkOffersExpand() throws {
        var toggled = false
        let view = NowPlayingArtwork(image: nil, isLarge: false) { toggled = true }
        let cover = try view.inspect().find(viewWithAccessibilityIdentifier: "artworkExpandButton")
        try cover.callOnTapGesture()
        XCTAssertTrue(toggled)
        XCTAssertEqual(try cover.accessibilityLabel().string(), "Show Larger Artwork")
    }
}
