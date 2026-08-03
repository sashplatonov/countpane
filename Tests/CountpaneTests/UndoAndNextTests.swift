import Foundation
import Testing
@testable import Countpane

@Suite("Undo and next countdown")
@MainActor
struct UndoAndNextTests {
    @Test("Completing and deleting can be undone")
    func undoActions() async {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: url))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let item = CountdownItem(title: "Deadline", targetDate: base.addingTimeInterval(86_400 * 5), createdAt: base)
        model.add(item)

        model.complete(item)
        #expect(model.completedItems.count == 1)
        model.undoLastAction()
        #expect(model.activeItems(at: base).count == 1)

        model.delete(item)
        #expect(model.activeItems(at: base).isEmpty)
        model.undoLastAction()
        #expect(model.activeItems(at: base).map(\.title) == ["Deadline"])
        await model.saveImmediately()
    }

    @Test("Next excludes overdue, distant and pinned countdowns")
    func nextSelection() async {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: url))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        model.add(CountdownItem(title: "Overdue", targetDate: base.addingTimeInterval(-86_400), createdAt: base))
        model.add(CountdownItem(title: "Far", targetDate: base.addingTimeInterval(86_400 * 120), createdAt: base))
        model.add(CountdownItem(title: "Later", targetDate: base.addingTimeInterval(86_400 * 20), createdAt: base))
        model.add(CountdownItem(title: "Sooner", targetDate: base.addingTimeInterval(86_400 * 5), createdAt: base))
        #expect(model.nextItem(at: base)?.title == "Sooner")

        var pinned = CountdownItem(title: "Pinned", targetDate: base.addingTimeInterval(86_400 * 30), createdAt: base)
        pinned.isPinned = true
        model.add(pinned)
        #expect(model.nextItem(at: base)?.title == "Sooner")
        await model.saveImmediately()
    }

    @Test("Next follows current search")
    func nextUsesSearch() async {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: url))
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        model.add(CountdownItem(title: "Vacation", targetDate: base.addingTimeInterval(86_400 * 15), note: "Spain"))
        model.add(CountdownItem(title: "Release", targetDate: base.addingTimeInterval(86_400 * 5), note: "Work"))
        model.searchText = "Spain"
        #expect(model.nextItem(at: base)?.title == "Vacation")
        await model.saveImmediately()
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountdownsUndoTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.sqlite3")
    }
}
