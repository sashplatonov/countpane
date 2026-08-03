import Foundation
import Testing
@testable import Countpane

@Suite("Dashboard snapshots")
@MainActor
struct DashboardSnapshotTests {
    @Test("One snapshot preserves counts, filters, and next item")
    func derivesDashboardDataFromOneInput() {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: location))
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        var pinned = CountdownItem(title: "Pinned", targetDate: now.addingTimeInterval(86_400))
        pinned.isPinned = true
        var today = CountdownItem(title: "Today", targetDate: now)
        today.isWidgetVisible = false
        var completed = CountdownItem(title: "Done", targetDate: now)
        completed.isCompleted = true
        completed.completedAt = now
        model.add(pinned)
        model.add(today)
        model.add(completed)

        let snapshot = model.dashboardSnapshot(
            at: now,
            filter: .all,
            includesCompletedItems: true
        )

        #expect(snapshot.activeCount == 2)
        #expect(snapshot.pinnedCount == 1)
        #expect(snapshot.todayCount == 1)
        #expect(snapshot.weekCount == 2)
        #expect(snapshot.completedItems.map(\.title) == ["Done"])
        #expect(snapshot.nextItem?.title == "Today")
        #expect(snapshot.filteredActiveItems.map(\.title) == ["Pinned", "Today"])
    }

    @Test("Filter selection is applied without changing stored items")
    func filtersUseTheSameActiveCollection() {
        let location = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: location.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: location))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var pinned = CountdownItem(title: "Pinned", targetDate: now.addingTimeInterval(86_400))
        pinned.isPinned = true
        model.add(pinned)
        model.add(CountdownItem(title: "Later", targetDate: now.addingTimeInterval(30 * 86_400)))

        let snapshot = model.dashboardSnapshot(
            at: now,
            filter: .pinned,
            includesCompletedItems: false
        )

        #expect(snapshot.activeCount == 2)
        #expect(snapshot.filteredActiveItems.map(\.title) == ["Pinned"])
        #expect(snapshot.completedItems.isEmpty)
        #expect(model.items.count == 2)
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountpaneDashboardTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.json")
    }
}
