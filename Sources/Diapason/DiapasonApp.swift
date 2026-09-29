import SwiftUI

@main
struct DiapasonApp: App {
    @State private var library: Library
    @State private var player: Player

    init() {
        let library = Library(keychain: LiveKeychainStore(service: "com.indiependente.Diapason"))
        _library = State(initialValue: library)
        _player = State(initialValue: Player(library: library))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .frame(minWidth: 900, minHeight: 600)
        }
        .commands {
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
            }
            CommandGroup(after: .toolbar) {
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
