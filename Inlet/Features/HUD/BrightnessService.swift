import CoreGraphics
import Foundation

/// Samples the built-in display brightness via the private DisplayServices
/// framework. There is no public change notification, so it polls cheaply.
@MainActor
final class BrightnessService {
    var onChange: ((Float) -> Void)?

    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private let getBrightness: GetBrightness? = {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let symbol = dlsym(handle, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(symbol, to: GetBrightness.self)
    }()

    private var timer: Timer?
    private var last: Float?
    private var display: CGDirectDisplayID?

    /// Only polls when there's a built-in panel to read — on a desk setup with
    /// just external monitors it does nothing at all.
    func start() {
        guard timer == nil, getBrightness != nil, let display = builtInDisplay() else { return }
        self.display = display
        last = read()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
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

    private func builtInDisplay() -> CGDirectDisplayID? {
        var ids = [CGDirectDisplayID](repeating: 0, count: 8)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(8, &ids, &count)
        return ids.prefix(Int(count)).first(where: { CGDisplayIsBuiltin($0) != 0 })
    }

    private func read() -> Float? {
        guard let getBrightness, let display else { return nil }
        var value: Float = 0
        return getBrightness(display, &value) == 0 ? value : nil
    }

    private func tick() {
        guard let value = read() else { return }
        defer { last = value }
        guard let last, abs(last - value) > 0.004 else { return }
        onChange?(value)
    }
}
