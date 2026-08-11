import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController: NSObject, NSWindowDelegate {
    static let shared = WidgetWindowController()

    private let positionStore = WidgetWindowPositionStore()
    private var windows: [UUID: WidgetPanel] = [:]

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        rehomeWindows()
    }

    func sync(with items: [CountdownItem]) {
        let visibleItems = items.filter { !$0.isCompleted && $0.isWidgetVisible }
        let visibleIDs = Set(visibleItems.map(\.id))
        for id in Set(windows.keys).subtracting(visibleIDs) {
            dismiss(id: id)
        }
        for (index, item) in visibleItems.enumerated() {
            present(id: item.id, initialPositionIndex: index)
        }
    }

    func present(id: UUID, initialPositionIndex: Int = 0) {
        guard windows[id] == nil else { return }

        let panel = WidgetPanel(
            contentRect: NSRect(origin: .zero, size: Self.widgetSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier(id.uuidString)
        panel.delegate = self
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(
            rootView: CountdownWidgetView(id: id).environment(AppModel.shared)
        )

        panel.setFrameOrigin(origin(for: id, initialPositionIndex: initialPositionIndex))

        windows[id] = panel
        panel.orderFrontRegardless()
    }

    func dismiss(id: UUID) {
        guard let panel = windows.removeValue(forKey: id) else { return }
        panel.orderOut(nil)
        panel.delegate = nil
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = panel.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        positionStore.save(panel.frame.origin, for: id)
    }

    private static let widgetSize = NSSize(width: 294, height: 184)

    private func origin(for id: UUID, initialPositionIndex: Int) -> CGPoint {
        WidgetWindowPlacement.origin(
            for: positionStore.origin(for: id),
            widgetSize: Self.widgetSize,
            screenFrames: NSScreen.screens.map(\.visibleFrame),
            fallbackIndex: initialPositionIndex
        )
    }

    private func rehomeWindows() {
        for (id, panel) in windows {
            let origin = self.origin(for: id, initialPositionIndex: 0)
            if panel.frame.origin != origin {
                panel.setFrameOrigin(origin)
            }
        }
    }
}

enum WidgetWindowPlacement {
    static func origin(
        for storedOrigin: CGPoint?,
        widgetSize: CGSize,
        screenFrames: [CGRect],
        fallbackIndex: Int,
        edgeInset: CGFloat = 24
    ) -> CGPoint {
        guard !screenFrames.isEmpty else { return storedOrigin ?? .zero }

        if let storedOrigin {
            let storedFrame = CGRect(origin: storedOrigin, size: widgetSize)
            if let screen = screenFrames.first(where: { $0.intersects(storedFrame) }) {
                return clamped(storedOrigin, widgetSize: widgetSize, in: screen)
            }
        }

        let screen = screenFrames[max(0, fallbackIndex) % screenFrames.count]
        let proposed = CGPoint(
            x: screen.maxX - widgetSize.width - edgeInset,
            y: screen.maxY - widgetSize.height - 72 - CGFloat(max(0, fallbackIndex)) * 24
        )
        return clamped(proposed, widgetSize: widgetSize, in: screen)
    }

    private static func clamped(_ origin: CGPoint, widgetSize: CGSize, in screen: CGRect) -> CGPoint {
        let maxX = max(screen.minX, screen.maxX - widgetSize.width)
        let maxY = max(screen.minY, screen.maxY - widgetSize.height)
        return CGPoint(
            x: min(max(origin.x, screen.minX), maxX),
            y: min(max(origin.y, screen.minY), maxY)
        )
    }
}

private final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private static let performWindowDragSelector = NSSelectorFromString("performWindowDragWithEvent:")

    override func sendEvent(_ event: NSEvent) {
        guard event.type == .leftMouseDown,
              let contentView,
              responds(to: Self.performWindowDragSelector) else {
            super.sendEvent(event)
            return
        }

        let location = contentView.convert(event.locationInWindow, from: nil)
        guard WidgetWindowDragRegion.shouldBeginDrag(at: location, in: contentView.bounds.size) else {
            super.sendEvent(event)
            return
        }

        perform(Self.performWindowDragSelector, with: event)
    }
}

enum WidgetWindowDragRegion {
    static let outerInset: CGFloat = 12
    static let closeButtonHitSize: CGFloat = 44

    static func shouldBeginDrag(at location: CGPoint, in contentSize: CGSize) -> Bool {
        !closeButtonFrame(in: contentSize).contains(location)
    }

    static func closeButtonFrame(in contentSize: CGSize) -> CGRect {
        let size = closeButtonHitSize
        return CGRect(
            x: contentSize.width - outerInset - size,
            y: contentSize.height - outerInset - size,
            width: size,
            height: size
        )
    }
}

struct WidgetWindowPositionStore {
    private let defaults: UserDefaults
    private let keyPrefix = "Countpane.widgetPosition."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func origin(for id: UUID) -> CGPoint? {
        guard let value = defaults.dictionary(forKey: key(for: id)),
              let x = value["x"] as? Double,
              let y = value["y"] as? Double else { return nil }
        return CGPoint(x: x, y: y)
    }

    func save(_ origin: CGPoint, for id: UUID) {
        defaults.set(["x": origin.x, "y": origin.y], forKey: key(for: id))
    }

    private func key(for id: UUID) -> String { keyPrefix + id.uuidString }
}
