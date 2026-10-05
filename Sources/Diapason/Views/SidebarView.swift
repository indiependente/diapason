import SwiftUI

struct SidebarView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @Binding var selection: SidebarItem?
    @AppStorage("largeArtwork") private var largeArtwork = false

    var body: some View {
        List(selection: $selection) {
            Section("Library") {
                Label("Albums", systemImage: "square.stack")
                    .tag(SidebarItem.albums)
                Label("Artists", systemImage: "music.microphone")
                    .tag(SidebarItem.artists)
                Label("Favorites", systemImage: "heart")
                    .tag(SidebarItem.favorites)
            }
            Section("Playlists") {
                ForEach(library.playlists) { playlist in
                    Label(playlist.name, systemImage: "music.note.list")
                        .tag(SidebarItem.playlist(playlist))
                }
            }
        }
        .contextMenu(forSelectionType: SidebarItem.self) { items in
            if case let .playlist(playlist)? = items.first {
                Button("Play") { queue(playlist) { player.play($0) } }
                Button("Play Next") { queue(playlist, player.playNext) }
                Button("Add to Queue") { queue(playlist, player.addToQueue) }
            }
        } primaryAction: { items in
            if case let .playlist(playlist)? = items.first {
                queue(playlist) { player.play($0) }
            }
        }
        .navigationTitle("Diapason")
        // The large artwork sits at the bottom of the sidebar, right above the play and pause buttons.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if largeArtwork, player.current != nil {
                NowPlayingArtwork(image: player.artwork, isLarge: true) {
                    withAnimation { largeArtwork = false }
                }
                .padding(12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if let message = library.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(8)
            }
        }
    }

    private func queue(_ playlist: MusicCollection, _ action: @escaping @MainActor ([Track]) -> Void) {
        Task {
            if let tracks = try? await library.tracks(in: playlist) {
                action(tracks)
            }
        }
    }
}
