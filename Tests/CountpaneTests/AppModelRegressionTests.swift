import Foundation
import Testing
@testable import Countpane

@Suite("App model review regressions")
@MainActor
struct AppModelReviewRegressionTests {
    @Test("Whitespace-only search behaves like an empty search")
    func whitespaceSearch() async {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: url))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        model.add(CountdownItem(title: "Vacation", targetDate: date))
        model.searchText = "   \n  "

        #expect(model.activeItems(at: date).map(\.title) == ["Vacation"])
        await model.saveImmediately()
    }

    @Test("Completed ordering is deterministic when completion dates match")
    func completedTieBreaker() async {
        let url = temporaryFileURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let model = AppModel(repository: CountdownRepository(fileURL: url))
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let lowID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var second = CountdownItem(title: "Second", targetDate: date)
        second.id = highID
        second.isCompleted = true
        second.completedAt = date
        var first = CountdownItem(title: "First", targetDate: date)
        first.id = lowID
        first.isCompleted = true
        first.completedAt = date
        model.add(second)
        model.add(first)

        #expect(model.completedItems.map(\.title) == ["First", "Second"])
        await model.saveImmediately()
    }

    private func temporaryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CountdownsReviewTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "countpane.json")
    }
}
