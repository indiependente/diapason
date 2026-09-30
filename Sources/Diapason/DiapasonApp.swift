import AppKit
import SwiftUI

@main
struct DiapasonApp: App {
    @State private var library: Library
    @State private var player: Player
    @State private var updater = UpdaterController()
    @State private var navigation = Navigation()
    @AppStorage("sidePanel") private var sidePanel = SidePanel.none

    init() {
        // Tests must not pick up the real session: the unit test host would start talking to the
        // server, and the UI test needs the sign-in screen without touching the stored session.
        let fresh = ProcessInfo.isRunningTests() || CommandLine.arguments.contains("-DiapasonFreshSession")
        let store: any SecretStore = fresh ? InMemorySecretStore() : FileSecretStore.default
        let library = Library(store: store)
        _library = State(initialValue: library)
        _player = State(initialValue: Player(library: library))
        Self.reopenIfWindowless()
    }

    /// Closing the window with Cmd+W and then quitting makes macOS restore "no windows" on the next
    /// launch, and SwiftUI opens nothing. A reopen, the same request a Dock click sends, brings the
    /// main window back. Two seconds is well past a normal launch, so it never races a real window.
    private static func reopenIfWindowless() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard NSApp.windows.isEmpty else {
                return
            }
            _ = try? await NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            // Passed as a parameter: injecting an NSObject-based Observable with `.environment`
            // stops SwiftUI from opening the window on macOS 26.
            RootView(updater: updater)
                .environment(library)
                .environment(player)
                .environment(navigation)
                // Sidebar, detail, and the Up Next panel do not fit in 900 points; the window grows instead of
                // squeezing.
                .frame(minWidth: sidePanel == .none ? 900 : 1220, minHeight: 600)
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheckForUpdates)
            }
            CommandMenu("Controls") {
                Button(player.isPlaying ? "Pause" : "Play") { player.togglePlayPause() }
                    .disabled(player.current == nil)
                Button("Next") { player.next() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                    .disabled(player.current == nil)
                Button("Previous") { player.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                    .disabled(player.current == nil)
                Divider()
                Button("Stop") { player.stop() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(player.current == nil)
                Divider()
                if let track = player.current {
                    Button(library.isFavorite(track) ? "Remove from Favorites" : "Add to Favorites") {
                        library.toggleFavorite(track)
                    }
                    if let album = library.album(for: track) {
                        Button("Go to Album") { navigation.show(album: album) }
                    }
                    if let artist = library.artist(for: track) {
                        Button("Go to Artist") { navigation.show(artist: artist) }
                    }
                    Divider()
                }
                Toggle("Shuffle", isOn: Binding(get: { player.isShuffled }, set: { player.isShuffled = $0 }))
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Picker("Repeat", selection: Binding(get: { player.repeatMode }, set: { player.repeatMode = $0 })) {
                    ForEach(RepeatMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            CommandGroup(after: .toolbar) {
                Toggle("Show Up Next", isOn: $sidePanel.showing(.queue))
                    .keyboardShortcut("u", modifiers: [.command, .shift])
                Toggle("Show Lyrics", isOn: $sidePanel.showing(.lyrics))
                    .keyboardShortcut("l", modifiers: [.command, .shift])
                Button("Refresh Library") { Task { await library.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!library.isSignedIn)
            }
        }

        Settings {
            SettingsView()
                .environment(library)
        }
    }
}
