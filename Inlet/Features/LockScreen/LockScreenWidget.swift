import AppKit
import SwiftUI

// MARK: - Configuration

/// What a small lock-screen slot (under the clock) shows.
enum LockWidgetKind: String, CaseIterable, Identifiable {
    case none
    case focus
    case weather
    case battery
    case nextEvent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "None")
        case .focus: String(localized: "Focus")
        case .weather: String(localized: "Weather")
        case .battery: String(localized: "Battery")
        case .nextEvent: String(localized: "Next event")
        }
    }

    static func slot(_ key: String) -> LockWidgetKind {
        LockWidgetKind(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .none
    }
}

/// Layout of the lock-screen widgets, as fractions of the screen height from the top.
enum LockScreenLayout {
    static let bandTop: CGFloat = 0.14
    static let bandHeight: CGFloat = 0.70
    static let smallRow: CGFloat = 0.255
    /// The big card is taller, so its centre sits a little lower.
    static func card(_ style: LockMediaStyle) -> CGFloat {
        style == .large ? 0.605 : 0.585
    }

    /// Widgets grow a little on tall displays so they hold their own next to
    /// the system clock, without getting oversized on a laptop.
    static func scale(forHeight height: CGFloat) -> CGFloat {
        min(1.2, max(0.95, height / 1050))
    }

    static var offset: CGFloat {
        CGFloat(UserDefaults.standard.double(forKey: Prefs.lockWidgetOffset))
    }
}

/// A pale tint taken from the wallpaper, so text reads like the system's
/// vibrant lock-screen clock instead of flat white.
@MainActor
final class LockAppearance: ObservableObject {
    static let fallback = Color(red: 0.87, green: 0.81, blue: 1.0)

    @Published private(set) var tint = LockAppearance.fallback

    func update(for screen: NSScreen) {
        guard let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let image = NSImage(contentsOf: url),
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
            tint = Self.fallback
            return
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: 8, height: 8))
        NSGraphicsContext.restoreGraphicsState()

        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        for x in 0..<8 {
            for y in 0..<8 {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { continue }
                r += c.redComponent; g += c.greenComponent; b += c.blueComponent
            }
        }
        let average = NSColor(deviceRed: r / 64, green: g / 64, blue: b / 64, alpha: 1)
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        average.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        tint = Color(hue: hue, saturation: min(0.32, saturation * 0.7), brightness: 1)
    }
}

// MARK: - Window

/// Floats the lock-screen widgets: a row of small widgets under the clock and
/// a Now Playing card below it.
///
/// The window lives in the lock-screen SkyLight space for the whole session
/// (re-ordering it would drop it out of that space), so it's hidden by
/// fading its content and ignoring the mouse rather than ordering out.
@MainActor
final class LockScreenWidgetController {
    private static let width: CGFloat = 860

    private let model: IslandModel
    private let media: NowPlayingService
    private let battery: BatteryService
    private let calendar: CalendarService
    private let appearance = LockAppearance()
    private var panel: IslandPanel?
    private var delegated = false
    private var screen: NSScreen?

    init(model: IslandModel, media: NowPlayingService, battery: BatteryService, calendar: CalendarService) {
        self.model = model
        self.media = media
        self.battery = battery
        self.calendar = calendar
    }

    func layout(on screen: NSScreen) {
        self.screen = screen
        let height = screen.frame.height * LockScreenLayout.bandHeight
        let frame = NSRect(x: screen.frame.midX - Self.width / 2,
                           y: screen.frame.maxY - screen.frame.height * LockScreenLayout.bandTop - height,
                           width: Self.width,
                           height: height)

        if panel == nil {
            let panel = IslandPanel(contentRect: frame)
            let root = LockScreenRoot(model: model, media: media, battery: battery, calendar: calendar,
                                      weather: .shared, focus: .shared, appearance: appearance,
                                      screenHeight: screen.frame.height, width: Self.width) { [weak self] interactive in
                self?.panel?.ignoresMouseEvents = !interactive
            }
            let host = IslandHostingView(rootView: root)
            host.frame = NSRect(origin: .zero, size: frame.size)
            host.autoresizingMask = [.width, .height]
            panel.contentView = host
            self.panel = panel
        }
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()

        if let panel, !delegated {
            LockScreenSpace.shared.delegate(panel)
            delegated = true
        }
    }

