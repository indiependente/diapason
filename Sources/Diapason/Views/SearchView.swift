import SwiftUI

/// Library-wide results: artists and albums from the loaded lists, songs from the server.
struct SearchView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    let query: String
    @State private var tracks: [Track] = []
    @State private var isSearching = false
    @State private var selection: Set<Track.ID> = []

    private var artists: [Artist] {
        Array(library.artists.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(10))
    }

    private var albums: [MusicCollection] {
        Array(library.albums.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.artist?
                .localizedCaseInsensitiveContains(query) == true
        }.prefix(10))
    }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                if !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists) { artist in
                            NavigationLink(value: artist) {
                                Label {
                                    Text(artist.name)
                                } icon: {
                                    Artwork(
                                        url: library.artworkURL(for: artist.hasArtwork ? artist.id : nil, size: 80),
                                        cornerRadius: 14
                                    )
                                    .frame(width: 28, height: 28)
                                }
                            }
                        }
                    }
                }
                if !albums.isEmpty {
                    Section("Albums") {
                        ForEach(albums) { album in
                            NavigationLink(value: album) {
                                Label {
                                    Text(album.name) + Text("  \(album.subtitle)").foregroundStyle(.secondary)
                                } icon: {
                                    Artwork(
                                        url: library.artworkURL(for: album.hasArtwork ? album.id : nil, size: 80),
                                        cornerRadius: 4
                                    )
                                    .frame(width: 28, height: 28)
                                }
                            }
                        }
                    }
                }
                Section("Songs") {
                    ForEach(tracks) { track in
                        SearchTrackRow(track: track, isPlaying: player.current?.id == track.id)
                            .tag(track.id)
                    }
                    if tracks.isEmpty {
                        Text(isSearching ? "Searching…" : "No songs match “\(query)”.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contextMenu(forSelectionType: Track.ID.self) { ids in
                Button("Play") { play(from: ids.first) }
                TrackMenuItems(tracks: selected(ids))
            } primaryAction: { ids in
                play(from: ids.first)
            }
            .navigationTitle("Search")
            .navigationDestination(for: Artist.self) { artist in
                ArtistView(artist: artist)
            }
            .navigationDestination(for: MusicCollection.self) { album in
                TrackListView(collection: album)
            }
        }
        .task(id: query) {
            // Wait for typing to settle before asking the server.
            isSearching = true
            defer { isSearching = false }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else {
                return
            }
            tracks = await (try? library.searchTracks(query)) ?? []
        }
    }

    private func selected(_ ids: Set<Track.ID>) -> [Track] {
        tracks.filter { ids.contains($0.id) }
    }

    /// Plays the results as a queue, starting at the chosen song.
    private func play(from id: Track.ID?) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else {
            return
        }
        player.play(tracks, from: index)
    }
}

struct SearchTrackRow: View {
    @Environment(Library.self) private var library
    let track: Track
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 10) {
            Artwork(url: library.artworkURL(for: track.artworkItemID, size: 80), cornerRadius: 4)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Now playing")
                    }
                    Text(track.title)
                        .fontWeight(isPlaying ? .semibold : .regular)
                        .lineLimit(1)
                }
                Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: "  ·  "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(track.media?.format ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(track.duration.trackFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
