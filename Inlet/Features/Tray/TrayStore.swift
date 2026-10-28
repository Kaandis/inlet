import AppKit
import SwiftUI

struct TrayItem: Identifiable, Equatable {
    let url: URL
    var id: URL { url }
    var name: String { url.lastPathComponent }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}

/// Files parked on the island. Stores references (not copies), persisted
/// across launches; items whose file has disappeared are dropped on load.
@MainActor
final class TrayStore: ObservableObject {
    @Published private(set) var items: [TrayItem] = []

    /// nil keeps the tray in memory only (used by the preview renderer).
    private let key: String?

    init(persistenceKey: String? = "trayItems") {
        key = persistenceKey
        let paths = persistenceKey.flatMap { UserDefaults.standard.stringArray(forKey: $0) } ?? []
        items = paths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .map(TrayItem.init)
    }

    func add(_ urls: [URL]) {
        let existing = Set(items.map(\.url))
        let new = urls.filter { !existing.contains($0) }.map(TrayItem.init)
        guard !new.isEmpty else { return }
        withAnimation(IslandModel.settle) { items.append(contentsOf: new) }
        save()
    }

    func remove(_ item: TrayItem) {
        withAnimation(IslandModel.settle) { items.removeAll { $0 == item } }
        save()
    }

    func clear() {
        withAnimation(IslandModel.settle) { items.removeAll() }
        save()
    }

    func open(_ item: TrayItem) {
        NSWorkspace.shared.open(item.url)
    }

    func revealInFinder(_ item: TrayItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    static func airDrop(_ urls: [URL]) {
        guard !urls.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        NSApp.activate()
        service.perform(withItems: urls)
    }

    private func save() {
        guard let key else { return }
        UserDefaults.standard.set(items.map(\.url.path), forKey: key)
    }
}

extension NSItemProvider {
    /// Resolves every file URL carried by a set of drag providers.
    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        await withTaskGroup(of: URL?.self) { group in
            for provider in providers where provider.canLoadObject(ofClass: URL.self) {
                group.addTask {
                    await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in
                            continuation.resume(returning: url?.isFileURL == true ? url : nil)
                        }
                    }
                }
            }
            var urls: [URL] = []
            for await url in group { if let url { urls.append(url) } }
            return urls
        }
    }
}
