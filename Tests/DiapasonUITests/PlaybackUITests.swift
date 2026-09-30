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
        resetStoredSession()
        let app = XCUIApplication()
        app.launch()

        let signIn = app.buttons["signInButton"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10), app.debugDescription)
        fill(app.textFields["serverField"], with: server)
        fill(app.textFields["usernameField"], with: user)
        // Clicking a SecureField does not always give it focus, so tab into it from the username field.
        app.textFields["usernameField"].typeKey(.tab, modifierFlags: [])
        paste(password, into: app)
        signIn.click()

        let albums = app.staticTexts["Albums"]
        let signedIn = albums.waitForExistence(timeout: 15)
        screenshot(app, name: "albums")
        XCTAssertTrue(signedIn, app.debugDescription)

        let sidebar = app.outlines["Sidebar"]
        XCTAssertTrue(sidebar.waitForExistence(timeout: 5), app.debugDescription)
        sidebar.staticTexts["Artists"].click()
        let artists = app.outlines.matching(NSPredicate(format: "label != 'Sidebar'")).firstMatch
        XCTAssertTrue(artists.outlineRows.element(boundBy: 0).waitForExistence(timeout: 15), app.debugDescription)
        screenshot(app, name: "artists")

        // Section headers show up as static texts too, so skip every fixed label to reach a playlist.
        let fixed: Set = ["Library", "Albums", "Artists", "Playlists"]
        let playlist = try XCTUnwrap(sidebar.staticTexts.allElementsBoundByIndex.first { text in
            !fixed.contains((text.value as? String) ?? text.label)
        })
        playlist.click()

        // SwiftUI's Table is an NSOutlineView underneath, like the sidebar, so skip the sidebar by label.
        let table = app.outlines.matching(NSPredicate(format: "label != 'Sidebar'")).firstMatch
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

        app.checkBoxes["queueButton"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5), app.debugDescription)
        screenshot(app, name: "queue")
        app.checkBoxes["queueButton"].firstMatch.click()

        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Play")
        app.buttons["playPauseButton"].click()
        XCTAssertEqual(app.buttons["playPauseButton"].label, "Pause")
        try await Task.sleep(for: .seconds(4))
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

    /// Forces the sign-in screen so the test covers the whole flow.
    private func resetStoredSession() {
        let file = URL.applicationSupportDirectory.appending(path: "Diapason/credentials.json")
        try? FileManager.default.removeItem(at: file)
    }
}
