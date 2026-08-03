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
}
