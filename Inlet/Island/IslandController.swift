import AppKit
import Combine
import SwiftUI

/// Owns the panel, wires services into the model, and turns raw mouse /
/// trackpad events into hover, click-outside and swipe intents.
@MainActor
final class IslandController: IslandDropHandler {
    private static let canvas = CGSize(width: 800, height: 300)

    private let media = NowPlayingService()
    private let battery = BatteryService()
    private let calendar = CalendarService()
    private let volume = VolumeService()
    private let brightness = BrightnessService()
    private let tray = TrayStore()
    private let timer = TimerService()
    private let bluetooth = BluetoothService()
    private let capsLock = CapsLockService()
    private let lockState = LockStateObserver()
    private let model: IslandModel
    private lazy var lockWidget = LockScreenWidgetController(model: model, media: media, battery: battery, calendar: calendar)

    private var panel: IslandPanel?
    /// Twin of `panel` that lives in the lock-screen space. Windows in that
    /// space never receive drag-and-drop, so the everyday island stays a
    /// normal window and this one is only ordered in while the Mac is locked.
    private var lockPanel: IslandPanel?
    private var unlockHideTask: Task<Void, Never>?
    private var screen: NSScreen?
    private var monitors: [Any] = []
    private var cancellables: Set<AnyCancellable> = []
    private var hoverTask: Task<Void, Never>?
    private var swipe = SwipeTracker()
    private var dragPoll: Timer?
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount

    init() {
        model = IslandModel(media: media, battery: battery, calendar: calendar, tray: tray, timer: timer)
    }

