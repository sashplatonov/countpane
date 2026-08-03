import Foundation
import Testing
@testable import Countpane

@Suite("Desktop widget model")
@MainActor
struct DesktopWidgetModelTests {
    @Test("Only active visible countdowns become desktop widgets")
    func visibleItems() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WidgetModel-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(repository: CountdownRepository(fileURL: directory.appending(path: "countpane.json")))
        let visible = CountdownItem(title: "Visible", targetDate: .now)
        var hidden = CountdownItem(title: "Hidden", targetDate: .now)
        hidden.isWidgetVisible = false
        var completed = CountdownItem(title: "Done", targetDate: .now)
        completed.isCompleted = true
        model.add(visible)
        model.add(hidden)
        model.add(completed)
        #expect(model.visibleWidgetItems.map(\.title) == ["Visible"])
        await model.saveImmediately()
    }

    @Test("Widget visibility is a model mutation")
    func mutations() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: "WidgetMutation-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppModel(repository: CountdownRepository(fileURL: directory.appending(path: "countpane.json")))
        let item = CountdownItem(title: "Trip", targetDate: .now)
        model.add(item)
        model.setWidgetVisible(item, false)
        #expect(model.item(id: item.id)?.isWidgetVisible == false)
        await model.saveImmediately()
    }
}
