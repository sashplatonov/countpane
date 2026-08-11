import AppKit
import Foundation

enum AppIconResource {
    static var image: NSImage? {
        guard let url = resourceURL() else { return nil }
        return NSImage(contentsOf: url)
    }

    static func menuBarImage(from source: NSImage? = AppIconResource.image, size: CGFloat) -> NSImage? {
        guard let image = source?.copy() as? NSImage else { return nil }
        image.size = NSSize(width: size, height: size)
        return image
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
}
