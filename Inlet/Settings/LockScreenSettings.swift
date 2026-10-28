import SwiftUI

struct LockScreenSettings: View {
    @AppStorage(Prefs.showOnLockScreen) private var showOnLockScreen = true
    @AppStorage(Prefs.lockScreenMediaWidget) private var mediaCard = true
    @AppStorage(Prefs.lockMediaStyle) private var mediaStyle = LockMediaStyle.large.rawValue
    @AppStorage(Prefs.lockWidgetSlot1) private var slot1 = LockWidgetKind.focus.rawValue
    @AppStorage(Prefs.lockWidgetSlot2) private var slot2 = LockWidgetKind.weather.rawValue
    @AppStorage(Prefs.lockWidgetOffset) private var offset = 0.0
    @AppStorage(Prefs.weatherCity) private var city = "İstanbul"
    @AppStorage(Prefs.weatherUnit) private var unit = "celsius"

    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var focus = FocusService.shared

    private var slots: [LockWidgetKind] {
        [slot1, slot2].compactMap(LockWidgetKind.init(rawValue:))
    }

    var body: some View {
        Form {
            Section {
                LockScreenPreview(slots: slots, showCard: mediaCard && showOnLockScreen, offset: offset,
                                  style: LockMediaStyle(rawValue: mediaStyle) ?? .large)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                Toggle("Show on lock screen", isOn: $showOnLockScreen)
                Toggle("Now Playing card", isOn: $mediaCard)
                    .disabled(!showOnLockScreen)
                Picker("Card size", selection: $mediaStyle) {
                    ForEach(LockMediaStyle.allCases) { Text($0.title).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .disabled(!showOnLockScreen || !mediaCard)
            }

            Section("Small widgets") {
                Picker("Left", selection: $slot1) {
                    ForEach(LockWidgetKind.allCases) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Right", selection: $slot2) {
                    ForEach(LockWidgetKind.allCases) { Text($0.title).tag($0.rawValue) }
                }
                LabeledContent("Vertical position") {
                    Slider(value: $offset, in: -0.1...0.1) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "arrow.up")
                    } maximumValueLabel: {
                        Image(systemName: "arrow.down")
                    }
                }
            }
            .disabled(!showOnLockScreen)

            if slots.contains(.weather) {
                Section {
                    TextField("City", text: $city)
                        .onSubmit { weather.refresh(force: true) }
                    Picker("Unit", selection: $unit) {
                        Text("°C").tag("celsius")
                        Text("°F").tag("fahrenheit")
                    }
                    .pickerStyle(.segmented)
                    if let error = weather.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else if let conditions = weather.conditions {
                        Label("\(conditions.city): \(weather.formattedTemperature(conditions))",
                              systemImage: WeatherService.symbol(for: conditions))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Weather")
                } footer: {
                    WeatherAttribution()
                }
            }

            if slots.contains(.focus) && !focus.hasAccess {
                Section("Focus") {
                    Text("To show the active Focus (Work, Sleep…), Inlet needs Full Disk Access. macOS doesn’t share the Focus name any other way.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Open Full Disk Access Settings") { FocusService.openFullDiskAccessSettings() }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            weather.refresh()
            focus.read()
        }
    }
}

/// The lock-screen widgets over the current wallpaper, with sample data where
/// live data isn't available yet.
private struct LockScreenPreview: View {
    let slots: [LockWidgetKind]
    let showCard: Bool
    let offset: Double
    let style: LockMediaStyle

    @StateObject private var battery = BatteryService()
    @StateObject private var calendar = CalendarService()
    @StateObject private var media = NowPlayingService()
    @StateObject private var appearance = LockAppearance()

    private static let height: CGFloat = 340
    private static let sample = Track(title: "Golden Hour Drive", artist: "Paper Lanterns", album: "",
                                      duration: 214, position: 81, isPlaying: true, source: .music, sampledAt: .now)

    var body: some View {
        GeometryReader { geo in
            let h = Self.height
            ZStack {
                wallpaper
                    .frame(width: geo.size.width, height: h)
                    .clipped()

                VStack(spacing: 0) {
                    Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text(Date.now, format: .dateTime.hour().minute())
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
                .foregroundStyle(appearance.tint.opacity(0.9))
                .position(x: geo.size.width / 2, y: h * 0.13)

                SmallWidgetRow(kinds: slots, battery: battery, calendar: calendar,
                               weather: .shared, focus: .shared, tint: appearance.tint)
                    .scaleEffect(0.7)
                    .position(x: geo.size.width / 2, y: h * (0.29 + offset))

                if showCard, let track = media.track {
                    LockScreenMediaCard(track: track, media: media, tint: appearance.tint, style: style)
                        // Behind-window blur would frost the desktop, not this preview.
                        .environment(\.isStaticRender, true)
                        .scaleEffect(style == .large ? 0.5 : 0.62)
                        .position(x: geo.size.width / 2, y: h * (0.66 + offset))
                }
            }
        }
        .frame(height: Self.height)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, AppLanguage.resolvedLocale)
        .onAppear {
            battery.start()
            calendar.start()
            media.injectPreview(Self.sample, artwork: nil)
            if let screen = NSScreen.main { appearance.update(for: screen) }
        }
    }

    @ViewBuilder
    private var wallpaper: some View {
        if let url = NSScreen.main.flatMap({ NSWorkspace.shared.desktopImageURL(for: $0) }),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
        } else {
            LinearGradient(colors: [Color(red: 0.25, green: 0.18, blue: 0.62), Color(red: 0.45, green: 0.25, blue: 0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// Open-Meteo data is CC BY 4.0: credit it wherever the weather appears in Inlet's UI.
struct WeatherAttribution: View {
    var body: some View {
        HStack(spacing: 4) {
            Link("Weather data by Open-Meteo.com", destination: URL(string: "https://open-meteo.com/")!)
            Text("·")
            Link("CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
