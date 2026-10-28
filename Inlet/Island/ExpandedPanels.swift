import SwiftUI

// MARK: - Tray

struct TrayPanel: View {
    @ObservedObject var tray: TrayStore
    @Environment(\.isStaticRender) private var isStaticRender

    var body: some View {
        if tray.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Drag files onto the island")
                    .font(.system(size: 13, weight: .semibold))
                Text("They wait here — drag them back out wherever you need them.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
        } else {
            HStack(alignment: .center, spacing: 14) {
                if isStaticRender {
                    tiles.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) { tiles }
                }

                VStack(spacing: 10) {
                    Button {
                        TrayStore.airDrop(tray.items.map(\.url))
                    } label: {
                        AirDropGlyph()
                            .frame(width: 16, height: 16)
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .help("AirDrop all")

                    Button(action: tray.clear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .frame(width: 34, height: 34)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .help("Clear tray")
                }
                .buttonStyle(PressableStyle(highlight: false))
            }
        }
    }
}

private struct TrayTile: View {
    let item: TrayItem
    @ObservedObject var tray: TrayStore
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 48, height: 48)
            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(width: 72, height: 26, alignment: .top)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(.white.opacity(hovering ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { hovering = $0 }
        .onDrag { NSItemProvider(object: item.url as NSURL) }
        .onTapGesture(count: 2) { tray.open(item) }
        .contextMenu {
            Button("Open") { tray.open(item) }
            Button("Show in Finder") { tray.revealInFinder(item) }
            Button("Send with AirDrop") { TrayStore.airDrop([item.url]) }
            Divider()
            Button("Remove from Tray") { tray.remove(item) }
        }
        .help(item.name)
    }
}

extension TrayPanel {
    private var tiles: some View {
        HStack(spacing: 8) {
            ForEach(tray.items) { item in
                TrayTile(item: item, tray: tray)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Timer

struct TimerPanel: View {
    @ObservedObject var timer: TimerService

    var body: some View {
        HStack(spacing: 26) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = timer.remaining(at: context.date)
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.12), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: timer.isActive ? 1 - timer.progress(at: context.date) : 0)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    Text(TimerService.format(remaining))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 96, height: 96)
            }

            VStack(alignment: .leading, spacing: 12) {
                if timer.isActive {
                    Text(timer.isRunning ? "Counting down" : "Paused" as LocalizedStringKey)
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 12) {
                        Button {
                            timer.isRunning ? timer.pause() : timer.resume()
                        } label: {
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .contentTransition(.symbolEffect(.replace))
                                .frame(width: 44, height: 44)
                                .background(.orange.opacity(0.25), in: Circle())
                                .foregroundStyle(.orange)
                        }
                        Button(action: timer.cancel) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                    }
                    .buttonStyle(PressableStyle(highlight: false))
                } else {
                    Text("Quick timer")
                        .font(.system(size: 14, weight: .semibold))
                    HStack(spacing: 8) {
                        ForEach(TimerService.presets, id: \.self) { seconds in
                            Button {
                                timer.start(seconds)
                            } label: {
                                Text("\(Int(seconds / 60)) min")
                                    .font(.system(size: 12, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(.white.opacity(0.12), in: Capsule())
                            }
                        }
                    }
                    .buttonStyle(PressableStyle(highlight: false))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
