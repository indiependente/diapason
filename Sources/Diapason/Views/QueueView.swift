import SwiftUI

/// The Up Next panel: reorder by drag, remove with Delete or the context menu, double-click to jump.
struct QueueView: View {
    @Environment(Player.self) private var player
    @State private var selection: Set<PlayQueue.Entry.ID> = []

    var body: some View {
        List(selection: $selection) {
            if let entry = player.queue.currentEntry {
                Section("Now Playing") {
                    QueueRow(entry: entry)
                }
            }
            Section {
                ForEach(player.queue.upcoming) { entry in
                    QueueRow(entry: entry)
                }
                .onMove { source, destination in
                    player.moveUpcoming(fromOffsets: source, toOffset: destination)
                }
            } header: {
                HStack {
                    Text("Up Next")
                    Spacer()
                    Button("Clear") { player.clearUpcoming() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(player.queue.upcoming.isEmpty)
                }
            }
        }
        .contextMenu(forSelectionType: PlayQueue.Entry.ID.self) { ids in
            Button("Play") { ids.first.map { player.jump(to: $0) } }
            Button("Remove from Queue") { remove(ids) }
            TrackMenuItems(tracks: entries(ids).map(\.track), includesQueueing: false)
        } primaryAction: { ids in
            ids.first.map { player.jump(to: $0) }
        }
        .onDeleteCommand { remove(selection) }
        .overlay {
            if player.queue.entries.isEmpty {
                ContentUnavailableView(
                    "Queue is empty",
                    systemImage: "list.bullet",
                    description: Text("Play something, or add tracks with Play Next.")
                )
            }
        }
        .accessibilityIdentifier("queueList")
    }

    private func entries(_ ids: Set<PlayQueue.Entry.ID>) -> [PlayQueue.Entry] {
        player.queue.entries.filter { ids.contains($0.id) }
    }

    private func remove(_ ids: Set<PlayQueue.Entry.ID>) {
        ids.forEach { player.remove($0) }
        selection.subtract(ids)
    }
}

struct QueueRow: View {
    @Environment(Library.self) private var library
    let entry: PlayQueue.Entry

    var body: some View {
        HStack(spacing: 10) {
            Artwork(url: library.artworkURL(for: entry.track.artworkItemID, size: 80), cornerRadius: 4)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.track.title)
                    .lineLimit(1)
                Text(entry.track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(entry.track.duration.trackFormatted)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
