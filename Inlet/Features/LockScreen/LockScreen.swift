import AppKit

/// Hosts windows in a private SkyLight space that sits above the lock screen,
/// so the island stays visible (and alive) while the Mac is locked.
///
/// Same technique as the MIT-licensed SkyLightWindow package by Lakr233.
/// These are private APIs: if Apple removes them, `delegate` quietly does nothing.
@MainActor
final class LockScreenSpace {
    static let shared = LockScreenSpace()

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias SpaceAddWindows = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32

    /// Level used by Notification Center on the lock screen.
    private static let notificationCenterAtLockLevel: Int32 = 400

    private let connection: Int32
    private let space: Int32
    private let addWindows: SpaceAddWindows?

    private init() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight", RTLD_NOW),
              let mainConnection = dlsym(handle, "SLSMainConnectionID"),
              let create = dlsym(handle, "SLSSpaceCreate"),
              let setLevel = dlsym(handle, "SLSSpaceSetAbsoluteLevel"),
              let show = dlsym(handle, "SLSShowSpaces"),
              let add = dlsym(handle, "SLSSpaceAddWindowsAndRemoveFromSpaces") else {
            connection = 0
            space = 0
            addWindows = nil
            return
        }

        connection = unsafeBitCast(mainConnection, to: MainConnectionID.self)()
        space = unsafeBitCast(create, to: SpaceCreate.self)(connection, 1, 0)
        _ = unsafeBitCast(setLevel, to: SpaceSetAbsoluteLevel.self)(connection, space, Self.notificationCenterAtLockLevel)
        _ = unsafeBitCast(show, to: ShowSpaces.self)(connection, [space] as CFArray)
        addWindows = unsafeBitCast(add, to: SpaceAddWindows.self)
    }

    func delegate(_ window: NSWindow) {
        guard let addWindows, window.windowNumber > 0 else { return }
        _ = addWindows(connection, space, [window.windowNumber] as CFArray, 7)
    }
}

/// Screen lock / unlock events, as posted by loginwindow.
@MainActor
final class LockStateObserver {
    var onChange: ((Bool) -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = DistributedNotificationCenter.default()
        observers = [
            center.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onChange?(true) }
            },
            center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.onChange?(false) }
            },
        ]
    }
}
