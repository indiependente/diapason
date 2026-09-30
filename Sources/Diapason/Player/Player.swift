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
        didSet {
            // While paused the output sits at zero after the fade-out; resume ramps up to the new level.
            if isPlaying {
                fadeTask?.cancel()
                avPlayer.volume = volume
            }
        }
    }

    var isShuffled = UserDefaults.standard.bool(forKey: "shuffle") {
        didSet {
            queue.setShuffled(isShuffled)
            UserDefaults.standard.set(isShuffled, forKey: "shuffle")
        }
    }

    var repeatMode = RepeatMode(rawValue: UserDefaults.standard.string(forKey: "repeat") ?? "") ?? .off {
        didSet { UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeat") }
    }

    var current: Track? {
        queue.current
    }

    private let library: Library
    private let avPlayer = AVPlayer()
    private let nowPlaying = NowPlaying()
    private var lastReport: TimeInterval = 0
    private var timeObserver: Any?
    private var fadeTask: Task<Void, Never>?

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
            Task { @MainActor in self?.trackEnded() }
        }
        // Tell the server the session ended, or it keeps showing the track as playing after quit.
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.report(.stopped) }
        }
    }

    /// Starts a new queue. With shuffle on and no index, a random track starts.
    func play(_ tracks: [Track], from index: Int? = nil) {
        report(.stopped)
        queue = PlayQueue(tracks: tracks, index: index ?? (isShuffled ? Int.random(in: 0 ..< max(tracks.count, 1)) : 0))
        queue.setShuffled(isShuffled)
        load()
    }

    // MARK: Queue editing

    /// Queues tracks after the current one, or starts them when nothing plays.
    func playNext(_ tracks: [Track]) {
        if current == nil {
            play(tracks)
        } else {
            queue.insertNext(tracks)
        }
    }

    /// Queues tracks at the end, or starts them when nothing plays.
    func addToQueue(_ tracks: [Track]) {
        if current == nil {
            play(tracks)
        } else {
            queue.append(tracks)
        }
    }

    func remove(_ id: PlayQueue.Entry.ID) {
        let wasCurrent = queue.currentEntry?.id == id
        if wasCurrent {
            report(.stopped)
        }
        queue.remove(id)
        guard wasCurrent else {
            return
        }
        if current != nil {
            load()
        } else {
            stop()
        }
    }

    func moveUpcoming(fromOffsets source: IndexSet, toOffset destination: Int) {
        queue.moveUpcoming(fromOffsets: source, toOffset: destination)
    }

    func jump(to id: PlayQueue.Entry.ID) {
        report(.stopped)
        if queue.jump(to: id) {
            load()
        }
    }

    func clearUpcoming() {
        queue.clearUpcoming()
    }

    // MARK: Transport

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        guard current != nil, isPlaying else {
            return
        }
        isPlaying = false
        syncNowPlaying()
        report(.progress)
        fade(to: 0) { [avPlayer] in avPlayer.pause() }
    }

    func resume() {
        guard current != nil, !isPlaying else {
            return
        }
        isPlaying = true
        avPlayer.volume = 0
        avPlayer.play()
        fade(to: volume)
        syncNowPlaying()
        report(.progress)
    }

    /// Ramps the output volume over 200 ms so pause and resume do not click.
    private func fade(to target: Float, then completion: (@MainActor () -> Void)? = nil) {
        fadeTask?.cancel()
        let start = avPlayer.volume
        let steps = 10
        fadeTask = Task {
            for step in 1 ... steps {
                try? await Task.sleep(for: .milliseconds(20))
                guard !Task.isCancelled else {
                    return
                }
                avPlayer.volume = start + (target - start) * Float(step) / Float(steps)
            }
            completion?()
        }
    }

    func next() {
        report(.stopped)
        if queue.advance() {
            load()
        } else if repeatMode == .all, !queue.tracks.isEmpty {
            queue.restart()
            load()
        } else {
            stop()
        }
    }

    /// Repeat-one replays the track. Otherwise the queue moves on like a manual skip.
    private func trackEnded() {
        if repeatMode == .one {
            seek(to: 0)
            avPlayer.play()
        } else {
            next()
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
        fadeTask?.cancel()
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
        fadeTask?.cancel()
        avPlayer.volume = volume
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
