import Foundation
import IOKit.ps

/// Watches the internal battery through IOPowerSources change notifications.
@MainActor
final class BatteryService: ObservableObject {
    @Published private(set) var level = 100
    @Published private(set) var isCharging = false
    @Published private(set) var isPluggedIn = false
    @Published private(set) var hasBattery = false

    var onPluggedIn: ((Int, Bool) -> Void)?
    var onLowBattery: ((Int) -> Void)?

    private var runLoopSource: CFRunLoopSource?
    private var warnedLow = false
    private var started = false

    func start() {
        guard runLoopSource == nil else { return }
        read()
        started = true

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let service = Unmanaged<BatteryService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.read() }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        runLoopSource = source
    }

    #if DEBUG
    func injectPreview(level: Int, charging: Bool) {
        self.level = level
        self.isCharging = charging
        self.isPluggedIn = charging
        self.hasBattery = true
    }
    #endif

    private func read() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else { return }

        for ps in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, ps)?.takeUnretainedValue() as? [String: Any],
                  desc[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }

            let current = desc[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = desc[kIOPSMaxCapacityKey] as? Int ?? 100
            let newLevel = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            let newCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
            let newPlugged = desc[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue

            let justPlugged = started && newPlugged && !isPluggedIn
            hasBattery = true
            level = newLevel
            isCharging = newCharging
            isPluggedIn = newPlugged

            if justPlugged { onPluggedIn?(newLevel, newCharging) }

            if !newPlugged && newLevel <= 20 && !warnedLow {
                warnedLow = true
                if started { onLowBattery?(newLevel) }
            } else if newPlugged || newLevel > 25 {
                warnedLow = false
            }
            return
        }
    }
}
