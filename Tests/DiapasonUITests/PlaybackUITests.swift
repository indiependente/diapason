import AppKit
import XCTest

/// Drives the real app against a real Jellyfin server. Skips when the server is not configured.
@MainActor
final class PlaybackUITests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = false
    }

    func testSignInAndPlayFirstPlaylistTrack() async throws {
        guard let server = env["DIAPASON_TEST_SERVER"], !server.isEmpty,
              let user = env["DIAPASON_TEST_USER"], let password = env["DIAPASON_TEST_PASSWORD"]
        else {
            throw XCTSkip("Set DIAPASON_TEST_SERVER, DIAPASON_TEST_USER and DIAPASON_TEST_PASSWORD.")
        }
        let app = XCUIApplication()
        // Never add -ApplePersistenceIgnoreState here: on macOS 26 it stops SwiftUI from opening the window.
        app.launchArguments = ["-DiapasonFreshSession"]
        app.launch()
        signIn(app, server: server, user: user, password: password)

        let albums = app.staticTexts["Albums"]
        let signedIn = albums.waitForExistence(timeout: 15)
        screenshot(app, name: "albums")
        XCTAssertTrue(signedIn, app.debugDescription)

        let sidebar = app.outlines["Sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), app.debugDescription)
        sidebar.staticTexts["Artists"].click()
        let artists = app.outlines.matching(NSPredicate(format: "label != 'Sidebar' AND identifier != 'queueList'"))
            .firstMatch
        XCTAssertTrue(artists.outlineRows.element(boundBy: 0).waitForExistence(timeout: 15), app.debugDescription)
        screenshot(app, name: "artists")

        // Section headers show up as static texts too, so skip every fixed label to reach a playlist.
        let fixed: Set = ["Library", "Albums", "Artists", "Favorites", "Playlists"]
        let playlist = try XCTUnwrap(sidebar.staticTexts.allElementsBoundByIndex.first { text in
            !fixed.contains((text.value as? String) ?? text.label)
        })
        playlist.click()

        // SwiftUI's Table is an NSOutlineView underneath, like the sidebar, so skip the sidebar by label.
        let table = app.outlines.matching(NSPredicate(format: "label != 'Sidebar' AND identifier != 'queueList'"))
            .firstMatch
        let firstRow = table.outlineRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 15), app.debugDescription)
        // Rows report themselves as not hittable, so click by coordinate.
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).doubleClick()

        let title = app.staticTexts["nowPlayingTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
        // Long enough for the server to receive the start report and for a person to eyeball the run.
        try await Task.sleep(for: .seconds(8))
        screenshot(app, name: "playing")

        try await openSidePanels(app)

        pauseAndResume(app)
        try skipToNext(app)
        try await Task.sleep(for: .seconds(4))
        search(app, for: "shelter", expecting: "Pale Shelter")
        toggleFavorite(app)
        // Quit like a person would, so the app gets to send its stop report.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    /// Opens Up Next and then Lyrics, taking a screenshot of each, and closes the panel again.
    private func openSidePanels(_ app: XCUIApplication) async throws {
        // The panel state persists between launches, so only open it when it is closed.
        if !app.outlines["queueList"].exists {
            app.checkBoxes["queueButton"].firstMatch.click()
        }
        XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5), app.debugDescription)
        screenshot(app, name: "queue")
        app.checkBoxes["lyricsButton"].firstMatch.click()
        XCTAssertTrue(
            app.descendants(matching: .any)["lyricsPanel"].firstMatch.waitForExistence(timeout: 5),
            app.debugDescription
        )
        try await Task.sleep(for: .seconds(3))
        screenshot(app, name: "lyrics")
        app.checkBoxes["lyricsButton"].firstMatch.click()
    }

    private func pauseAndResume(_ app: XCUIApplication) {
        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Play")
        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
    }

    /// Hearts the playing song from the player bar, then removes the heart again.
    private func toggleFavorite(_ app: XCUIApplication) {
        let heart = app.buttons["favoriteButton"].firstMatch
        XCTAssertTrue(heart.waitForExistence(timeout: 5), app.debugDescription)
        let before = heart.label
        heart.click()
        let flipped = NSPredicate(format: "label != %@", before)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: flipped, evaluatedWith: heart)], timeout: 3), .completed)
        screenshot(app, name: "favorite")
        heart.click()
    }

    /// Types into the sidebar search field and waits for a song result, then clears the search.
    private func search(_ app: XCUIApplication, for term: String, expecting title: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), app.debugDescription)
        field.click()
        paste(term, into: field)
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 10), app.debugDescription)
        screenshot(app, name: "search")
        field.typeKey("a", modifierFlags: .command)
        field.typeKey(.delete, modifierFlags: [])
    }

    /// The next track is buffered ahead, so the title must change almost at once.
    private func skipToNext(_ app: XCUIApplication) throws {
        let title = app.staticTexts["nowPlayingTitle"]
        let before = try XCTUnwrap(title.value as? String)
        app.buttons["Next"].firstMatch.click()
        let changed = NSPredicate(format: "value != %@", before)
        let result = XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: title)], timeout: 3)
        XCTAssertEqual(result, .completed, "still showing \(before)")
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
    }

    private func signIn(_ app: XCUIApplication, server: String, user: String, password: String) {
        let button = app.buttons["signInButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10), app.debugDescription)
        fill(app.textFields["serverField"], with: server)
        fill(app.textFields["usernameField"], with: user)
        // Clicking a SecureField does not always give it focus, so tab into it from the username field.
        app.textFields["usernameField"].typeKey(.tab, modifierFlags: [])
        paste(password, into: app)
        button.click()
    }

    private func fill(_ field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.click()
        field.typeKey("a", modifierFlags: .command)
        paste(text, into: field)
    }

    /// typeText drops punctuation now and then on macOS, so the text goes through the pasteboard.
    private func paste(_ text: String, into element: XCUIElement) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        element.typeKey("v", modifierFlags: .command)
    }

    private func screenshot(_ app: XCUIApplication, name: String) {
        let shot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = env["DIAPASON_SCREENSHOT_DIR"], !dir.isEmpty {
            let base = URL(fileURLWithPath: dir).appendingPathComponent(name)
            try? shot.pngRepresentation.write(to: base.appendingPathExtension("png"))
            try? app.debugDescription.write(to: base.appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        }
    }
}
