import SwiftUI

struct AlbumsView: View {
    @Environment(Library.self) private var library
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.albumsPath) {
            AlbumGrid(albums: library.albums)
                .navigationTitle("Albums")
                .navigationDestination(for: MusicCollection.self) { album in
                    TrackListView(collection: album)
                }
                .overlay {
                    if library.albums.isEmpty, library.isLoading {
                        ProgressView()
                    }
                }
        }
    }
}

/// A scrolling grid of album covers. Each cell links to the album's tracks.
struct AlbumGrid: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    let albums: [MusicCollection]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)], spacing: 24) {
                ForEach(albums) { album in
                    NavigationLink(value: album) {
                        AlbumCell(
                            album: album,
                            artworkURL: library.artworkURL(for: album.hasArtwork ? album.id : nil, size: 400)
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Play") { queue(album) { player.play($0) } }
                        Button("Play Next") { queue(album, player.playNext) }
                        Button("Add to Queue") { queue(album, player.addToQueue) }
                    }
                }
            }
            .padding(20)
        }
    }

    private func queue(_ album: MusicCollection, _ action: @escaping @MainActor ([Track]) -> Void) {
        Task {
            if let tracks = try? await library.tracks(in: album) {
                action(tracks)
            }
        }
    }
}

struct AlbumCell: View {
    let album: MusicCollection
    let artworkURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Artwork(url: artworkURL)
                .aspectRatio(1, contentMode: .fit)
                .shadow(radius: 2, y: 1)
            Text(album.name)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Text(album.year.map(String.init) ?? album.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
