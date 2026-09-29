import AppKit
import AVFoundation
import Observation

/// Streams the queue through AVPlayer and mirrors its state to Now Playing and to the server.
@Observable
@MainActor
final class Player {
    private(set) var queue = PlayQueue()
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var artwork: NSImage?
    var volume: Float = 1 {
        didSet { avPlayer.volume = volume }
    }

    var current: Track? {
        queue.current
    }

    private let library: Library
    private let avPlayer = AVPlayer()
    private let nowPlaying = NowPlaying()
    private var lastReport: TimeInterval = 0
    private var timeObserver: Any?

    init(library: Library) {
        self.library = library
        nowPlaying.install(NowPlaying.Handlers(
            play: { [weak self] in self?.resume() },
            pause: { [weak self] in self?.pause() },
            toggle: { [weak self] in self?.togglePlayPause() },
            next: { [weak self] in self?.next() },
            previous: { [weak self] in self?.previous() },
            seek: { [weak self] in self?.seek(to: $0) }
        ))
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in self?.tick(time.seconds) }
        }
        NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.next() }
        }
        // Tell the server the session ended, or it keeps showing the track as playing after quit.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.report(.stopped) }
        }
    }

    func play(_ tracks: [Track], from index: Int = 0) {
        report(.stopped)
        queue = PlayQueue(tracks: tracks, index: index)
        load()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        guard current != nil else {
            return
        }
        avPlayer.pause()
        isPlaying = false
        syncNowPlaying()
        report(.progress)
    }

    func resume() {
        guard current != nil else {
            return
        }
        avPlayer.play()
        isPlaying = true
        syncNowPlaying()
        report(.progress)
    }

    func next() {
        report(.stopped)
        if queue.advance() {
            load()
        } else {
            stop()
        }
    }

    /// Restarts the track after three seconds, like most players. Before that it goes back.
    func previous() {
        if currentTime > 3 || !queue.hasPrevious {
            seek(to: 0)
        } else {
            report(.stopped)
            _ = queue.retreat()
            load()
        }
    }

    func seek(to seconds: TimeInterval) {
        avPlayer.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        currentTime = seconds
        syncNowPlaying()
    }

    func stop() {
        avPlayer.replaceCurrentItem(with: nil)
        queue = PlayQueue()
        isPlaying = false
        currentTime = 0
        artwork = nil
        nowPlaying.clear()
    }

    private func load() {
        guard let track = current, let client = library.client else {
            stop()

            return
        }
        avPlayer.replaceCurrentItem(with: AVPlayerItem(url: client.streamURL(for: track)))
        avPlayer.play()
        isPlaying = true
        currentTime = 0
        lastReport = 0
        artwork = nil
        syncNowPlaying()
        report(.start)
        Task {
            guard let url = library.artworkURL(for: track.artworkItemID, size: 600),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  current?.id == track.id
            else {
                return
            }
            artwork = NSImage(data: data)
            syncNowPlaying()
        }
    }

    private func tick(_ seconds: TimeInterval) {
        guard seconds.isFinite, current != nil else {
            return
        }
        currentTime = seconds
        if isPlaying, seconds - lastReport >= 10 {
            lastReport = seconds
            report(.progress)
        }
    }

    private func syncNowPlaying() {
        guard let track = current else {
            return
        }
        nowPlaying.update(track: track, elapsed: currentTime, rate: isPlaying ? 1 : 0, artwork: artwork)
    }

    private func report(_ event: PlaybackEvent) {
        guard let track = current, let client = library.client else {
            return
        }
        let position = currentTime
        let paused = !isPlaying
        Task { try? await client.report(event, track: track, position: position, isPaused: paused) }
    }
}
