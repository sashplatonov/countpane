import Foundation
import Testing
@testable import Countpane

@Suite("Desktop widget positions")
struct WidgetWindowPositionStoreTests {
    @Test("A widget restores its saved screen position")
    func restoresSavedPosition() {
        let suiteName = "WidgetWindowPositionStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = WidgetWindowPositionStore(defaults: defaults)
        let id = UUID()
        let expected = CGPoint(x: 421.5, y: 208.25)

        store.save(expected, for: id)

        #expect(store.origin(for: id) == expected)
        #expect(store.origin(for: UUID()) == nil)
    }

    @Test("Widget drag keeps the close button interactive")
    func dragRegion() {
        let contentSize = CGSize(width: 294, height: 184)

        #expect(WidgetWindowDragRegion.shouldBeginDrag(at: CGPoint(x: 40, y: 40), in: contentSize))
        #expect(!WidgetWindowDragRegion.shouldBeginDrag(at: CGPoint(x: 260, y: 150), in: contentSize))
    }
}
