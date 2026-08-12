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

    @Test("An off-screen widget is rehomed to a visible display")
    func rehomesOffScreenWidget() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

        #expect(WidgetWindowPlacement.origin(
            for: CGPoint(x: 4_000, y: 4_000),
            widgetSize: CGSize(width: 294, height: 184),
            screenFrames: [screen],
            fallbackIndex: 0
        ) == CGPoint(x: 1_602, y: 824))
    }

    @Test("Rehomed widgets retain distinct cascade positions")
    func cascadesMultipleOffScreenWidgets() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)
        let widgetSize = CGSize(width: 294, height: 184)

        let first = WidgetWindowPlacement.origin(
            for: CGPoint(x: 4_000, y: 4_000),
            widgetSize: widgetSize,
            screenFrames: [screen],
            fallbackIndex: 0
        )
        let second = WidgetWindowPlacement.origin(
            for: CGPoint(x: 5_000, y: 5_000),
            widgetSize: widgetSize,
            screenFrames: [screen],
            fallbackIndex: 1
        )

        #expect(first != second)
        #expect(second == CGPoint(x: 1_602, y: 800))
    }

    @Test("A partially visible widget is clamped inside the screen")
    func clampsPartiallyVisibleWidget() {
        let screen = CGRect(x: 0, y: 0, width: 1_920, height: 1_080)

        #expect(WidgetWindowPlacement.origin(
            for: CGPoint(x: 1_850, y: 1_020),
            widgetSize: CGSize(width: 294, height: 184),
            screenFrames: [screen],
            fallbackIndex: 0
        ) == CGPoint(x: 1_626, y: 896))
    }
}
