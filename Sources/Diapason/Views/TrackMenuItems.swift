import SwiftUI

/// The song actions every context menu shares: queueing, the heart, and jumping to the album or artist.
struct TrackMenuItems: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @Environment(Navigation.self) private var navigation
    let tracks: [Track]
    var includesQueueing = true

    var body: some View {
        if includesQueueing, !tracks.isEmpty {
            Button("Play Next") { player.playNext(tracks) }
            Button("Add to Queue") { player.addToQueue(tracks) }
        }
        if let track = tracks.first {
            Divider()
            Button(library.isFavorite(track) ? "Remove from Favorites" : "Add to Favorites") {
                library.toggleFavorite(track)
            }
            Divider()
            if let album = library.album(for: track) {
                Button("Go to Album") { navigation.show(album: album) }
            }
            if let artist = library.artist(for: track) {
                Button("Go to Artist") { navigation.show(artist: artist) }
            }
        }
    }
}

/// The heart that marks a favorite.
struct FavoriteButton: View {
    @Environment(Library.self) private var library
    let track: Track

    var body: some View {
        let isFavorite = library.isFavorite(track)
        Button { library.toggleFavorite(track) } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.accentColor : .secondary)
                .accessibilityLabel(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
        .buttonStyle(.borderless)
    }
}
