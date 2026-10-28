import Foundation

/// UserDefaults keys shared by @AppStorage and the services.
enum Prefs {
    static let showMenuBarIcon = "showMenuBarIcon"
    static let expandOnHover = "expandOnHover"
    static let hoverDelay = "hoverDelay"
    static let showOnNonNotchDisplays = "showOnNonNotchDisplays"
    static let hapticFeedback = "hapticFeedback"
    static let mediaEnabled = "mediaEnabled"
    static let batteryEnabled = "batteryEnabled"
    static let calendarEnabled = "calendarEnabled"
    static let volumeHUDEnabled = "volumeHUDEnabled"
    static let brightnessHUDEnabled = "brightnessHUDEnabled"
    static let swipeGesturesEnabled = "swipeGesturesEnabled"
    static let showOnLockScreen = "showOnLockScreen"
    static let lockScreenMediaWidget = "lockScreenMediaWidget"
    static let lockWidgetSlot1 = "lockWidgetSlot1"
    static let lockMediaStyle = "lockMediaStyle"
    static let lockWidgetSlot2 = "lockWidgetSlot2"
    static let lockWidgetOffset = "lockWidgetOffset"
    static let weatherCity = "weatherCity"
    static let weatherUnit = "weatherUnit"
    static let trayEnabled = "trayEnabled"
    static let bluetoothEnabled = "bluetoothEnabled"
    static let capsLockEnabled = "capsLockEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showMenuBarIcon: true,
            expandOnHover: false,
            hoverDelay: 0.35,
            showOnNonNotchDisplays: true,
            hapticFeedback: true,
            mediaEnabled: true,
            batteryEnabled: true,
            calendarEnabled: true,
            volumeHUDEnabled: true,
            brightnessHUDEnabled: true,
            swipeGesturesEnabled: true,
            showOnLockScreen: true,
            lockScreenMediaWidget: true,
            lockWidgetSlot1: "focus",
            lockMediaStyle: "large",
            lockWidgetSlot2: "weather",
            lockWidgetOffset: 0.0,
            weatherCity: "İstanbul",
            weatherUnit: "celsius",
            trayEnabled: true,
            bluetoothEnabled: true,
            capsLockEnabled: true,
        ])
    }

    static func bool(_ key: String) -> Bool { UserDefaults.standard.bool(forKey: key) }
}
