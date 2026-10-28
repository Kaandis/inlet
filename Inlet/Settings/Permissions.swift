import AppKit
import EventKit
import HarborKit

/// Publishes the permissions Inlet uses so Harbor can show them: Calendar
/// (upcoming events) and Full Disk Access (the Focus name on the lock screen).
///
/// Neither has a change signal Inlet can listen to, so the status is
/// re-read at launch, when Inlet comes forward, and whenever the calendar or
/// Focus services notice a change themselves.
@MainActor
enum Permissions {
    private static var token: NSObjectProtocol?

    static func start() {
        publish()
        guard token == nil else { return }
        token = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { publish() }
        }
    }

    static func publish() {
        SettingsBridge.publishPermissions([
            "calendars": EKEventStore.authorizationStatus(for: .event) == .fullAccess,
            "fullDiskAccess": FocusService.canReadDatabase,
        ])
    }
}
