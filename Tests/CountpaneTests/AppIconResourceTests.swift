import AppKit
import Foundation
import Testing
@testable import Countpane

@Suite("Application icon resources")
struct AppIconResourceTests {
    @Test("Packaged application icon is loaded from Contents/Resources")
    func packagedApplicationIconIsFound() throws {
        let appURL = FileManager.default.temporaryDirectory
            .appending(path: "CountpaneIcon-\(UUID().uuidString).app", directoryHint: .isDirectory)
        let resourcesURL = appURL
            .appending(path: "Contents", directoryHint: .isDirectory)
            .appending(path: "Resources", directoryHint: .isDirectory)
        let iconURL = resourcesURL.appending(path: "AppIcon.icns")
        defer { try? FileManager.default.removeItem(at: appURL) }

        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        try Data().write(to: iconURL)

        #expect(AppIconResource.resourceURL(bundleURL: appURL, resourceURL: resourcesURL) == iconURL)
    }

    @Test("Menu-bar icon has a compact physical size")
    func menuBarIconSize() {
        let source = NSImage(size: NSSize(width: 512, height: 512))
        let image = AppIconResource.menuBarImage(from: source, size: 18)

        #expect(image?.size == NSSize(width: 18, height: 18))
    }
}
