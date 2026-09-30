import SwiftUI

struct ArtistsView: View {
    @Environment(Library.self) private var library
    @Environment(Navigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.artistsPath) {
            List(library.artists) { artist in
                NavigationLink(value: artist) {
                    HStack(spacing: 12) {
                        Artwork(
                            url: library.artworkURL(for: artist.hasArtwork ? artist.id : nil, size: 120),
                            cornerRadius: 20
                        )
                        .frame(width: 40, height: 40)
                        Text(artist.name)
                    }
                    .padding(.vertical, 2)
                }
            }
            .navigationTitle("Artists")
            .navigationDestination(for: Artist.self) { artist in
                ArtistView(artist: artist)
            }
            .navigationDestination(for: MusicCollection.self) { album in
                TrackListView(collection: album)
            }
        }
    }
}

struct ArtistView: View {
    @Environment(Library.self) private var library
    let artist: Artist
    @State private var albums: [MusicCollection] = []
    @State private var errorMessage: String?

    var body: some View {
        AlbumGrid(albums: albums)
            .navigationTitle(artist.name)
            .overlay {
                if let errorMessage {
                    ContentUnavailableView(
                        "Could not load albums",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                }
            }
            .task(id: artist.id) {
                do {
                    albums = try await library.albums(by: artist)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
    }
}
