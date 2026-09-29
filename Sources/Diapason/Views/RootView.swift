import SwiftUI

struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
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
                case let .playlist(playlist):
                    NavigationStack {
                        TrackListView(collection: playlist)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PlayerBar()
            }
            .onKeyPress(.space) {
                guard player.current != nil else {
                    return .ignored
                }
                player.togglePlayPause()

                return .handled
            }
            .task { await library.refresh() }
        } else {
            SignInView()
        }
    }
}
