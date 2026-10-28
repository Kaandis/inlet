import AppKit
import SwiftUI

/// Short-lived things the island pops out to show, then retracts.
enum Transient: Equatable {
    case volume(level: Float, muted: Bool)
    case brightness(level: Float)
    case charging(level: Int, isCharging: Bool)
    case lowBattery(level: Int)
    case upcomingEvent(title: String, start: Date, color: Color)
    case unlocked
    case timerDone
    case bluetooth(name: String, symbol: String, connected: Bool)
    case capsLock(on: Bool)
    case trayAdded(count: Int)

    /// Volume and brightness replace each other in place instead of re-animating.
    var isHUD: Bool {
        switch self {
        case .volume, .brightness: true
        default: false
        }
    }

    /// Small enough to share the compact "activity" footprint.
    var isCompact: Bool {
        switch self {
        case .unlocked, .capsLock: true
        default: false
        }
    }
}

enum ExpandedTab: String, CaseIterable {
    case media
    case calendar
    case tray
    case timer

    var symbol: String {
        switch self {
        case .media: "music.note"
        case .calendar: "calendar"
        case .tray: "tray.full.fill"
        case .timer: "timer"
        }
    }
}

/// Where a file drag is hovering while the drop zones are showing.
enum DropZone: Equatable {
    case tray
    case airDrop
}

/// What the island is currently presenting; drives its size and content.
enum Presentation: Equatable {
    case idle
    case activity          // music playing, collapsed
    case locked            // lock glyph on the lock screen
    case timer             // countdown running, collapsed
    case hud               // volume / brightness bar
    case notice            // charging, low battery, upcoming event, bluetooth…
    case compactNotice     // unlocked, caps lock
    case drop              // files are being dragged over the island
    case expanded
}

@MainActor
final class IslandModel: ObservableObject {
    @Published private(set) var isExpanded = false
    @Published private(set) var isHovering = false
    @Published private(set) var transient: Transient?
    @Published private(set) var isLocked = false
    @Published var tab: ExpandedTab = .media

    /// Non-nil while a file drag is over the island; the zone under the pointer.
    @Published var dropTarget: DropZone?
    /// A file drag is in progress somewhere on screen; the island leans out to invite it.
    @Published private(set) var dragInvite = false

    /// Continuous feedback while a vertical swipe is in progress (points, can be negative).
    @Published var stretch: CGFloat = 0
    /// Continuous feedback while a horizontal swipe on the player is in progress.
    @Published var swipeOffset: CGFloat = 0

    @Published var notchSize = CGSize(width: 190, height: 32)
    @Published var hasHardwareNotch = true

    let media: NowPlayingService
    let battery: BatteryService
    let calendar: CalendarService
    let tray: TrayStore
    let timer: TimerService

    private var transientTask: Task<Void, Never>?

    init(media: NowPlayingService, battery: BatteryService, calendar: CalendarService,
         tray: TrayStore, timer: TimerService) {
        self.media = media
        self.battery = battery
        self.calendar = calendar
        self.tray = tray
        self.timer = timer
    }

    // MARK: - Presentation & geometry

    var isDragging: Bool { dropTarget != nil }

    var presentation: Presentation {
        if isDragging { return .drop }
        if isExpanded { return .expanded }
        if let transient {
            if transient.isHUD { return .hud }
            return transient.isCompact ? .compactNotice : .notice
        }
        if isLocked { return .locked }
        if timer.isActive { return .timer }
        if Prefs.bool(Prefs.mediaEnabled), media.track?.isPlaying == true { return .activity }
        return .idle
    }

    /// Concave flare radius where the island meets the screen edge.
    var topRadius: CGFloat { isExpanded || isDragging ? 14 : 7 }
    var bottomRadius: CGFloat { isExpanded || isDragging ? 34 : max(10, notchSize.height * 0.36) }

