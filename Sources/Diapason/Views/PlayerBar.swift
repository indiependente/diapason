import SwiftUI

struct PlayerBar: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @State private var scrubTime: TimeInterval?

    var body: some View {
        @Bindable var player = player
        HStack(spacing: 24) {
            transport
            Spacer(minLength: 0)
            nowPlaying
                .frame(maxWidth: 560)
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                Image(systemName: "speaker.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Volume")
                Slider(value: $player.volume, in: 0 ... 1)
                    .frame(width: 100)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var transport: some View {
        HStack(spacing: 18) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .accessibilityLabel("Previous")
            }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .frame(width: 32)
                    .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            }
            .accessibilityIdentifier("playPauseButton")
            Button { player.next() } label: {
                Image(systemName: "forward.fill")
                    .accessibilityLabel("Next")
            }
        }
        .font(.title3)
        .buttonStyle(.borderless)
        .disabled(player.current == nil)
    }

    @ViewBuilder
    private var nowPlaying: some View {
        if let track = player.current {
            HStack(spacing: 12) {
                Group {
                    if let artwork = player.artwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    } else {
                        Artwork(url: nil, cornerRadius: 4)
                    }
                }
                .frame(width: 48, height: 48)
                VStack(spacing: 2) {
                    Text(track.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .accessibilityIdentifier("nowPlayingTitle")
                    Text("\(track.artist) — \(track.album)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text((scrubTime ?? player.currentTime).trackFormatted)
                        Slider(
                            value: Binding(
                                get: { scrubTime ?? min(player.currentTime, track.duration) },
                                set: { scrubTime = $0 }
                            ),
                            in: 0 ... max(track.duration, 1)
                        ) { editing in
                            guard !editing, let scrubTime else {
                                return
                            }
                            player.seek(to: scrubTime)
                            self.scrubTime = nil
                        }
                        .controlSize(.mini)
                        Text("-" + (track.duration - (scrubTime ?? player.currentTime)).trackFormatted)
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Not playing")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
