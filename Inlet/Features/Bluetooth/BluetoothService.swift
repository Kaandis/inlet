import AppKit
import IOBluetooth

/// Announces Bluetooth devices (AirPods, keyboards, mice…) as they connect
/// and disconnect.
///
/// IOBluetooth reports *every* baseband link, including the short background
/// connections AirPods make for automatic switching and battery sync while
/// they're actually playing from an iPhone, and the burst of reconnects after
/// wake. So a connection is only announced once it has lasted a few seconds,
/// and — for audio devices — once it shows up as a real CoreAudio output.
@MainActor
final class BluetoothService: NSObject {
    var onChange: ((_ name: String, _ symbol: String, _ connected: Bool) -> Void)?

    private static let settleDelay: TimeInterval = 4
    private static let quietAfterWake: TimeInterval = 15
    private static let cooldown: TimeInterval = 60

    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotifications: [String: IOBluetoothUserNotification] = [:]
    private var pending: [String: Task<Void, Never>] = [:]
    /// Devices we told the user about; only these get a "disconnected" notice.
    private var announced: Set<String> = []
    private var lastAnnouncement: [String: Date] = [:]
    private var quietUntil = Date.distantFuture
    private var wakeObserver: NSObjectProtocol?

    func start() {
        guard connectNotification == nil else { return }
        quietUntil = .now.addingTimeInterval(Self.settleDelay + 1)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.quietUntil = .now.addingTimeInterval(Self.quietAfterWake)
            }
        }
        connectNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                         selector: #selector(deviceConnected(_:device:)))
    }

    func stop() {
        connectNotification?.unregister()
        connectNotification = nil
        disconnectNotifications.values.forEach { $0.unregister() }
        disconnectNotifications.removeAll()
        pending.values.forEach { $0.cancel() }
        pending.removeAll()
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        disconnectNotifications[address]?.unregister()
        disconnectNotifications[address] = device.register(forDisconnectNotification: self,
                                                           selector: #selector(deviceDisconnected(_:device:)))

        pending[address]?.cancel()
        pending[address] = Task { [weak self] in
            // The audio route can trail the link by a few seconds; check a few times.
            var meaningful = false
            for attempt in 0..<3 {
                try? await Task.sleep(for: .seconds(attempt == 0 ? Self.settleDelay : 3))
                guard !Task.isCancelled, let self, device.isConnected() else { return }
                if self.isMeaningful(device) {
                    meaningful = true
                    break
                }
            }
            guard let self else { return }
            self.pending[address] = nil
            guard meaningful else { return }
            // Remember it either way so a later disconnect can be announced,
            // but stay silent during launch / wake reconnect bursts.
            self.announced.insert(address)
            guard Date.now >= self.quietUntil, !self.isCoolingDown(address) else { return }
            self.lastAnnouncement[address] = .now
            self.onChange?(Self.name(of: device), Self.symbol(for: device), true)
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        notification.unregister()
        guard let address = device.addressString else { return }
        disconnectNotifications[address] = nil

        // A link that dropped before settling was never announced: say nothing.
        if let task = pending.removeValue(forKey: address) {
            task.cancel()
            return
        }
        guard announced.remove(address) != nil,
              Date.now >= quietUntil,
              !isCoolingDown(address) else { return }
        lastAnnouncement[address] = .now
        onChange?(Self.name(of: device), Self.symbol(for: device), false)
    }

    private func isCoolingDown(_ address: String) -> Bool {
        guard let last = lastAnnouncement[address] else { return false }
        return Date.now.timeIntervalSince(last) < Self.cooldown
    }

    /// Audio devices only count once macOS routes audio to them.
    private func isMeaningful(_ device: IOBluetoothDevice) -> Bool {
        guard device.deviceClassMajor == UInt32(kBluetoothDeviceClassMajorAudio) else { return true }
        let name = Self.name(of: device).lowercased()
        return AudioDevices.bluetoothOutputs().contains { $0.name.lowercased() == name }
    }

    private static func name(of device: IOBluetoothDevice) -> String {
        device.name ?? String(localized: "Bluetooth device")
    }

    static func symbol(forName rawName: String, audio: Bool) -> String {
        let name = rawName.lowercased()
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        if name.contains("beats") { return "beats.headphones" }
        return audio ? "headphones" : "dot.radiowaves.left.and.right"
    }

    private static func symbol(for device: IOBluetoothDevice) -> String {
        let name = (device.name ?? "").lowercased()
        switch device.deviceClassMajor {
        case UInt32(kBluetoothDeviceClassMajorAudio):
            return symbol(forName: name, audio: true)
        case UInt32(kBluetoothDeviceClassMajorPeripheral):
            if name.contains("keyboard") || name.contains("klavye") { return "keyboard" }
            if name.contains("trackpad") { return "rectangle.and.hand.point.up.left" }
            return "computermouse"
        case UInt32(kBluetoothDeviceClassMajorPhone):
            return "iphone"
        default:
            return symbol(forName: name, audio: false)
        }
    }
}
