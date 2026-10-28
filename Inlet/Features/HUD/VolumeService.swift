import AudioToolbox
import CoreAudio
import Foundation

/// Listens for output volume / mute changes on the current default device.
@MainActor
final class VolumeService {
    var onChange: ((Float, Bool) -> Void)?

    private var device = AudioObjectID(kAudioObjectUnknown)
    private var lastValue: (Float, Bool)?
    /// Kept as one instance so it can be removed when the default device changes.
    /// Registered on the main queue, so it always runs on the main thread.
    private lazy var listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        MainActor.assumeIsolated { self?.emit() }
    }

    private static var defaultDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    private static var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)
    private static var muteAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyMute,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain)

    func start() {
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.attachToDefaultDevice() }
        }
        attachToDefaultDevice()
    }

    private func attachToDefaultDevice() {
        if device != kAudioObjectUnknown {
            AudioObjectRemovePropertyListenerBlock(device, &Self.volumeAddress, .main, listener)
            AudioObjectRemovePropertyListenerBlock(device, &Self.muteAddress, .main, listener)
        }

        var id = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &Self.defaultDeviceAddress, 0, nil, &size, &id)
        device = id
        lastValue = read()

        AudioObjectAddPropertyListenerBlock(device, &Self.volumeAddress, .main, listener)
        AudioObjectAddPropertyListenerBlock(device, &Self.muteAddress, .main, listener)
    }

    private func read() -> (Float, Bool)? {
        guard device != kAudioObjectUnknown else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &Self.volumeAddress, 0, nil, &size, &volume)
        guard status == noErr else { return nil }

        var muted = UInt32(0)
        size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(device, &Self.muteAddress, 0, nil, &size, &muted)
        return (volume, muted != 0)
    }

    fileprivate func emit() {
        guard let value = read() else { return }
        defer { lastValue = value }
        if let last = lastValue, abs(last.0 - value.0) < 0.001, last.1 == value.1 { return }
        onChange?(value.0, value.1)
    }
}
