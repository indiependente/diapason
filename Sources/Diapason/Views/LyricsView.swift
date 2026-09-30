import SwiftUI

/// Lyrics of the playing song. Synced lyrics follow playback, and a click on a line seeks to it.
struct LyricsView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @State private var lines: [LyricLine] = []
    @State private var isLoading = false

    private var currentIndex: Int? {
        LyricLine.currentIndex(in: lines, at: player.currentTime)
    }

    var body: some View {
        Group {
            if let track = player.current {
                if lines.isEmpty {
                    ContentUnavailableView(
                        isLoading ? "Loading lyrics…" : "No lyrics",
                        systemImage: "music.microphone",
                        description: Text(isLoading ? "" : "The server has no lyrics for “\(track.title)”.")
                    )
                } else {
                    lyrics
                }
            } else {
                ContentUnavailableView("Nothing playing", systemImage: "music.microphone")
            }
        }
        .task(id: player.current?.id) {
            lines = []
            guard let track = player.current else {
                return
            }
            isLoading = true
            defer { isLoading = false }
            lines = await (try? library.lyrics(for: track)) ?? []
        }
        .accessibilityIdentifier("lyricsPanel")
    }

    private var lyrics: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(.title3.weight(index == currentIndex ? .semibold : .regular))
                            .foregroundStyle(index == currentIndex || line.start == nil ? .primary : .secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let start = line.start {
                                    player.seek(to: start)
                                }
                            }
                            .id(index)
                    }
                }
                .padding(20)
            }
            .onChange(of: currentIndex) { _, index in
                if let index {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }
}
