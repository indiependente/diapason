import SwiftUI

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @Environment(Navigation.self) private var navigation
    let updater: UpdaterController
    @AppStorage("sidePanel") private var sidePanel = SidePanel.none
    /// Always open with the sidebar visible instead of restoring a collapsed one.
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var navigation = navigation
        if library.isSignedIn {
            NavigationSplitView(columnVisibility: $columns) {
                SidebarView(selection: $navigation.selection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                if !navigation.query.isEmpty {
                    SearchView(query: navigation.query)
                } else {
                    switch navigation.selection {
                    case .albums, .none:
                        AlbumsView()
                    case .artists:
                        ArtistsView()
                    case .favorites:
                        NavigationStack {
                            TrackListView(collection: .favorites)
                        }
                    case let .playlist(playlist):
                        NavigationStack {
                            TrackListView(collection: playlist)
                        }
                    }
                }
            }
            .searchable(text: $navigation.query, placement: .sidebar, prompt: "Search songs, albums, artists")
            .inspector(isPresented: $sidePanel.isOpen) {
                Group {
                    if sidePanel == .lyrics {
                        LyricsView()
                    } else {
                        QueueView()
                    }
                }
                .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Toggle(isOn: $sidePanel.showing(.lyrics)) {
                        Label("Lyrics", systemImage: "music.microphone")
                    }
                    .accessibilityIdentifier("lyricsButton")
                    Toggle(isOn: $sidePanel.showing(.queue)) {
                        Label("Up Next", systemImage: "list.bullet")
                    }
                    .accessibilityIdentifier("queueButton")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlayerBar()
            }
            .overlay(alignment: .bottomTrailing) {
                UpdateBubble(updater: updater)
                    .padding(.trailing, 16)
                    .padding(.bottom, 90)
            }
            .onKeyPress(.space) {
                guard player.current != nil else {
                    return .ignored
                }
                player.togglePlayPause()

                return .handled
            }
            .task {
                updater.start()
                await library.refresh()
            }
        } else {
            SignInView()
        }
    }
}

/// What the side inspector shows.
enum SidePanel: String {
    case none
    case queue
    case lyrics
}

extension Binding where Value == SidePanel {
    var isOpen: Binding<Bool> {
        Binding<Bool>(get: { wrappedValue != .none }, set: { open in
            if !open {
                withAnimation { wrappedValue = .none }
            }
        })
    }

    /// A toggle for one panel. Turning it on replaces the other panel; turning it off closes the inspector.
    /// Writes happen inside `withAnimation`, so the panel slides in from the menu as well as the toolbar.
    func showing(_ panel: SidePanel) -> Binding<Bool> {
        Binding<Bool>(get: { wrappedValue == panel }, set: { on in
            withAnimation { wrappedValue = on ? panel : .none }
        })
    }
}
