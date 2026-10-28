import AppKit
import SwiftUI

struct Track: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    var position: TimeInterval
    var isPlaying: Bool
    var isShuffling = false
    var source: MediaSource
    /// When `position` was sampled, so the UI can extrapolate between polls.
    var sampledAt: Date

    func currentPosition(at date: Date = .now) -> TimeInterval {
        guard isPlaying else { return position }
        return min(duration, position + date.timeIntervalSince(sampledAt))
    }
}

enum MediaSource: String {
    case music = "com.apple.Music"
    case spotify = "com.spotify.client"

    var displayName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }
}

/// Reads and controls playback in Music and Spotify through Apple Events.
///
/// Scripts are only compiled for apps that are already running, so the user is
/// never prompted to locate an app that isn't installed. Changes arrive through
/// the players' own distributed notifications; the timer is just a slow safety
/// net (polling every second used to cost ~8% CPU while Music was open).
@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage?

    private let queue = DispatchQueue(label: "app.inlet.applescript")
    private var timer: Timer?
    private var artworkKey: String?
    private var observers: [NSObjectProtocol] = []
    private var pendingPoll: DispatchWorkItem?

    /// Players announce track and state changes on these.
    private static let playerNotifications = ["com.apple.Music.playerInfo", "com.spotify.client.PlaybackStateChanged"]

    private var running = false

    func start() {
        guard !running else { return }
        running = true
        let center = DistributedNotificationCenter.default()
        observers = Self.playerNotifications.map { name in
            center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedulePoll() }
            }
        }
        poll()
        rescheduleTimer()
    }

    func stop() {
        running = false
        observers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        observers = []
        timer?.invalidate()
        timer = nil
        withAnimation(IslandModel.settle) { track = nil }
        artwork = nil
        artworkKey = nil
    }

    /// Shows a fixed track without polling (Settings preview, debug renders).
    func injectPreview(_ track: Track?, artwork: NSImage?) {
        self.track = track
        self.artwork = artwork
    }

    // MARK: - Controls

    func togglePlayPause() { send("playpause", optimistic: { $0.isPlaying.toggle() }) }
    func next() { send("next track") }

    func toggleShuffle() {
        guard let source = track?.source else { return }
        track?.isShuffling.toggle()
        let property = source == .spotify ? "shuffling" : "shuffle enabled"
        run("tell application id \"\(source.rawValue)\" to set \(property) to not \(property)") { [weak self] _ in
            self?.poll()
        }
    }
    func previous() { send("previous track") }

    func seek(to seconds: TimeInterval) {
        guard let source = track?.source else { return }
        let value = String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), seconds)
        track?.position = seconds
        track?.sampledAt = .now
        run("tell application id \"\(source.rawValue)\" to set player position to \(value)", cache: false) { _ in }
    }

    func openSourceApp() {
        let id = track?.source.rawValue ?? MediaSource.music.rawValue
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    private func send(_ command: String, optimistic: ((inout Track) -> Void)? = nil) {
        guard let source = track?.source ?? runningSources().first else { return }
        if var t = track, let optimistic {
            optimistic(&t)
            t.position = t.currentPosition()
            t.sampledAt = .now
            track = t
        }
        run("tell application id \"\(source.rawValue)\" to \(command)") { [weak self] _ in
            self?.poll()
        }
    }

    // MARK: - Polling

    private func runningSources() -> [MediaSource] {
        [.spotify, .music].filter {
            !NSRunningApplication.runningApplications(withBundleIdentifier: $0.rawValue).isEmpty
        }
    }

    private func poll() {
        let sources = runningSources()
        guard !sources.isEmpty else {
            update(nil)
            return
        }

        queue.async { [weak self] in
            // Prefer whichever app is actually playing.
            let tracks = sources.compactMap { Self.fetch(from: $0) }
            let best = tracks.first(where: \.isPlaying) ?? tracks.first
            DispatchQueue.main.async { self?.update(best) }
        }
    }

    /// Coalesces bursts of player notifications into one poll.
    private func schedulePoll() {
        pendingPoll?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.poll() }
        pendingPoll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    /// Position is extrapolated between samples, so a playing track only needs
    /// an occasional drift correction; a paused or absent one barely any.
    private func rescheduleTimer() {
        guard running else { return }
        let interval: TimeInterval = track?.isPlaying == true ? 5 : 15
        guard timer?.timeInterval != interval else { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = interval * 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func update(_ new: Track?) {
        defer { rescheduleTimer() }
        let playingChanged = (new?.isPlaying ?? false) != (track?.isPlaying ?? false)
        if playingChanged || (new == nil) != (track == nil) {
            withAnimation(IslandModel.settle) { track = new }
        } else {
            track = new
        }

        guard let new else {
            artwork = nil
            artworkKey = nil
            return
        }
        let key = "\(new.source.rawValue)|\(new.title)|\(new.album)"
        if key != artworkKey {
            artworkKey = key
            loadArtwork(for: new.source, key: key)
        }
    }

    private func loadArtwork(for source: MediaSource, key: String) {
        queue.async { [weak self] in
            switch source {
            case .music:
                let script = "tell application id \"\(source.rawValue)\" to get data of artwork 1 of current track"
                let image = Self.execute(script).flatMap { NSImage(data: $0.data) }
                DispatchQueue.main.async {
                    guard self?.artworkKey == key else { return }
                    withAnimation(.easeOut(duration: 0.2)) { self?.artwork = image }
                }
            case .spotify:
                let script = "tell application id \"\(source.rawValue)\" to get artwork url of current track"
                guard let string = Self.execute(script)?.stringValue, let url = URL(string: string) else { return }
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    let image = data.flatMap(NSImage.init(data:))
                    DispatchQueue.main.async {
                        guard self?.artworkKey == key else { return }
                        withAnimation(.easeOut(duration: 0.2)) { self?.artwork = image }
                    }
                }.resume()
            }
        }
    }

    // MARK: - AppleScript (always on `queue`)

    private nonisolated static func fetch(from source: MediaSource) -> Track? {
        // Spotify reports duration in milliseconds, Music in seconds.
        let duration = source == .spotify ? "((duration of t) / 1000)" : "(duration of t)"
        let shuffle = source == .spotify ? "shuffling" : "shuffle enabled"
        let script = """
        tell application id "\(source.rawValue)"
            if player state is stopped then return "stopped"
            set t to current track
            return {player state as string, name of t, artist of t, album of t, player position as string, \(duration) as string, \(shuffle) as string}
        end tell
        """
        // A list, not a delimited string: track names can contain anything.
        guard let result = execute(script), result.numberOfItems == 7 else { return nil }
        let parts = (1...7).map { result.atIndex($0)?.stringValue ?? "" }
        return Track(title: parts[1],
                     artist: parts[2],
                     album: parts[3],
                     duration: number(parts[5]),
                     position: number(parts[4]),
                     isPlaying: parts[0] == "playing",
                     isShuffling: parts[6] == "true",
                     source: source,
                     sampledAt: .now)
    }

    /// AppleScript formats reals with the user's locale (e.g. "12,5" in Turkish).
    private nonisolated static func number(_ string: String) -> TimeInterval {
        TimeInterval(string.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    /// Compiled scripts, keyed by source. Only touched on `queue`.
    private nonisolated(unsafe) static var compiled: [String: NSAppleScript] = [:]

    private nonisolated static func execute(_ source: String, cache: Bool = true) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let script: NSAppleScript?
        if cache, let existing = compiled[source] {
            script = existing
        } else {
            script = NSAppleScript(source: source)
            guard script?.compileAndReturnError(&error) == true else { return nil }
            if cache { compiled[source] = script }
        }
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    private func run(_ script: String, cache: Bool = true, completion: @escaping @MainActor (NSAppleEventDescriptor?) -> Void) {
        queue.async {
            let result = Self.execute(script, cache: cache)
            DispatchQueue.main.async { completion(result) }
        }
    }
}
