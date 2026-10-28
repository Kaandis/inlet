import HarborKit
import SwiftUI

@main
struct InletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true

    var body: some Scene {
        MenuBarExtra("Inlet", systemImage: "capsule.fill", isInserted: $showMenuBarIcon) {
            MenuBarContent()
        }

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // With Harbor installed, settings live there; otherwise in Inlet's own window.
        Button("Settings…") {
            if !HarborLink.openSettings(appID: "inlet") {
                NSApp.activate()
                openSettings()
            }
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit Inlet") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: IslandController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        PreviewRenderer.runIfRequested()
        #endif
        Prefs.registerDefaults()
        SettingsBridge.listen()
        Permissions.start()
        controller = IslandController()
        controller?.start()
    }

    /// Opening the app again (Launchpad, Finder) shows Settings — the only way
    /// back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.activate()
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        return true
    }
}
