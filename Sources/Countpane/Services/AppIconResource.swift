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
            resourceURL?.appendingPathComponent("AppIcon.png"),
            bundleURL.appendingPathComponent("Contents/Resources/AppIcon.png"),
            bundleURL.appendingPathComponent("Contents/Resources/Countpane_Countpane.bundle/AppIcon.png"),
            bundleURL.appendingPathComponent("Countpane_Countpane.bundle/AppIcon.png"),
            executableDirectory.appendingPathComponent("Countpane_Countpane.bundle/AppIcon.png")
        ]

        return candidates.compactMap { $0 }.first(where: { fileManager.fileExists(atPath: $0.path) })
    }
}
