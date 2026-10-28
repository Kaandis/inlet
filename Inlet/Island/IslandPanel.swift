import AppKit
import SwiftUI

/// Borderless, non-activating panel that sits above the menu bar on every Space.
final class IslandPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect,
                   styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        isReleasedWhenClosed = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Receives file drags for the whole panel canvas, so the drop target doesn't
/// depend on the island's animating shape (which made it flicker in and out).
@MainActor
protocol IslandDropHandler: AnyObject {
    func dragUpdated(_ info: NSDraggingInfo) -> NSDragOperation
    func dragExited()
    func performDrop(_ info: NSDraggingInfo) -> Bool
}

final class IslandContainerView: NSView {
    weak var dropHandler: IslandDropHandler?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Clicks go straight to the SwiftUI content.
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        return view === self ? nil : view
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropHandler?.dragUpdated(sender) ?? []
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropHandler?.dragUpdated(sender) ?? []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropHandler?.dragExited()
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropHandler?.performDrop(sender) ?? false
    }
}

/// Hosting view that reacts to the very first click even though the panel is never key.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
