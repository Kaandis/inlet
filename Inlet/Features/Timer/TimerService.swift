import AppKit
import SwiftUI

/// One simple countdown. The UI derives the remaining time from `endDate`
/// (or `pausedRemaining`), so nothing ticks unless something is on screen.
@MainActor
final class TimerService: ObservableObject {
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining: TimeInterval?

    var onFinish: (() -> Void)?

    static let presets: [TimeInterval] = [60, 5 * 60, 10 * 60, 25 * 60]

    private var task: Task<Void, Never>?

    var isActive: Bool { endDate != nil || pausedRemaining != nil }
    var isRunning: Bool { endDate != nil }

    func remaining(at date: Date = .now) -> TimeInterval {
        if let pausedRemaining { return pausedRemaining }
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(date))
    }

    func progress(at date: Date = .now) -> Double {
        guard duration > 0 else { return 0 }
        return 1 - remaining(at: date) / duration
    }

    func start(_ seconds: TimeInterval) {
        withAnimation(IslandModel.settle) {
            duration = seconds
            pausedRemaining = nil
            endDate = .now.addingTimeInterval(seconds)
        }
        schedule()
    }

    func pause() {
        guard let endDate else { return }
        task?.cancel()
        withAnimation(IslandModel.settle) {
            pausedRemaining = max(0, endDate.timeIntervalSinceNow)
            self.endDate = nil
        }
    }

    func resume() {
        guard let pausedRemaining else { return }
        withAnimation(IslandModel.settle) {
            endDate = .now.addingTimeInterval(pausedRemaining)
            self.pausedRemaining = nil
        }
        schedule()
    }

    func cancel() {
        task?.cancel()
        withAnimation(IslandModel.settle) {
            endDate = nil
            pausedRemaining = nil
            duration = 0
        }
    }

    private func schedule() {
        task?.cancel()
        guard let endDate else { return }
        task = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, endDate.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self else { return }
            self.cancel()
            NSSound(named: "Glass")?.play()
            self.onFinish?()
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
