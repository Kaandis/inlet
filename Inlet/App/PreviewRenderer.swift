#if DEBUG
import AppKit
import SwiftUI

/// `Inlet --render-previews <dir>` writes a PNG of every island state and exits.
/// Lets the UI be checked without screen-recording permission.
@MainActor
enum PreviewRenderer {
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--render-previews"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        // `--transparent` renders without the beige backdrop (for the website and README).
        let transparent = args.contains("--transparent")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Prefs.registerDefaults()

        let art = sampleArtwork()
        let track = Track(title: "Golden Hour Drive", artist: "Paper Lanterns", album: "Coastline",
                          duration: 214, position: 81, isPlaying: true, source: .music, sampledAt: .now)
        let now = Date()
        let events = [
            CalendarEvent(id: "1", title: sampleReview, start: now.addingTimeInterval(1800),
                          end: now.addingTimeInterval(5400), isAllDay: false, color: .orange),
            CalendarEvent(id: "2", title: sampleRun, start: now.addingTimeInterval(9000),
                          end: now.addingTimeInterval(12600), isAllDay: false, color: .green),
        ]

        let states: [(String, (IslandModel) -> Void)] = [
            ("1-idle", { _ in }),
            ("2-hover", { $0.setHovering(true) }),
            ("3-activity", { $0.media.injectPreview(track, artwork: art) }),
            ("4-volume", { $0.show(.volume(level: 0.62, muted: false)) }),
            ("5-charging", { $0.show(.charging(level: 82, isCharging: true)) }),
            ("6-event", { $0.show(.upcomingEvent(title: sampleReview, start: now.addingTimeInterval(240), color: .orange)) }),
            ("7-expanded-media", { $0.media.injectPreview(track, artwork: art); $0.expand() }),
            ("8-expanded-empty", { $0.expand() }),
            ("9-expanded-calendar", { $0.calendar.injectPreview(events); $0.tab = .calendar; $0.expand() }),
            ("10-locked", { $0.media.injectPreview(track, artwork: art); $0.setLocked(true) }),
            ("11-unlocked", { $0.setLocked(true); $0.setLocked(false) }),
            ("11b-locked-expanded", { $0.media.injectPreview(track, artwork: art); $0.tab = .calendar; $0.setLocked(true); $0.expand() }),
            ("12-drop", { $0.tray.add(sampleFiles()); $0.setDropTarget(.tray) }),
            ("12b-drop-empty", { $0.setDropTarget(.airDrop) }),
            ("13-timer", { $0.timer.start(25 * 60) }),
            ("14-bluetooth", { $0.show(.bluetooth(name: "AirPods Pro", symbol: "airpodspro", connected: true)) }),
            ("15-capslock", { $0.show(.capsLock(on: true)) }),
            ("16-expanded-tray", { $0.tray.add(sampleFiles()); $0.tab = .tray; $0.expand() }),
            ("17-expanded-timer", { $0.timer.start(10 * 60); $0.tab = .timer; $0.expand() }),
            ("18-expanded-tray-empty", { $0.tray.clear(); $0.tab = .tray; $0.expand() }),
        ]

        for (name, setup) in states {
            let media = NowPlayingService()
            let battery = BatteryService()
            battery.injectPreview(level: 82, charging: name.contains("charging"))
            let calendar = CalendarService()
            let tray = TrayStore(persistenceKey: nil)
            let timer = TimerService()
            let model = IslandModel(media: media, battery: battery, calendar: calendar, tray: tray, timer: timer)
            model.notchSize = CGSize(width: 190, height: 34)
            setup(model)

            let view = IslandView(model: model, media: media, battery: battery, calendar: calendar,
                                  tray: tray, timer: timer)
                .frame(width: 760, height: 240)
                .background(transparent ? Color.clear : Color(red: 0.93, green: 0.90, blue: 0.86))
                .environment(\.isStaticRender, true)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            if let image = renderer.nsImage,
               let tiff = image.tiffRepresentation,
               let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                try? png.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
        renderLockWidget(track: track, artwork: art, to: dir)
        exit(0)
    }

    private static func renderLockWidget(track: Track, artwork: NSImage, to dir: URL) {
        let media = NowPlayingService()
        media.injectPreview(track, artwork: artwork)
        let battery = BatteryService()
        battery.injectPreview(level: 76, charging: false)
        let calendar = CalendarService()
        calendar.injectPreview([CalendarEvent(id: "1", title: sampleReview, start: .now.addingTimeInterval(3600),
                                              end: .now.addingTimeInterval(7200), isAllDay: false, color: .orange)])
        let tint = LockAppearance.fallback
        let view = VStack(spacing: 0) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text("9:41").font(.system(size: 96, weight: .bold, design: .rounded))
            SmallWidgetRow(kinds: [.nextEvent, .battery], battery: battery, calendar: calendar,
                           weather: .shared, focus: .shared, tint: tint)
                .padding(.top, 6)
            LockScreenMediaCard(track: track, media: media, tint: tint, style: .large)
                .padding(.top, 60)
        }
            .foregroundStyle(tint)
            .padding(.vertical, 40)
            .frame(width: 900)
            .background(LinearGradient(colors: [Color(red: 0.22, green: 0.2, blue: 0.68), Color(red: 0.42, green: 0.22, blue: 0.62)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, .dark)
            .environment(\.isStaticRender, true)
            .environment(\.locale, AppLanguage.resolvedLocale)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent("19-lock-widget.png"))
        }
    }

    private static func sampleFiles() -> [URL] {
        ["/Applications/Safari.app", "/System/Library/CoreServices/Finder.app",
         "/Library/Desktop Pictures", "/etc/hosts"]
            .map { URL(fileURLWithPath: $0) }
    }

    private static var isTurkish: Bool { AppLanguage.resolvedLocale.identifier.hasPrefix("tr") }
    private static var sampleReview: String { isTurkish ? "Tasarım incelemesi" : "Design review" }
    private static var sampleRun: String { isTurkish ? "Akşam koşusu" : "Evening run" }

    private static func sampleArtwork() -> NSImage {
        NSImage(size: NSSize(width: 200, height: 200), flipped: false) { rect in
            let gradient = NSGradient(colors: [.systemOrange, .systemPink, .systemPurple])
            gradient?.draw(in: rect, angle: 315)
            NSColor.white.withAlphaComponent(0.85).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 70, dy: 70).offsetBy(dx: 0, dy: 20)).fill()
            return true
        }
    }
}
#endif
