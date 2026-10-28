import SwiftUI

struct ExpandedView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var media: NowPlayingService
    @ObservedObject var battery: BatteryService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var tray: TrayStore
    @ObservedObject var timer: TimerService
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch model.tab {
                case .media:
                    MediaPanel(media: media, swipeOffset: model.swipeOffset)
                case .calendar:
                    CalendarPanel(calendar: calendar)
                case .tray:
                    TrayPanel(tray: tray)
                case .timer:
                    TimerPanel(timer: timer)
                }
            }
            .transition(.opacity)
            .padding(.horizontal, 24)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .frame(maxHeight: .infinity)
        }
        .foregroundStyle(.white)
        .frame(width: model.bodySize.width, height: model.bodySize.height, alignment: .top)
    }

    /// The top strip shares the notch's height; controls sit to either side of it.
    private var header: some View {
        HStack(spacing: 0) {
            HStack(spacing: 16) {
                ForEach(ExpandedTab.allCases, id: \.self) { tab in
                    tabButton(tab, icon: tab.symbol)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear.frame(width: model.notchSize.width)

            HStack(spacing: 6) {
                settingsButton
                    .padding(.trailing, 6)
                if battery.hasBattery {
                    Text("\(battery.level)%")
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.8))
                    BatteryGlyph(level: battery.level, isCharging: battery.isCharging)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 22)
        .frame(height: model.notchSize.height)
    }

    /// Small and quiet, next to the battery: the shortest way into Settings.
    private var settingsButton: some View {
        Button {
            model.collapse()
            NSApp.activate()
            openSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(PressableStyle())
        .help("Settings")
        .accessibilityLabel("Settings")
    }

    private func tabButton(_ tab: ExpandedTab, icon: String) -> some View {
        Button {
            withAnimation(IslandModel.settle) { model.tab = tab }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(model.tab == tab ? 1 : 0.4))
                .frame(width: 22, height: 22)
        }
        .buttonStyle(PressableStyle())
    }
}

// MARK: - Media

private struct MediaPanel: View {
    @ObservedObject var media: NowPlayingService
    let swipeOffset: CGFloat

    var body: some View {
        if let track = media.track {
            HStack(spacing: 18) {
                Artwork(image: media.artwork, size: 92, radius: 18)
                    .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                    .onTapGesture { media.openSourceApp() }

                VStack(alignment: .leading, spacing: 0) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .tracking(-0.2)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .padding(.top, 2)

                    Scrubber(track: track, onSeek: media.seek(to:))
                        .padding(.top, 12)

                    controls(isPlaying: track.isPlaying)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .offset(x: swipeOffset)
        } else {
            HStack(spacing: 18) {
                Artwork(image: nil, size: 92, radius: 18)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nothing playing")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Start a song in Music or Spotify.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.55))
                    Button("Open Music") { media.openSourceApp() }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.12), in: Capsule())
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func controls(isPlaying: Bool) -> some View {
        HStack(spacing: 34) {
            Button(action: media.previous) {
                Image(systemName: "backward.fill").font(.system(size: 17))
            }
            Button(action: media.togglePlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 26)
            }
            Button(action: media.next) {
                Image(systemName: "forward.fill").font(.system(size: 17))
            }
        }
        .buttonStyle(PressableStyle())
        .frame(maxWidth: .infinity)
    }
}

/// Progress bar that tracks the pointer 1:1 while dragging and seeks on release.
private struct Scrubber: View {
    let track: Track
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let position = track.currentPosition(at: context.date)
            let fraction = dragFraction ?? (track.duration > 0 ? position / track.duration : 0)
            let shown = dragFraction.map { $0 * track.duration } ?? position

            VStack(spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule().fill(.white)
                            .frame(width: geo.size.width * max(0, min(1, fraction)))
                    }
                    .frame(height: dragFraction == nil ? 5 : 8)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                withAnimation(.spring(response: 0.2, dampingFraction: 1)) {
                                    dragFraction = max(0, min(1, value.location.x / geo.size.width))
                                }
                            }
                            .onEnded { _ in
                                if let dragFraction { onSeek(dragFraction * track.duration) }
                                withAnimation(.spring(response: 0.25, dampingFraction: 1)) { dragFraction = nil }
                            }
                    )
                }
                .frame(height: 10)

                HStack {
                    Text(Self.format(shown))
                    Spacer()
                    Text("-" + Self.format(max(0, track.duration - shown)))
                }
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Calendar

private struct CalendarPanel: View {
    @ObservedObject var calendar: CalendarService

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Date.now, format: .dateTime.weekday(.wide))
                    .font(.system(size: 12, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
                Text(Date.now, format: .dateTime.day())
                    .font(.system(size: 44, weight: .bold))
                    .tracking(-1.5)
                Text(Date.now, format: .dateTime.month(.wide))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: 96, alignment: .leading)
            .onTapGesture { calendar.openCalendarApp() }

            Group {
                if !calendar.isAuthorized {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("See your events here")
                            .font(.system(size: 14, weight: .semibold))
                        Button("Allow Calendar Access") { calendar.requestAccess() }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                } else if calendar.events.isEmpty {
                    Label("Nothing else today", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.top, 6)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(calendar.events.prefix(3)) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct EventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(event.color)
                .frame(width: 3, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Group {
                    if event.isAllDay {
                        Text("All day")
                    } else {
                        Text(event.start, format: .dateTime.hour().minute())
                        + Text(" – ")
                        + Text(event.end, format: .dateTime.hour().minute())
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}
