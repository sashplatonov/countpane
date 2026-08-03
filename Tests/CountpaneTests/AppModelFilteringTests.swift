import Foundation
import Testing
@testable import Countpane

@Suite("App model ordering and filtering")
@MainActor
struct AppModelTests {
    @Test("Pinned items stay above the selected sort mode")
    func pinnedFirst() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: location))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let later = CountdownItem(title: "Later", targetDate: base.addingTimeInterval(86_400 * 10), createdAt: base)
        var pinned = CountdownItem(title: "Pinned", targetDate: base.addingTimeInterval(86_400 * 20), createdAt: base)
        pinned.isPinned = true
        model.add(later)
        model.add(pinned)

        #expect(model.activeItems(at: base).map(\.title) == ["Pinned", "Later"])
        await model.saveImmediately()
    }

    @Test("Search applies to active and completed collections")
    func searchFiltering() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: location))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let active = CountdownItem(title: "Vacation", targetDate: date, note: "Spain")
        var completed = CountdownItem(title: "Release", targetDate: date, note: "Backend")
        completed.isCompleted = true
        completed.completedAt = date
        model.add(active)
        model.add(completed)

        model.searchText = "Spain"
        #expect(model.activeItems(at: date).map(\.title) == ["Vacation"])
        #expect(model.completedItems.isEmpty)

        model.searchText = "Backend"
        #expect(model.activeItems(at: date).isEmpty)
        #expect(model.completedItems.map(\.title) == ["Release"])
        await model.saveImmediately()
    }

    @Test("Completing an item removes its pin")
    func completeUnpins() async throws {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: location))
        var item = CountdownItem(title: "Pinned", targetDate: .now)
        item.isPinned = true
        model.add(item)
        model.complete(item)
        #expect(model.completedItems.first?.isPinned == false)
        await model.saveImmediately()
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountdownsModelTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.sqlite3")
    }
}
