import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            FeatureSettings()
                .tabItem { Label("Features", systemImage: "square.grid.2x2") }
            LockScreenSettings()
                .tabItem { Label("Lock Screen", systemImage: "lock.rectangle") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.expandOnHover) private var expandOnHover = false
    @AppStorage(Prefs.hoverDelay) private var hoverDelay = 0.35
    @AppStorage(Prefs.showOnNonNotchDisplays) private var showOnNonNotch = true
    @AppStorage(Prefs.hapticFeedback) private var haptics = true
    @AppStorage(Prefs.swipeGesturesEnabled) private var swipes = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var language = AppLanguage.current
    private let launchLanguage = AppLanguage.current

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                    }
                Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                Toggle("Show on displays without a notch", isOn: $showOnNonNotch)
            }

            Section {
                Picker("Language", selection: $language) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                .onChange(of: language) { _, language in language.apply() }
                if language != launchLanguage {
                    HStack {
                        Text("Restart Inlet to switch languages.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Restart Now") { AppLanguage.relaunch() }
                    }
                }
            }

            Section("Interaction") {
                Toggle("Expand on hover", isOn: $expandOnHover)
                if expandOnHover {
                    LabeledContent("Delay") {
                        Slider(value: $hoverDelay, in: 0...1, step: 0.05) {
                            EmptyView()
                        } minimumValueLabel: {
                            Text("Instant")
                        } maximumValueLabel: {
                            Text("1 s")
                        }
                    }
                }
                Toggle("Swipe gestures", isOn: $swipes)
                Text("Two-finger swipe down: open · up: close · sideways: change track")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Haptic feedback", isOn: $haptics)
            }
        }
        .formStyle(.grouped)
    }
}

private struct FeatureSettings: View {
    @AppStorage(Prefs.mediaEnabled) private var media = true
    @AppStorage(Prefs.batteryEnabled) private var battery = true
    @AppStorage(Prefs.calendarEnabled) private var calendar = true
    @AppStorage(Prefs.volumeHUDEnabled) private var volume = true
    @AppStorage(Prefs.brightnessHUDEnabled) private var brightness = true
    @AppStorage(Prefs.trayEnabled) private var tray = true
    @AppStorage(Prefs.bluetoothEnabled) private var bluetooth = true
    @AppStorage(Prefs.capsLockEnabled) private var capsLock = true

    var body: some View {
        Form {
            Section("Live Activities") {
                Toggle("Now Playing", isOn: $media)
                Toggle("Charging and battery alerts", isOn: $battery)
                Toggle("Upcoming events", isOn: $calendar)
                Toggle("Bluetooth devices (AirPods, etc.)", isOn: $bluetooth)
            }
            Section("Files") {
                Toggle(isOn: $tray) {
                    Text("Tray and AirDrop")
                    Text("Drag files onto the island and drop them.")
                }
            }
            Section("HUD") {
                Toggle("Volume", isOn: $volume)
                Toggle("Display brightness", isOn: $brightness)
                Toggle("Caps Lock", isOn: $capsLock)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(.black)
                .frame(width: 84, height: 26)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
                .padding(.top, 24)
            Text("Inlet")
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.4)
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Text("Your notch, put to work.")
                .font(.callout)
                .foregroundStyle(.secondary)
            WeatherAttribution()
                .padding(.top, 8)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
    }
}
