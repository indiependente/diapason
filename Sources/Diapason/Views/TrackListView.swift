import SwiftUI

struct TrackListView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    let collection: MusicCollection
    @State private var tracks: [Track] = []
    @State private var selection: Set<Track.ID> = []
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            Table(tracks, selection: $selection) {
                TableColumn("#") { track in
                    if player.current?.id == track.id {
                        Image(systemName: player.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                            .foregroundStyle(Color.accentColor)
                            .accessibilityLabel("Now playing")
                    } else {
                        Text(track.trackNumber.map(String.init) ?? "")
                            .foregroundStyle(.secondary)
                    }
                }
                .width(28)
                TableColumn("Title") { track in
                    Text(track.title)
                        .fontWeight(player.current?.id == track.id ? .semibold : .regular)
                }
                TableColumn("Artist", value: \.artist)
                TableColumn("Album", value: \.album)
                TableColumn("Format") { track in
                    Text(track.media?.format ?? "")
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 110)
                TableColumn("kbps") { track in
                    Text(track.media?.kbps.map(String.init) ?? "")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(48)
                TableColumn("Time") { track in
                    Text(track.duration.trackFormatted)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .width(56)
            }
            .contextMenu(forSelectionType: Track.ID.self) { ids in
                Button("Play") { play(from: ids.first) }
            } primaryAction: { ids in
                play(from: ids.first)
            }
        }
        .navigationTitle(collection.name)
        .overlay {
            if let errorMessage {
                ContentUnavailableView(
                    "Could not load tracks",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            }
        }
        .task(id: collection.id) {
            tracks = []
            do {
                tracks = try await library.tracks(in: collection)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 20) {
            Artwork(
                url: library.artworkURL(for: collection.hasArtwork ? collection.id : nil, size: 400),
                cornerRadius: 8
            )
            .frame(width: 160, height: 160)
            .shadow(radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(collection.name)
                    .font(.title.bold())
                    .lineLimit(2)
                Text(collection.subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("\(tracks.count) songs, \(tracks.reduce(0) { $0 + $1.duration }.trackFormatted)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Play", systemImage: "play.fill") { player.play(tracks) }
                        .buttonStyle(.borderedProminent)
                    Button("Shuffle", systemImage: "shuffle") {
                        player.isShuffled = true
                        player.play(tracks)
                    }
                    .buttonStyle(.bordered)
                }
                .disabled(tracks.isEmpty)
                .padding(.top, 8)
            }
            Spacer()
        }
        .padding(20)
    }

    private func play(from id: Track.ID?) {
        guard let index = tracks.firstIndex(where: { $0.id == id }) else {
            return
        }
        player.play(tracks, from: index)
    }
}
