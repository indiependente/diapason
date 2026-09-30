import SwiftUI

@main
struct DiapasonApp: App {
    @State private var library: Library
    @State private var player: Player
    @State private var updater = UpdaterController()
    @AppStorage("showQueue") private var showQueue = false

    init() {
        // The ad-hoc signed test host would trigger a Keychain access prompt on every rebuild.
        let keychain: any KeychainStore = ProcessInfo.isRunningTests()
            ? InMemoryKeychainStore()
            : LiveKeychainStore(service: "com.indiependente.Diapason")
        let library = Library(keychain: keychain)
        _library = State(initialValue: library)
        _player = State(initialValue: Player(library: library))
    }

    var body: some Scene {
        WindowGroup {
            // Passed as a parameter: injecting an NSObject-based Observable with `.environment`
            // stops SwiftUI from opening the window on macOS 26.
            RootView(updater: updater)
                .environment(library)
                .environment(player)
                .frame(minWidth: 900, minHeight: 600)
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
                Toggle("Shuffle", isOn: Binding(get: { player.isShuffled }, set: { player.isShuffled = $0 }))
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Picker("Repeat", selection: Binding(get: { player.repeatMode }, set: { player.repeatMode = $0 })) {
                    ForEach(RepeatMode.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
            CommandGroup(after: .toolbar) {
                Toggle("Show Up Next", isOn: $showQueue)
                    .keyboardShortcut("u", modifiers: [.command, .shift])
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
