import AppKit
import Foundation

enum AppIconResource {
    static var image: NSImage? {
        guard let url = resourceURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    static func resourceURL(
        bundleURL: URL = Bundle.main.bundleURL,
        resourceURL: URL? = Bundle.main.resourceURL
    ) -> URL? {
        let fileManager = FileManager.default
        let executableDirectory = bundleURL.deletingLastPathComponent()
        let candidates = [
            resourceURL?.appendingPathComponent("AppIcon.icns"),
            bundleURL.appendingPathComponent("Contents/Resources/AppIcon.icns"),
            executableDirectory.appendingPathComponent("Resources/AppIcon.icns")
        ]

        return candidates.compactMap { $0 }.first(where: { fileManager.fileExists(atPath: $0.path) })
    }

    @MainActor
    static func menuBarImage(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        let inset: CGFloat = 1.25
        let bounds = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let radius = bounds.width / 2

        image.lockFocus()
        defer { image.unlockFocus() }

        let track = NSBezierPath(ovalIn: bounds)
        track.lineWidth = 1.4
        NSColor.black.withAlphaComponent(0.5).setStroke()
        track.stroke()

        let progress = NSBezierPath()
        progress.appendArc(
            withCenter: center,
            radius: radius,
            startAngle: 90,
            endAngle: -174,
            clockwise: true
        )
        progress.lineWidth = 2.2
        progress.lineCapStyle = .round
        NSColor.black.setStroke()
        progress.stroke()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        let numeral = "9" as NSString
        let numeralSize = numeral.size(withAttributes: attributes)
        numeral.draw(
            at: NSPoint(
                x: (size - numeralSize.width) / 2,
                y: (size - numeralSize.height) / 2 + 0.3
            ),
            withAttributes: attributes
        )

        image.isTemplate = true
        return image
    }
}