    func start() {
        layout()
        installMonitors()
        wireServices()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in self?.layout() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.layout()
                self?.applyServicePrefs()
            }
            .store(in: &cancellables)
    }

    // MARK: - Screen & window

    private func targetScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
            return notched
        }
        guard Prefs.bool(Prefs.showOnNonNotchDisplays) else { return nil }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func layout() {
        guard let screen = targetScreen() else {
            panel?.orderOut(nil)
            self.screen = nil
            return
        }
        self.screen = screen

        let insetTop = screen.safeAreaInsets.top
        if insetTop > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            model.notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: insetTop)
            model.hasHardwareNotch = true
        } else {
            let menuBar = max(24, screen.frame.maxY - screen.visibleFrame.maxY)
            model.notchSize = CGSize(width: 180, height: menuBar)
            model.hasHardwareNotch = false
        }

        let size = Self.canvas
        let frame = NSRect(x: screen.frame.midX - size.width / 2,
                           y: screen.frame.maxY - size.height,
                           width: size.width,
                           height: size.height)

        if panel == nil {
            let panel = IslandPanel(contentRect: frame)
            let container = IslandContainerView(frame: NSRect(origin: .zero, size: size))
            container.dropHandler = self
            let host = makeHost(size: size)
            host.frame = container.bounds
            container.addSubview(host)
            panel.contentView = container
            self.panel = panel
        }
        panel?.setFrame(frame, display: true)
        panel?.orderFrontRegardless()

        if Prefs.bool(Prefs.showOnLockScreen) {
            if lockPanel == nil {
                let lockPanel = IslandPanel(contentRect: frame)
                lockPanel.contentView = makeHost(size: size)
                self.lockPanel = lockPanel
            }
            lockPanel?.setFrame(frame, display: true)
            if model.isLocked { showLockPanel() }
            lockWidget.layout(on: screen)
        } else {
            lockPanel?.orderOut(nil)
        }
    }

    private func makeHost(size: CGSize) -> NSView {
        let root = IslandView(model: model, media: media, battery: battery, calendar: calendar,
                              tray: tray, timer: timer)
        let host = IslandHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        return host
    }

    private func showLockPanel() {
        guard Prefs.bool(Prefs.showOnLockScreen), let lockPanel else { return }
        unlockHideTask?.cancel()
        lockPanel.orderFrontRegardless()
        LockScreenSpace.shared.delegate(lockPanel)
    }

    /// Keep the twin up through the unlock animation, then step aside.
    private func hideLockPanelSoon() {
        unlockHideTask?.cancel()
        unlockHideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled, let self, !self.model.isLocked else { return }
            self.lockPanel?.orderOut(nil)
        }
    }

    /// The island's current rectangle in screen coordinates, padded so the
    /// collapsed notch is easy to hit.
    private func islandRect() -> NSRect? {
        guard let screen else { return nil }
        let size = model.shapeSize
        let pad: CGFloat = model.isExpanded ? 4 : 10
        return NSRect(x: screen.frame.midX - size.width / 2 - pad,
                      y: screen.frame.maxY - size.height - pad,
                      width: size.width + 2 * pad,
                      height: size.height + pad)
    }

    // MARK: - Events

    private func installMonitors() {
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: moveMask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseMoved() }
        }) { monitors.append(global) }

        if let local = NSEvent.addLocalMonitorForEvents(matching: moveMask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.mouseMoved() }
            return event
        }) { monitors.append(local) }

        // A click anywhere else dismisses the expanded island.
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.model.collapse() }
        }) { monitors.append(outside) }

        // While the button is held, keep tracking: file drags from Finder don't
        // always reach the global move monitor.
        if let down = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.beginDragPolling() }
        }) { monitors.append(down) }

        if let scroll = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel, handler: { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated {
                guard event.window === self.panel else { return event }
                self.handleScroll(event)
                return nil
            }
        }) { monitors.append(scroll) }
    }

    private func beginDragPolling() {
        dragChangeCount = NSPasteboard(name: .drag).changeCount
        dragPoll?.invalidate()
        dragPoll = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard NSEvent.pressedMouseButtons & 1 != 0 else {
                    timer.invalidate()
                    self.model.setDragInvite(false)
                    self.mouseMoved()
                    return
                }
                // A new file drag anywhere on screen: let the island invite it.
                let pasteboard = NSPasteboard(name: .drag)
                if pasteboard.changeCount != self.dragChangeCount,
                   Prefs.bool(Prefs.trayEnabled),
                   pasteboard.types?.contains(.fileURL) == true {
                    if !self.model.dragInvite { DragLog.write("poll: file drag detected") }
                    self.model.setDragInvite(true)
                }
                self.mouseMoved()
            }
        }
    }

    private func mouseMoved() {
        guard let panel, let rect = islandRect() else { return }
        let inside = rect.contains(NSEvent.mouseLocation)
        // During a file drag the whole canvas listens, so the drop page can
        // open as the file approaches rather than only on the notch itself.
        panel.ignoresMouseEvents = !(inside || model.dragInvite)
        lockPanel?.ignoresMouseEvents = !inside

        // A file drag never opens the regular tabbed view; the drop page owns it.
        guard !model.dragInvite, !model.isDragging else { return }

        guard inside != model.isHovering else { return }
        model.setHovering(inside)
        hoverTask?.cancel()

        if inside {
            guard Prefs.bool(Prefs.expandOnHover) else { return }
            let delay = UserDefaults.standard.double(forKey: Prefs.hoverDelay)
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.model.expand()
            }
        } else if model.isExpanded {
            // Short grace period so brushing past the edge doesn't slam it shut.
            hoverTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled, let self, !self.model.isHovering else { return }
                self.model.collapse()
            }
        }
    }

    // MARK: - File drops

    func dragUpdated(_ info: NSDraggingInfo) -> NSDragOperation {
        // Drags that start in Inlet itself (pulling files out of the tray) are not drops.
        guard Prefs.bool(Prefs.trayEnabled), info.draggingSource == nil, let screen else {
            DragLog.write("dragUpdated: rejected (tray=\(Prefs.bool(Prefs.trayEnabled)) ownSource=\(info.draggingSource != nil))")
            return []
        }
        model.setDragInvite(true)
        let zone = dropZone(at: NSEvent.mouseLocation, on: screen)
        if zone != model.dropTarget { DragLog.write("dragUpdated: zone \(String(describing: zone)) at \(NSEvent.mouseLocation)") }
        model.setDropTarget(zone)
        return zone == nil ? [] : .copy
    }

    func dragExited() {
        DragLog.write("dragExited")
        model.setDropTarget(nil)
    }

    func performDrop(_ info: NSDraggingInfo) -> Bool {
        guard let zone = model.dropTarget else { return false }
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                        options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        DragLog.write("performDrop: zone \(zone) urls \(urls.count)")
        guard !urls.isEmpty else {
            model.setDropTarget(nil)
            return false
        }
        switch zone {
        case .tray:
            tray.add(urls)
            model.finishDropIntoTray()
        case .airDrop:
            model.setDropTarget(nil)
            TrayStore.airDrop(urls)
        }
        return true
    }

    /// Opens on approach (a generous area around the notch); once open, the
    /// whole drop page plus a margin keeps it open, so it doesn't flicker at the edge.
    private func dropZone(at point: NSPoint, on screen: NSScreen) -> DropZone? {
        let page = model.expandedBodySize
        let area: NSRect
        if model.isDragging {
            let width = page.width + 2 * 14 + 80
            area = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - page.height - 40,
                          width: width, height: page.height + 40)
        } else {
            let width = model.notchSize.width + 220
            let height = model.notchSize.height + 90
            area = NSRect(x: screen.frame.midX - width / 2, y: screen.frame.maxY - height,
                          width: width, height: height)
        }
        guard area.contains(point) else { return nil }
        // Tray takes the left ~60% of the page, AirDrop the rest.
        let split = screen.frame.midX - page.width / 2 + page.width * 0.6
        return point.x < split ? .tray : .airDrop
    }

    private func handleScroll(_ event: NSEvent) {
        guard Prefs.bool(Prefs.swipeGesturesEnabled) else { return }

        // Classic mouse wheel: no phases, treat each notch as a discrete step.
        if event.phase.isEmpty && event.momentumPhase.isEmpty {
            let dy = event.isDirectionInvertedFromDevice ? event.scrollingDeltaY : -event.scrollingDeltaY
            if dy > 1 { model.expand(fromGesture: true) }
            else if dy < -1 { model.collapse(fromGesture: true) }
            return
        }
        guard event.momentumPhase.isEmpty else { return }

        switch event.phase {
        case .began, .mayBegin:
            swipe = SwipeTracker()
        case .changed:
            swipe.add(event)
            applySwipeFeedback()
        case .ended, .cancelled:
            commitSwipe()
            swipe = SwipeTracker()
        default:
            break
        }
    }

    /// 1:1 rubber-banded feedback while fingers are still on the trackpad.
    private func applySwipeFeedback() {
        switch swipe.axis {
        case .vertical:
            let dy = swipe.total.height
            // Pulling down on a collapsed island stretches it; pushing up on an expanded one squeezes it.
            if !model.isExpanded {
                model.stretch = rubberband(max(0, dy), dimension: 120)
            } else {
                model.stretch = -rubberband(max(0, -dy), dimension: 120)
            }
        case .horizontal:
            if model.isExpanded && model.tab == .media {
                model.swipeOffset = rubberband(swipe.total.width, dimension: 160)
            }
        case .undecided:
            break
        }
    }

    private func commitSwipe() {
        let threshold: CGFloat = 36
        switch swipe.axis {
        case .vertical:
            let dy = swipe.total.height
            if dy > threshold && !model.isExpanded {
                model.expand(fromGesture: true)
            } else if dy < -threshold && model.isExpanded {
                model.collapse(fromGesture: true)
            } else {
                model.releaseStretch()
            }
        case .horizontal:
            let dx = swipe.total.width
            if model.isExpanded && model.tab == .media {
                if dx > threshold * 1.5 { media.previous() }
                else if dx < -threshold * 1.5 { media.next() }
            } else if !model.isExpanded && abs(dx) > threshold * 1.5 {
                dx < 0 ? media.next() : media.previous()
                model.haptic()
            }
            model.releaseStretch()
        case .undecided:
            model.releaseStretch()
        }
    }

    // MARK: - Services

    private func wireServices() {
        battery.onPluggedIn = { [weak self] level, charging in
            guard Prefs.bool(Prefs.batteryEnabled) else { return }
            self?.model.show(.charging(level: level, isCharging: charging), for: 3)
        }
        battery.onLowBattery = { [weak self] level in
            guard Prefs.bool(Prefs.batteryEnabled) else { return }
            self?.model.show(.lowBattery(level: level), for: 4)
        }
        volume.onChange = { [weak self] level, muted in
            guard Prefs.bool(Prefs.volumeHUDEnabled) else { return }
            self?.model.show(.volume(level: level, muted: muted), for: 1.6)
        }
        brightness.onChange = { [weak self] level in
            guard Prefs.bool(Prefs.brightnessHUDEnabled) else { return }
            self?.model.show(.brightness(level: level), for: 1.6)
        }
        timer.onFinish = { [weak self] in
            self?.model.show(.timerDone, for: 4)
        }
        bluetooth.onChange = { [weak self] name, symbol, connected in
            guard Prefs.bool(Prefs.bluetoothEnabled) else { return }
            self?.model.show(.bluetooth(name: name, symbol: symbol, connected: connected), for: 2.6)
        }
        capsLock.onChange = { [weak self] on in
            guard Prefs.bool(Prefs.capsLockEnabled) else { return }
            self?.model.show(.capsLock(on: on), for: 1.3)
        }
        lockState.onChange = { [weak self] locked in
            guard let self else { return }
            if locked {
                self.showLockPanel()
                self.lockWidget.willAppear()
            } else {
                self.hideLockPanelSoon()
            }
            self.model.setLocked(locked)
        }
        calendar.onUpcoming = { [weak self] event in
            guard Prefs.bool(Prefs.calendarEnabled) else { return }
            self?.model.show(.upcomingEvent(title: event.title, start: event.start, color: event.color), for: 5)
        }

        battery.start()
        volume.start()
        lockState.start()
        applyServicePrefs()
    }

    private func applyServicePrefs() {
        Prefs.bool(Prefs.mediaEnabled) ? media.start() : media.stop()
        Prefs.bool(Prefs.calendarEnabled) ? calendar.start() : calendar.stop()
        Prefs.bool(Prefs.brightnessHUDEnabled) ? brightness.start() : brightness.stop()
        Prefs.bool(Prefs.bluetoothEnabled) ? bluetooth.start() : bluetooth.stop()
        Prefs.bool(Prefs.capsLockEnabled) ? capsLock.start() : capsLock.stop()

        let slots = [LockWidgetKind.slot(Prefs.lockWidgetSlot1), LockWidgetKind.slot(Prefs.lockWidgetSlot2)]
        let lockScreen = Prefs.bool(Prefs.showOnLockScreen)
        if lockScreen && slots.contains(.weather) {
            WeatherService.shared.start()
            WeatherService.shared.refresh()
        } else {
            WeatherService.shared.stop()
        }
        lockScreen && slots.contains(.focus) ? FocusService.shared.start() : FocusService.shared.stop()
        if lockScreen && slots.contains(.nextEvent) { calendar.start() }
    }
}

