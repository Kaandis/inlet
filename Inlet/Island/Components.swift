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

// MARK: - Level bars

/// Little bars that dance while music plays.
///
/// Driven by repeating Core Animation animations, so the render server runs
/// them and the app itself stays idle — a SwiftUI TimelineView redrawing the
/// island every frame cost ~7% CPU and 130 wakeups a second.
struct PulseBars: View {
    let count: Int
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2
    var height: CGFloat = 14
    var minScale: CGFloat = 0.3
    var color: Color = .white
    let isAnimating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isStaticRender) private var isStaticRender

    private var width: CGFloat { CGFloat(count) * barWidth + CGFloat(count - 1) * spacing }

    var body: some View {
        Group {
            if isStaticRender {
                // ImageRenderer can't draw AppKit views; a still frame is enough there.
                HStack(spacing: spacing) {
                    ForEach(0..<count, id: \.self) { i in
                        Capsule().fill(color)
                            .frame(width: barWidth, height: height * (isAnimating ? [0.55, 1, 0.7, 0.85, 0.45][i % 5] : minScale))
                    }
                }
            } else {
                PulseBarsLayer(count: count, barWidth: barWidth, spacing: spacing, minScale: minScale,
                               color: NSColor(color), isAnimating: isAnimating && !reduceMotion)
            }
        }
        .frame(width: width, height: height)
    }
}

private struct PulseBarsLayer: NSViewRepresentable {
    let count: Int
    let barWidth: CGFloat
    let spacing: CGFloat
    let minScale: CGFloat
    let color: NSColor
    let isAnimating: Bool

    func makeNSView(context: Context) -> PulseBarsView { PulseBarsView() }

    func updateNSView(_ view: PulseBarsView, context: Context) {
        view.configure(count: count, barWidth: barWidth, spacing: spacing, minScale: minScale,
                       color: color, animating: isAnimating)
    }
}

final class PulseBarsView: NSView {
    private var bars: [CALayer] = []
    private var barWidth: CGFloat = 2.5
    private var spacing: CGFloat = 2
    private var minScale: CGFloat = 0.3
    private var animating = false

    /// Slightly different periods so the bars never fall into step.
    private static let durations: [CFTimeInterval] = [0.42, 0.31, 0.53, 0.37, 0.47]

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimations()
    }

    func configure(count: Int, barWidth: CGFloat, spacing: CGFloat, minScale: CGFloat, color: NSColor, animating: Bool) {
        self.barWidth = barWidth
        self.spacing = spacing
        self.minScale = minScale
        if bars.count != count {
            bars.forEach { $0.removeFromSuperlayer() }
            bars = (0..<count).map { _ in
                let bar = CALayer()
                bar.cornerCurve = .continuous
                layer?.addSublayer(bar)
                return bar
            }
            needsLayout = true
        }
        bars.forEach { $0.backgroundColor = color.cgColor }
        guard animating != self.animating || bars.first?.animation(forKey: "pulse") == nil && animating else { return }
        self.animating = animating
        updateAnimations()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (i, bar) in bars.enumerated() {
            bar.bounds = CGRect(x: 0, y: 0, width: barWidth, height: bounds.height)
            bar.position = CGPoint(x: CGFloat(i) * (barWidth + spacing) + barWidth / 2, y: bounds.midY)
            bar.cornerRadius = barWidth / 2
        }
        CATransaction.commit()
        updateAnimations()
    }

    private func updateAnimations() {
        for (i, bar) in bars.enumerated() {
            bar.removeAnimation(forKey: "pulse")
            bar.transform = CATransform3DMakeScale(1, minScale, 1)
            guard animating else { continue }
            let pulse = CABasicAnimation(keyPath: "transform.scale.y")
            pulse.fromValue = minScale
            pulse.toValue = 1
            pulse.duration = Self.durations[i % Self.durations.count]
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            pulse.timeOffset = Double(i) * 0.13
            bar.add(pulse, forKey: "pulse")
        }
    }
}

/// The island's equalizer.
struct Equalizer: View {
    let isPlaying: Bool
    var color: Color = .white

    var body: some View {
        PulseBars(count: 4, color: color, isAnimating: isPlaying)
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
