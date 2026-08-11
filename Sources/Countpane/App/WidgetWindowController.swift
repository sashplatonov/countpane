import AppKit
import SwiftUI

@MainActor
final class WidgetWindowController: NSObject, NSWindowDelegate {
    static let shared = WidgetWindowController()

    private let positionStore = WidgetWindowPositionStore()
    private var windows: [UUID: WidgetPanel] = [:]

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
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(
            rootView: CountdownWidgetView(id: id).environment(AppModel.shared)
        )

        if let origin = positionStore.origin(for: id) {
            panel.setFrameOrigin(origin)
        } else {
            panel.setFrameOrigin(initialOrigin(at: initialPositionIndex))
        }

        windows[id] = panel
        panel.orderFrontRegardless()
    }

    func dismiss(id: UUID) {
        guard let panel = windows.removeValue(forKey: id) else { return }
        panel.orderOut(nil)
        panel.delegate = nil
    }

    func origin(for id: UUID) -> CGPoint? {
        windows[id]?.frame.origin
    }

    func move(id: UUID, from origin: CGPoint, by translation: CGSize) {
        guard let panel = windows[id] else { return }
        panel.setFrameOrigin(
            CGPoint(
                x: origin.x + translation.width,
                y: origin.y - translation.height
            )
        )
    }

    func windowDidMove(_ notification: Notification) {
        guard let panel = notification.object as? NSWindow,
              let id = panel.identifier.flatMap({ UUID(uuidString: $0.rawValue) }) else { return }
        positionStore.save(panel.frame.origin, for: id)
    }

    private static let widgetSize = NSSize(width: 294, height: 184)

    private func initialOrigin(at index: Int) -> CGPoint {
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        return CGPoint(
            x: screenFrame.maxX - Self.widgetSize.width - 24,
            y: screenFrame.maxY - Self.widgetSize.height - 72 - CGFloat(index) * 24
        )
    }
}

private final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
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