    /// Called as the screen locks: freshen what the widgets show.
    func willAppear() {
        if let screen { appearance.update(for: screen) }
        WeatherService.shared.refresh()
        FocusService.shared.read()
    }
}

private struct LockScreenRoot: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var media: NowPlayingService
    @ObservedObject var battery: BatteryService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService
    @ObservedObject var focus: FocusService
    @ObservedObject var appearance: LockAppearance
    let screenHeight: CGFloat
    let width: CGFloat
    let onInteractiveChange: (Bool) -> Void

    @AppStorage(Prefs.showOnLockScreen) private var lockScreenEnabled = true
    @AppStorage(Prefs.lockScreenMediaWidget) private var cardEnabled = true
    @AppStorage(Prefs.lockWidgetSlot1) private var slot1 = LockWidgetKind.focus.rawValue
    @AppStorage(Prefs.lockWidgetSlot2) private var slot2 = LockWidgetKind.weather.rawValue
    @AppStorage(Prefs.lockWidgetOffset) private var offset = 0.0
    @AppStorage(Prefs.lockMediaStyle) private var mediaStyle = LockMediaStyle.large.rawValue

    private var showWidgets: Bool { model.isLocked && lockScreenEnabled }
    private var showCard: Bool { showWidgets && cardEnabled && media.track != nil }

    var body: some View {
        let bandTop = screenHeight * LockScreenLayout.bandTop
        let scale = LockScreenLayout.scale(forHeight: screenHeight)
        ZStack(alignment: .top) {
            if showWidgets {
                SmallWidgetRow(kinds: [slot1, slot2].compactMap(LockWidgetKind.init(rawValue:)),
                               battery: battery, calendar: calendar, weather: weather, focus: focus,
                               tint: appearance.tint, scale: scale)
                    .position(x: width / 2, y: screenHeight * (LockScreenLayout.smallRow + offset) - bandTop)
                    .transition(.materialize)
            }
            if showCard, let track = media.track {
                let style = LockMediaStyle(rawValue: mediaStyle) ?? .large
                LockScreenMediaCard(track: track, media: media, tint: appearance.tint, style: style, scale: scale)
                    .position(x: width / 2, y: screenHeight * (LockScreenLayout.card(style) + offset) - bandTop)
                    .transition(.materialize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(IslandModel.settle, value: showWidgets)
        .animation(IslandModel.settle, value: showCard)
        .onChange(of: showCard, initial: true) { _, show in onInteractiveChange(show) }
        .environment(\.colorScheme, .dark)
        .environment(\.locale, AppLanguage.resolvedLocale)
    }
}

// MARK: - Small widgets

struct SmallWidgetRow: View {
    let kinds: [LockWidgetKind]
    @ObservedObject var battery: BatteryService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var weather: WeatherService
    @ObservedObject var focus: FocusService
    let tint: Color
    var scale: CGFloat = 1

    var body: some View {
        HStack(spacing: 22 * scale) {
            ForEach(kinds) { kind in
                if let content = content(for: kind) {
                    HStack(spacing: 6 * scale) {
                        Image(systemName: content.symbol)
                            .font(.system(size: 14 * scale, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                        Text(content.text)
                            .font(.system(size: 16 * scale, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    }
                    .foregroundStyle(tint.opacity(0.92))
                    .shadow(color: .black.opacity(0.18), radius: 6, y: 1)
                    .transition(.opacity)
                }
            }
        }
        .animation(IslandModel.settle, value: kinds)
    }

    private func content(for kind: LockWidgetKind) -> (symbol: String, text: String)? {
        switch kind {
        case .none:
            return nil
        case .focus:
            return focus.current.map { ($0.symbol, $0.name) }
        case .weather:
            return weather.conditions.map { (WeatherService.symbol(for: $0), weather.formattedTemperature($0)) }
        case .battery:
            guard battery.hasBattery else { return nil }
            let symbol = battery.isCharging ? "battery.100percent.bolt" : Self.batterySymbol(battery.level)
            return (symbol, (Double(battery.level) / 100).formatted(.percent.precision(.fractionLength(0)).locale(AppLanguage.resolvedLocale)))
        case .nextEvent:
            guard let event = calendar.events.first(where: { !$0.isAllDay }) ?? calendar.events.first else { return nil }
            let time = event.isAllDay ? String(localized: "All day") : event.start.formatted(.dateTime.hour().minute())
            let title = event.title.count > 16 ? String(event.title.prefix(15)) + "…" : event.title
            return ("calendar", "\(time) \(title)")
        }
    }

    private static func batterySymbol(_ level: Int) -> String {
        switch level {
        case ..<13: "battery.0percent"
        case ..<38: "battery.25percent"
        case ..<63: "battery.50percent"
        case ..<88: "battery.75percent"
        default: "battery.100percent"
        }
    }
}

// MARK: - Now Playing card

enum LockMediaStyle: String, CaseIterable, Identifiable {
    case large
    case compact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .large: String(localized: "Large")
        case .compact: String(localized: "Compact")
        }
    }

    static var current: LockMediaStyle {
        LockMediaStyle(rawValue: UserDefaults.standard.string(forKey: Prefs.lockMediaStyle) ?? "") ?? .large
    }
}

struct LockScreenMediaCard: View {
    let track: Track
    @ObservedObject var media: NowPlayingService
    var tint: Color = LockAppearance.fallback
    var style: LockMediaStyle = .compact
    var scale: CGFloat = 1

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.isStaticRender) private var isStaticRender

    private var radius: CGFloat { style == .large ? 32 * scale : 26 }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radius, style: .continuous) }

    var body: some View {
        Group {
            switch style {
            case .large: large
            case .compact: compact
            }
        }
        .background { glass }
        .overlay {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0.08)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: style == .large ? 30 * scale : 24, y: style == .large ? 14 * scale : 12)
    }

    // MARK: Layouts

    private var compact: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                artwork(size: 54, radius: 11)
                titles(titleSize: 14, artistSize: 13, alignment: .leading)
                Spacer(minLength: 8)
                DotMeter(isPlaying: track.isPlaying, color: tint.opacity(0.75))
            }
            progress(fontSize: 10.5, barHeight: 5)
                .padding(.top, 16)
            controls(scale: 1)
                .padding(.top, 10)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .frame(width: 340)
    }

    /// Near-square card: cover and titles side by side, then progress and
    /// controls across the full width beneath.
    private var large: some View {
        let s = scale
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16 * s) {
                artwork(size: 112 * s, radius: 18 * s)
                    .shadow(color: .black.opacity(0.3), radius: 12 * s, y: 5 * s)
                VStack(alignment: .leading, spacing: 0) {
                    Text(track.source.displayName.uppercased())
                        .font(.system(size: 10 * s, weight: .bold))
                        .tracking(0.6)
                        .foregroundStyle(tint.opacity(0.55))
                    titles(titleSize: 19 * s, artistSize: 15 * s, alignment: .leading)
                        .padding(.top, 6 * s)
                }
                Spacer(minLength: 0)
                DotMeter(isPlaying: track.isPlaying, color: tint.opacity(0.75))
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(height: 112 * s)

            progress(fontSize: 11 * s, barHeight: 6 * s)
                .padding(.top, 18 * s)
            controls(scale: 1.12 * s)
                .padding(.top, 8 * s)
        }
        .padding(.horizontal, 20 * s)
        .padding(.top, 20 * s)
        .padding(.bottom, 12 * s)
        .frame(width: 390 * s)
    }

    // MARK: Pieces

    private func artwork(size: CGFloat, radius: CGFloat) -> some View {
        Artwork(image: media.artwork, size: size, radius: radius)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
    }

    private func titles(titleSize: CGFloat, artistSize: CGFloat, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(track.title)
                .font(.system(size: titleSize, weight: .semibold))
                .tracking(titleSize > 16 ? -0.3 : 0)
                .foregroundStyle(.white)
            Text(track.artist)
                .font(.system(size: artistSize, weight: .medium))
                .foregroundStyle(tint.opacity(0.85))
        }
        .lineLimit(1)
    }

    private func progress(fontSize: CGFloat, barHeight: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let position = track.currentPosition(at: context.date)
            let known = track.duration > 0
            HStack(spacing: 10) {
                Text(known ? Self.format(position) : "-:--")
                    .frame(width: fontSize * 3.4, alignment: .leading)
                Capsule()
                    .fill(.white.opacity(0.18))
                    .frame(height: barHeight)
                    .overlay(alignment: .leading) {
                        GeometryReader { geo in
                            Capsule()
                                .fill(.white.opacity(0.85))
                                .frame(width: known ? geo.size.width * min(1, position / track.duration) : 0)
                        }
                    }
                Text(known ? "-" + Self.format(max(0, track.duration - position)) : "-:--")
                    .frame(width: fontSize * 3.4, alignment: .trailing)
            }
            .font(.system(size: fontSize, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(tint.opacity(0.7))
        }
    }

    private func controls(scale: CGFloat) -> some View {
        HStack(spacing: 0) {
            control("shuffle", size: 15 * scale, tinted: !track.isShuffling, action: media.toggleShuffle)
            control("backward.fill", size: 19 * scale, action: media.previous)
            control(track.isPlaying ? "pause.fill" : "play.fill", size: 27 * scale, action: media.togglePlayPause)
            control("forward.fill", size: 19 * scale, action: media.next)
            Image(systemName: outputSymbol)
                .font(.system(size: 15 * scale, weight: .medium))
                .foregroundStyle(tint.opacity(0.75))
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var glass: some View {
        ZStack {
            if reduceTransparency {
                Color(white: 0.16)
            } else {
                if isStaticRender {
                    Color.white.opacity(0.14)
                } else {
                    VisualEffect(material: .hudWindow)
                        .opacity(0.85)
                }
                // The cover's colours bleed softly into the glass on the big card.
                // Color.clear takes the card's size, so the filled image can't widen the glass.
                if style == .large, let image = media.artwork {
                    Color.clear
                        .overlay {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .blur(radius: 50)
                                .opacity(0.35)
                        }
                        .clipped()
                }
                tint.opacity(0.10)
                Color.white.opacity(0.05)
            }
        }
        .clipShape(shape)
    }

    private var outputSymbol: String {
        guard let output = AudioDevices.defaultOutput() else { return "laptopcomputer" }
        if output.isBluetooth { return BluetoothService.symbol(forName: output.name, audio: true) }
        if output.name.lowercased().contains("macbook") { return "laptopcomputer" }
        return "hifispeaker.fill"
    }

    private func control(_ symbol: String, size: CGFloat, tinted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tinted ? AnyShapeStyle(tint.opacity(0.75)) : AnyShapeStyle(.white))
                .contentTransition(.symbolEffect(.replace))
                .frame(height: 36 * max(1, size / 27))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(PressableStyle())
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Five dots that rise into a level meter while music plays.
private struct DotMeter: View {
    let isPlaying: Bool
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isPlaying || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 2.5) {
                ForEach(0..<5, id: \.self) { i in
                    let wave = (sin(t * (5 + Double(i) * 1.7) + Double(i)) + 1) / 2
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: isPlaying && !reduceMotion ? 3 + 9 * wave : 3)
                }
            }
            .frame(height: 12)
        }
    }
}

/// Behind-window blur, so the card frosts whatever wallpaper is under it.
struct VisualEffect: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
    }
}
