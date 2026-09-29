import SwiftUI

struct AlbumsView: View {
    @Environment(Library.self) private var library
    @State private var query = ""

    private var albums: [MusicCollection] {
        guard !query.isEmpty else {
            return library.albums
        }

        return library.albums.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.artist?
                .localizedCaseInsensitiveContains(query) == true
        }
    }

    var body: some View {
        NavigationStack {
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
                    }
                }
                .padding(20)
            }
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
        .searchable(text: $query, placement: .toolbar, prompt: "Albums or artists")
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
            Text(album.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
