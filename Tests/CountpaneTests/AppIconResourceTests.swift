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

    @Test("Menu-bar icon uses the compact status-item size")
    @MainActor
    func menuBarIconSize() {
        let image = AppIconResource.menuBarImage(size: MenuBarAppIcon.size)

        #expect(image.size == NSSize(width: 18, height: 18))
        #expect(image.isTemplate)
    }
}
