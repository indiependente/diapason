import AppKit
import XCTest

/// Drives the real app against a real Jellyfin server. Skips when the server is not configured.
@MainActor
final class PlaybackUITests: XCTestCase {
    private let env = ProcessInfo.processInfo.environment

    override func setUp() {
        continueAfterFailure = false
    }

    // One test per feature. Run one while you work on it, for example:
    //   make test-e2e ONLY=PlaybackUITests/testLargeArtwork
    // Run the full suite once before you finish.

    func testPlaybackReportsToServerAndQuits() async throws {
        let app = try launchSignedIn()
        try playFirstPlaylistTrack(app)
        // Long enough for the server to receive the start report.
        try await Task.sleep(for: .seconds(8))
        screenshot(app, name: "playing")
        pauseAndResume(app)
        try skipToNext(app)
        // Quit like a person would, so the app gets to send its stop report.
        app.typeKey("q", modifierFlags: .command)
        XCTAssertTrue(app.wait(for: .notRunning, timeout: 10))
    }

    func testBrowseArtists() throws {
        let app = try launchSignedIn()
        app.outlines["Sidebar"].staticTexts["Artists"].click()
        XCTAssertTrue(
            contentOutline(app).outlineRows.element(boundBy: 0).waitForExistence(timeout: 15),
            app.debugDescription
        )
        screenshot(app, name: "artists")
    }

    func testSearch() throws {
        let app = try launchSignedIn()
        search(app, for: "shelter", expecting: "Pale Shelter")
    }

    func testSidePanels() async throws {
        let app = try launchSignedIn()
        try playFirstPlaylistTrack(app)
        try await openSidePanels(app)
    }

    func testFavorite() throws {
        let app = try launchSignedIn()
        try playFirstPlaylistTrack(app)
        toggleFavorite(app)
    }

    func testLargeArtwork() throws {
        let app = try launchSignedIn()
        try playFirstPlaylistTrack(app)
        toggleLargeArtwork(app)
    }

    // MARK: Shared steps

    /// Launches the app with an in-memory session and signs in through the UI.
    private func launchSignedIn() throws -> XCUIApplication {
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
        let signedIn = app.staticTexts["Albums"].waitForExistence(timeout: 15)
        screenshot(app, name: "albums")
        XCTAssertTrue(signedIn, app.debugDescription)
        XCTAssertTrue(app.outlines["Sidebar"].waitForExistence(timeout: 5), app.debugDescription)

        return app
    }

    /// Opens the first playlist in the sidebar and double-clicks its first track.
    private func playFirstPlaylistTrack(_ app: XCUIApplication) throws {
        // Section headers show up as static texts too, so skip every fixed label to reach a playlist.
        let fixed: Set = ["Library", "Albums", "Artists", "Favorites", "Playlists"]
        let playlist = try XCTUnwrap(app.outlines["Sidebar"].staticTexts.allElementsBoundByIndex.first { text in
            !fixed.contains((text.value as? String) ?? text.label)
        })
        playlist.click()
        let firstRow = contentOutline(app).outlineRows.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 15), app.debugDescription)
        // Rows report themselves as not hittable, so click by coordinate.
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).doubleClick()
        XCTAssertTrue(app.staticTexts["nowPlayingTitle"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
    }

    /// SwiftUI's List and Table are both outlines, so skip the sidebar and the Up Next list.
    private func contentOutline(_ app: XCUIApplication) -> XCUIElement {
        app.outlines.matching(NSPredicate(format: "label != 'Sidebar' AND identifier != 'queueList'")).firstMatch
    }

    /// Opens Up Next and then Lyrics, taking a screenshot of each, and closes the panel again.
    /// The keyboard shortcuts work wherever macOS puts the window, also when the toolbar is off screen.
    private func openSidePanels(_ app: XCUIApplication) async throws {
        // The panel state persists between launches, so only open it when it is closed.
        if !app.outlines["queueList"].exists {
            app.typeKey("u", modifierFlags: [.command, .shift])
        }
        XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5), app.debugDescription)
        screenshot(app, name: "queue")
        app.typeKey("l", modifierFlags: [.command, .shift])
        XCTAssertTrue(
            app.descendants(matching: .any)["lyricsPanel"].firstMatch.waitForExistence(timeout: 5),
            app.debugDescription
        )
        try await Task.sleep(for: .seconds(3))
        screenshot(app, name: "lyrics")
        app.typeKey("l", modifierFlags: [.command, .shift])
    }

    private func pauseAndResume(_ app: XCUIApplication) {
        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Play")
        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
    }

    /// Moves the artwork into the sidebar and back with a click on the cover.
    private func toggleLargeArtwork(_ app: XCUIApplication) {
        let expand = app.descendants(matching: .any)["artworkExpandButton"].firstMatch
        // The size persists between launches, so only expand when the cover is small.
        if expand.waitForExistence(timeout: 3) {
            expand.click()
        }
        let collapse = app.descendants(matching: .any)["artworkCollapseButton"].firstMatch
        XCTAssertTrue(collapse.waitForExistence(timeout: 5), app.debugDescription)
        collapse.hover()
        screenshot(app, name: "large-artwork")
        collapse.click()
        XCTAssertTrue(expand.waitForExistence(timeout: 5), app.debugDescription)
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