// MARK: - Debug log

/// Debug builds append drag events to ~/Library/Logs/Inlet/drag.log, so a
/// failing drop can be traced to the step where it stops.
enum DragLog {
    static func write(_ message: @autoclosure () -> String) {
        #if DEBUG
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Inlet")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("drag.log")
        let line = "\(Date.now.formatted(.iso8601.time(includingFractionalSeconds: true))) \(message())\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
        #endif
    }
}

// MARK: - Swipe helpers

/// Accumulates trackpad deltas in *finger* direction (positive = down / right),
/// locking to one axis after a small hysteresis so diagonal noise doesn't flip it.
private struct SwipeTracker {
    enum Axis { case undecided, vertical, horizontal }

    private(set) var total: CGSize = .zero
    private(set) var axis: Axis = .undecided

    mutating func add(_ event: NSEvent) {
        let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
        total.width += event.scrollingDeltaX * sign
        total.height += event.scrollingDeltaY * sign

        if axis == .undecided, hypot(total.width, total.height) > 8 {
            axis = abs(total.height) >= abs(total.width) ? .vertical : .horizontal
        }
    }
}

/// The further past the bound, the less the element follows.
private func rubberband(_ offset: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
    let magnitude = (abs(offset) * dimension * constant) / (dimension + constant * abs(offset))
    return offset < 0 ? -magnitude : magnitude
}