    /// Size of the island body (without the top flares).
    var bodySize: CGSize {
        let n = notchSize
        let side = n.height + 8
        var size: CGSize
        switch presentation {
        case .expanded, .drop:
            // Dragging a file opens the tray page at full size.
            size = expandedBodySize
        case .hud:
            size = CGSize(width: n.width + 2 * 96, height: n.height)
        case .notice:
            size = CGSize(width: n.width + 2 * 120, height: n.height)
        case .timer:
            size = CGSize(width: n.width + 2 * 66, height: n.height)
        case .compactNotice:
            size = CGSize(width: n.width + 2 * 84, height: n.height)
        case .activity, .locked:
            size = CGSize(width: n.width + 2 * side, height: n.height)
        case .idle:
            size = n
        }
        if (isHovering || dragInvite) && !isExpanded && !isDragging {
            size.width += 18
            size.height += 6
        }
        size.height = max(n.height * 0.6, size.height + stretch)
        if stretch > 0 { size.width += stretch * 0.5 }
        return size
    }

    var expandedBodySize: CGSize {
        CGSize(width: max(notchSize.width + 340, 580), height: 204)
    }

    /// Full shape size including flares — used for layout and hit-testing.
    var shapeSize: CGSize {
        let body = bodySize
        return CGSize(width: body.width + 2 * topRadius, height: body.height)
    }

    // MARK: - Animation

    /// Critically damped by default: graceful, no overshoot.
    static let settle = Animation.spring(response: 0.4, dampingFraction: 1.0)
    /// Slight bounce only when a swipe handed us momentum.
    static let fling = Animation.spring(response: 0.38, dampingFraction: 0.78)
    static let reduced = Animation.easeInOut(duration: 0.18)

    private func animation(fromGesture: Bool) -> Animation {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { return Self.reduced }
        return fromGesture ? Self.fling : Self.settle
    }

    // MARK: - Intents

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        withAnimation(animation(fromGesture: false)) { isHovering = hovering }
        if hovering && !isExpanded { haptic() }
    }

    func expand(fromGesture: Bool = false) {
        guard !isExpanded else { return }
        transientTask?.cancel()
        withAnimation(animation(fromGesture: fromGesture)) {
            isExpanded = true
            transient = nil
            stretch = 0
        }
        haptic()
    }

    func collapse(fromGesture: Bool = false) {
        guard isExpanded else { return }
        withAnimation(animation(fromGesture: fromGesture)) {
            isExpanded = false
            stretch = 0
        }
    }

    func toggle() { isExpanded ? collapse() : expand() }

    func open(_ tab: ExpandedTab) {
        withAnimation(animation(fromGesture: false)) { self.tab = tab }
        expand()
    }

    func releaseStretch() {
        withAnimation(animation(fromGesture: true)) {
            stretch = 0
            swipeOffset = 0
        }
    }

    func setDropTarget(_ zone: DropZone?) {
        guard zone != dropTarget else { return }
        let entering = dropTarget == nil && zone != nil
        withAnimation(animation(fromGesture: false)) { dropTarget = zone }
        if entering || zone != nil { haptic() }
    }

    /// Files landed in the tray: go straight to the tray page in one
    /// transaction, so the island never flashes back to idle in between.
    func finishDropIntoTray() {
        transientTask?.cancel()
        withAnimation(animation(fromGesture: false)) {
            dropTarget = nil
            dragInvite = false
            transient = nil
            tab = .tray
            isExpanded = true
            isHovering = true
        }
    }

    func setDragInvite(_ invite: Bool) {
        guard invite != dragInvite else { return }
        withAnimation(animation(fromGesture: false)) { dragInvite = invite }
    }

    func setLocked(_ locked: Bool) {
        guard locked != isLocked else { return }
        if locked {
            collapse()
            withAnimation(animation(fromGesture: false)) { isLocked = true }
        } else {
            withAnimation(animation(fromGesture: false)) { isLocked = false }
            show(.unlocked, for: 1.1)
        }
    }

    func show(_ item: Transient, for duration: TimeInterval = 2.2) {
        guard !isExpanded, !isDragging else { return }
        let replacingHUD = transient?.isHUD == true && item.isHUD
        transientTask?.cancel()
        if replacingHUD {
            // Same shape, new value: let the bar glide without re-popping the island.
            withAnimation(.spring(response: 0.25, dampingFraction: 1.0)) { transient = item }
        } else {
            withAnimation(animation(fromGesture: false)) { transient = item }
        }
        transientTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            withAnimation(self.animation(fromGesture: false)) { self.transient = nil }
        }
    }

    func haptic() {
        guard Prefs.bool(Prefs.hapticFeedback) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }
}
