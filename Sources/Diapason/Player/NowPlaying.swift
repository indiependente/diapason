import AppKit
import MediaPlayer

/// Builds the dictionary that macOS shows in Control Center and on the media keys.
enum NowPlayingInfo {
    static func dictionary(track: Track, elapsed: TimeInterval, rate: Double) -> [String: Any] {
        [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
    }
}

/// Bridges the player to the system Now Playing controls and the remote commands.
@MainActor
final class NowPlaying {
    struct Handlers {
        var play: @MainActor () -> Void = {}
        var pause: @MainActor () -> Void = {}
        var toggle: @MainActor () -> Void = {}
        var next: @MainActor () -> Void = {}
        var previous: @MainActor () -> Void = {}
        var seek: @MainActor (TimeInterval) -> Void = { _ in }
    }

    private let center = MPNowPlayingInfoCenter.default()

    func install(_ handlers: Handlers) {
        let commands = MPRemoteCommandCenter.shared()
        bind(commands.playCommand) { handlers.play() }
        bind(commands.pauseCommand) { handlers.pause() }
        bind(commands.togglePlayPauseCommand) { handlers.toggle() }
        bind(commands.nextTrackCommand) { handlers.next() }
        bind(commands.previousTrackCommand) { handlers.previous() }
        commands.changePlaybackPositionCommand.addTarget { event in
            guard let position = (event as? MPChangePlaybackPositionCommandEvent)?.positionTime else {
                return .commandFailed
            }
            Task { @MainActor in handlers.seek(position) }

            return .success
        }
    }

    func update(track: Track, elapsed: TimeInterval, rate: Double, artwork: NSImage?) {
        var info = NowPlayingInfo.dictionary(track: track, elapsed: elapsed, rate: rate)
        if let artwork {
            // MediaPlayer calls the handler on its own queue, so the closure must not inherit main-actor isolation.
            nonisolated(unsafe) let image = artwork
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { @Sendable _ in image }
        }
        center.nowPlayingInfo = info
        center.playbackState = rate > 0 ? .playing : .paused
    }

    func clear() {
        center.nowPlayingInfo = nil
        center.playbackState = .stopped
    }

    private func bind(_ command: MPRemoteCommand, _ action: @escaping @MainActor () -> Void) {
        command.isEnabled = true
        command.addTarget { _ in
            Task { @MainActor in action() }

            return .success
        }
    }
}
