import SwiftUI

// MARK: - Preview rendering

private struct StaticRenderKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True under `ImageRenderer`, which can't draw AppKit-backed views
    /// (scroll views, drop targets) and shows yellow placeholders instead.
    var isStaticRender: Bool {
        get { self[StaticRenderKey.self] }
        set { self[StaticRenderKey.self] = newValue }
    }
}

// MARK: - Press feedback

/// Feedback lands on press, not release: the control shrinks and a soft
/// highlight appears the instant the pointer goes down.
struct PressableStyle: ButtonStyle {
    var highlight = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .background {
                if highlight {
                    Circle()
                        .fill(.white.opacity(configuration.isPressed ? 0.14 : 0))
                        .padding(-8)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 1), value: configuration.isPressed)
    }
}

// MARK: - Content transition

/// Content "materializes" — blur, scale and opacity move together, anchored to
/// the notch so it grows out of the island rather than appearing in place.
private struct Materialize: ViewModifier {
    let progress: CGFloat // 0 = gone, 1 = present

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 8)
            .scaleEffect(0.9 + 0.1 * progress, anchor: .top)
    }
}

extension AnyTransition {
    static var materialize: AnyTransition {
        .modifier(active: Materialize(progress: 0), identity: Materialize(progress: 1))
    }
}

// MARK: - Battery glyph

struct BatteryGlyph: View {
    let level: Int
    let isCharging: Bool

    private var fill: Color {
        if isCharging { return .green }
        if level <= 20 { return .red }
        return .white
    }

    var body: some View {
        HStack(spacing: 1.5) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .strokeBorder(.white.opacity(0.4), lineWidth: 1)
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(fill)
                        .frame(width: max(2, (geo.size.width - 4) * CGFloat(level) / 100))
                        .padding(2)
                }
                if isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 7, weight: .black))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(width: 24, height: 12)
            RoundedRectangle(cornerRadius: 1)
                .fill(.white.opacity(0.4))
                .frame(width: 1.5, height: 4)
        }
        .animation(IslandModel.settle, value: level)
    }
}

// MARK: - Equalizer

/// Little bars that dance while music plays; frozen when paused or when the
/// user prefers reduced motion.
struct Equalizer: View {
    let isPlaying: Bool
    var color: Color = .white
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let phases: [Double] = [0, 1.7, 0.6, 2.4]
    private let speeds: [Double] = [7.1, 9.3, 6.2, 8.4]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying || reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let wave = (sin(t * speeds[i] + phases[i]) + 1) / 2
                    let height = isPlaying && !reduceMotion ? 0.3 + 0.7 * wave : 0.3
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: 14 * height)
                }
            }
            .frame(height: 14)
        }
    }
}

// MARK: - AirDrop glyph

/// Concentric open rings — SF Symbols has no public AirDrop symbol.
struct AirDropGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach([1.0, 0.68, 0.36], id: \.self) { scale in
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .rotation(.degrees(140))
                        .stroke(style: StrokeStyle(lineWidth: side * 0.085, lineCap: .round))
                        .frame(width: side * scale - side * 0.085, height: side * scale - side * 0.085)
                }
                Circle().frame(width: side * 0.14, height: side * 0.14)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Artwork

struct Artwork: View {
    let image: NSImage?
    let size: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                LinearGradient(colors: [Color(white: 0.22), Color(white: 0.12)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}
