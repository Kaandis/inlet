import AppKit

/// Watches Caps Lock without needing Accessibility permission by sampling the
/// current modifier flags.
@MainActor
final class CapsLockService {
    var onChange: ((Bool) -> Void)?

    private var timer: Timer?
    private var last = NSEvent.modifierFlags.contains(.capsLock)

    func start() {
        guard timer == nil else { return }
        last = NSEvent.modifierFlags.contains(.capsLock)
        let timer = Timer(timeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let on = NSEvent.modifierFlags.contains(.capsLock)
        guard on != last else { return }
        last = on
        onChange?(on)
    }
}
