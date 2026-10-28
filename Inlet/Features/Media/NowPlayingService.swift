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
/// never prompted to locate an app that isn't installed.
@MainActor
final class NowPlayingService: ObservableObject {
    @Published private(set) var track: Track?
    @Published private(set) var artwork: NSImage?

    private let queue = DispatchQueue(label: "app.inlet.applescript")
    private var timer: Timer?
    private var artworkKey: String?

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
    }

    func stop() {
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
        run("tell application id \"\(source.rawValue)\" to set player position to \(value)") { _ in }
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

    private func update(_ new: Track?) {
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

    private nonisolated static let separator = "|#|"

    private nonisolated static func fetch(from source: MediaSource) -> Track? {
        // Spotify reports duration in milliseconds, Music in seconds.
        let duration = source == .spotify ? "((duration of t) / 1000)" : "(duration of t)"
        let shuffle = source == .spotify ? "shuffling" : "shuffle enabled"
        let script = """
        tell application id "\(source.rawValue)"
            if player state is stopped then return "stopped"
            set t to current track
            set s to "\(separator)"
            return (player state as string) & s & (name of t) & s & (artist of t) & s & (album of t) & s & (player position as string) & s & (\(duration) as string) & s & (\(shuffle) as string)
        end tell
        """
        guard let result = execute(script)?.stringValue, result != "stopped" else { return nil }
        let parts = result.components(separatedBy: separator)
        guard parts.count == 7 else { return nil }
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

    private nonisolated static func execute(_ source: String) -> NSAppleEventDescriptor? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }

    private func run(_ script: String, completion: @escaping @MainActor (NSAppleEventDescriptor?) -> Void) {
        queue.async {
            let result = Self.execute(script)
            DispatchQueue.main.async { completion(result) }
        }
    }
}
