import HarborKit
import SwiftUI

struct IslandView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var media: NowPlayingService
    @ObservedObject var battery: BatteryService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var tray: TrayStore
    @ObservedObject var timer: TimerService

    var body: some View {
        island
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
            .environment(\.locale, AppLanguage.resolvedLocale)
    }

    private var shape: NotchShape {
        NotchShape(topRadius: model.topRadius, bottomRadius: model.bottomRadius)
    }

    private var island: some View {
        let size = model.shapeSize
        return ZStack(alignment: .top) {
            content
                .padding(.horizontal, model.topRadius)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .background(.black)
        .clipShape(shape)
        .shadow(color: .black.opacity(model.isExpanded || model.isDragging ? 0.4 : 0), radius: 20, y: 10)
        .contentShape(shape)
        .onTapGesture {
            if !model.isExpanded { model.expand() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.presentation {
        case .expanded:
            ExpandedView(model: model, media: media, battery: battery, calendar: calendar, tray: tray, timer: timer)
                .transition(.materialize)
        case .drop:
            DropZonesView(model: model, tray: tray)
                .transition(.materialize)
        case .hud:
            if case let .volume(level, muted)? = model.transient {
                Flanking(model: model) {
                    Image(systemName: muted || level == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
                          variableValue: Double(level))
                        .contentTransition(.symbolEffect(.replace))
                } trailing: {
                    LevelBar(level: muted ? 0 : level)
                }
                .transition(.materialize)
            } else if case let .brightness(level)? = model.transient {
                Flanking(model: model) {
                    Image(systemName: "sun.max.fill", variableValue: Double(level))
                } trailing: {
                    LevelBar(level: level)
                }
                .transition(.materialize)
            }
        case .notice, .compactNotice:
            NoticeView(model: model)
                .transition(.materialize)
        case .locked:
            Flanking(model: model) {
                Image(systemName: "lock.fill")
            } trailing: {
                if media.track?.isPlaying == true {
                    Equalizer(isPlaying: true, color: .white.opacity(0.85))
                }
            }
            .transition(.materialize)
        case .timer:
            Flanking(model: model) {
                Image(systemName: timer.isRunning ? "timer" : "pause.fill")
                    .foregroundStyle(.orange)
                    .contentTransition(.symbolEffect(.replace))
            } trailing: {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(TimerService.format(timer.remaining(at: context.date)))
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
            }
            .transition(.materialize)
        case .activity:
            Flanking(model: model) {
                Artwork(image: media.artwork, size: model.bodySize.height - 12, radius: 6)
            } trailing: {
                Equalizer(isPlaying: media.track?.isPlaying == true, color: .white.opacity(0.85))
            }
            .transition(.materialize)
        case .idle:
            Color.clear
        }
    }
}

// MARK: - Drop page

/// The tray page, opened by a file drag: what's already in the tray on the
/// left (drop here to add), AirDrop on the right.
private struct DropZonesView: View {
    @ObservedObject var model: IslandModel
    @ObservedObject var tray: TrayStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Label("Tray", systemImage: "tray.full.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Color.clear.frame(width: model.notchSize.width)
                (tray.items.isEmpty ? Text("Empty") : Text("\(tray.items.count) files"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, 22)
            .frame(height: model.notchSize.height)

            HStack(spacing: 12) {
                zone(.tray, title: "Drop to tray") {
                    if tray.items.isEmpty {
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 26, weight: .medium))
                    } else {
                        TrayPreview(items: tray.items)
                    }
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1.5)

                zone(.airDrop, title: "AirDrop") {
                    AirDropGlyph()
                        .frame(width: 30, height: 30)
                }
                .frame(width: (model.bodySize.width - 48) * 0.38)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 18)
        }
        .foregroundStyle(.white)
    }

    private func zone<Icon: View>(_ zone: DropZone, title: LocalizedStringKey, @ViewBuilder icon: () -> Icon) -> some View {
        let active = model.dropTarget == zone
        return VStack(spacing: 10) {
            icon()
            Text(title)
                .font(.system(size: 12, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.white.opacity(active ? 1 : 0.5))
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(active ? 0.14 : 0.05))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(active ? 0.35 : 0.14), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
        }
        .scaleEffect(active ? 1.02 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 1), value: active)
    }
}

