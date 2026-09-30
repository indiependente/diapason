import SwiftUI

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    let updater: UpdaterController
    @State private var selection: SidebarItem? = .albums

    var body: some View {
        if library.isSignedIn {
            NavigationSplitView {
                SidebarView(selection: $selection)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            } detail: {
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
