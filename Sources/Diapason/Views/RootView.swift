import SwiftUI

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    let updater: UpdaterController
    @State private var selection: SidebarItem? = .albums
    @AppStorage("showQueue") private var showQueue = false
    /// Always open with the sidebar visible instead of restoring a collapsed one.
    @State private var columns: NavigationSplitViewVisibility = .all
    @State private var query = ""

    var body: some View {
        if library.isSignedIn {
            NavigationSplitView(columnVisibility: $columns) {
                SidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
                if !query.isEmpty {
                    SearchView(query: query)
                } else {
                    switch selection {
                    case .albums, .none:
                        AlbumsView()
                    case .artists:
                        ArtistsView()
                    case let .playlist(playlist):
                        NavigationStack {
                            TrackListView(collection: playlist)
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .sidebar, prompt: "Search songs, albums, artists")
            .inspector(isPresented: $showQueue) {
                QueueView()
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showQueue.animated) {
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

extension Binding where Value == Bool {
    /// Writes inside `withAnimation`, so the inspector slides in from the menu as well as the toolbar.
    var animated: Binding<Bool> {
        Binding(get: { wrappedValue }, set: { value in withAnimation { wrappedValue = value } })
    }
}
