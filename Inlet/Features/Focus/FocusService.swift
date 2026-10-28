import AppKit

/// The active Focus (Work, Sleep, Do Not Disturb…), read from the Focus
/// database. macOS has no public API for the Focus *name*, and these files
/// need Full Disk Access — without it `hasAccess` is false and nothing shows.
@MainActor
final class FocusService: ObservableObject {
    static let shared = FocusService()

    struct Focus: Equatable {
        let name: String
        let symbol: String
    }

    @Published private(set) var current: Focus?
    @Published private(set) var hasAccess = true

    private var timer: Timer?
    private static let directory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/DoNotDisturb/DB")

    func start() {
        guard timer == nil else { return }
        read()
        let timer = Timer(timeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.read() }
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func read() {
        guard let assertions = try? Data(contentsOf: Self.directory.appendingPathComponent("Assertions.json")),
              let configurations = try? Data(contentsOf: Self.directory.appendingPathComponent("ModeConfigurations.json")) else {
            setAccess(false)
            current = nil
            return
        }
        setAccess(true)
        current = Self.parse(assertions: assertions, configurations: configurations)
    }

    private func setAccess(_ access: Bool) {
        guard access != hasAccess else { return }
        hasAccess = access
        Permissions.publish()
    }

    /// Whether the Focus database can be opened, i.e. Inlet has Full Disk Access.
    static var canReadDatabase: Bool {
        guard let handle = try? FileHandle(forReadingFrom: directory.appendingPathComponent("Assertions.json")) else { return false }
        try? handle.close()
        return true
    }

    static func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func parse(assertions: Data, configurations: Data) -> Focus? {
        guard let assertionRoot = try? JSONSerialization.jsonObject(with: assertions) as? [String: Any],
              let records = ((assertionRoot["data"] as? [[String: Any]])?.first?["storeAssertionRecords"]) as? [[String: Any]],
              let modeID = records.compactMap({ ($0["assertionDetails"] as? [String: Any])?["assertionDetailsModeIdentifier"] as? String }).last
        else { return nil }

        let configRoot = try? JSONSerialization.jsonObject(with: configurations) as? [String: Any]
        let modes = (configRoot?["data"] as? [[String: Any]])?.first?["modeConfigurations"] as? [String: Any]
        let mode = (modes?[modeID] as? [String: Any])?["mode"] as? [String: Any]

        let name = mode?["name"] as? String ?? fallbackName(for: modeID)
        let symbol = mode?["symbolImageName"] as? String ?? "moon.fill"
        return Focus(name: name, symbol: symbol)
    }

    private static func fallbackName(for id: String) -> String {
        if id.contains("work") { return String(localized: "Work") }
        if id.contains("sleep") { return String(localized: "Sleep") }
        if id.contains("personal") { return String(localized: "Personal") }
        if id.contains("driving") { return String(localized: "Driving") }
        return String(localized: "Do Not Disturb")
    }
}