/// A fanned stack of the first few tray icons, plus a "+N" badge.
private struct TrayPreview: View {
    let items: [TrayItem]

    var body: some View {
        HStack(spacing: -10) {
            ForEach(Array(items.prefix(4).enumerated()), id: \.element.id) { index, item in
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(Double(index - 1) * 6))
                    .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
            }
            if items.count > 4 {
                Text("+\(items.count - 4)")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())
                    .padding(.leading, 16)
            }
        }
    }
}

// MARK: - Compact layouts

/// Lays content out on either side of the physical notch.
private struct Flanking<Leading: View, Trailing: View>: View {
    @ObservedObject var model: IslandModel
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear
                .frame(width: model.notchSize.width)
            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: model.bodySize.height)
    }
}

private struct LevelBar: View {
    let level: Float

    var body: some View {
        Capsule()
            .fill(.white.opacity(0.2))
            .frame(width: 64, height: 5)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(.white)
                    .frame(width: 64 * CGFloat(max(0, min(1, level))))
            }
    }
}

private struct NoticeView: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        switch model.transient {
        case let .charging(level, isCharging)?:
            Flanking(model: model) {
                Label(isCharging ? "Charging" : "Connected" as LocalizedStringKey, systemImage: "bolt.fill")
                    .labelStyle(TightLabel(tint: .green))
            } trailing: {
                HStack(spacing: 6) {
                    Text("\(level)%").foregroundStyle(.green).monospacedDigit()
                    BatteryGlyph(level: level, isCharging: true)
                }
            }
        case let .lowBattery(level)?:
            Flanking(model: model) {
                Label("Low battery", systemImage: "battery.25percent")
                    .labelStyle(TightLabel(tint: .red))
            } trailing: {
                HStack(spacing: 6) {
                    Text("\(level)%").foregroundStyle(.red).monospacedDigit()
                    BatteryGlyph(level: level, isCharging: false)
                }
            }
        case let .upcomingEvent(title, start, color)?:
            Flanking(model: model) {
                HStack(spacing: 6) {
                    Circle().fill(color).frame(width: 7, height: 7)
                    Text(title).lineLimit(1)
                }
            } trailing: {
                TimelineView(.periodic(from: .now, by: 15)) { context in
                    let minutes = max(0, Int(ceil(start.timeIntervalSince(context.date) / 60)))
                    (minutes == 0 ? Text("Now") : Text("in \(minutes) min"))
                        .foregroundStyle(color)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
        case .unlocked?:
            Flanking(model: model) {
                Image(systemName: "lock.open.fill")
                    .symbolEffect(.bounce, options: .nonRepeating)
            } trailing: {
                Image(systemName: "checkmark")
                    .foregroundStyle(.white.opacity(0.6))
            }
        case let .capsLock(on)?:
            Flanking(model: model) {
                Image(systemName: "capslock.fill")
                    .foregroundStyle(on ? .green : .white.opacity(0.5))
            } trailing: {
                Text(on ? "On" : "Off" as LocalizedStringKey)
                    .foregroundStyle(on ? .green : .white.opacity(0.6))
            }
        case .timerDone?:
            Flanking(model: model) {
                Label("Time’s up", systemImage: "timer")
                    .labelStyle(TightLabel(tint: .orange))
            } trailing: {
                Text("0:00").foregroundStyle(.orange).monospacedDigit()
            }
        case let .bluetooth(name, symbol, connected)?:
            Flanking(model: model) {
                HStack(spacing: 6) {
                    Image(systemName: symbol)
                    Text(name).lineLimit(1)
                }
            } trailing: {
                Text(connected ? "Connected" : "Disconnected" as LocalizedStringKey)
                    .foregroundStyle(connected ? .green : .white.opacity(0.5))
            }
        case let .trayAdded(count)?:
            Flanking(model: model) {
                Label("In tray", systemImage: "tray.full.fill")
                    .labelStyle(TightLabel(tint: .white))
            } trailing: {
                Text("\(count) files").foregroundStyle(.white.opacity(0.7))
            }
        default:
            EmptyView()
        }
    }
}

private struct TightLabel: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon.foregroundStyle(tint)
            configuration.title.lineLimit(1)
        }
    }
}
