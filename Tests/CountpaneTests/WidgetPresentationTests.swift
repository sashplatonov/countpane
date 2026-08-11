import Foundation
import Testing
@testable import Countpane

@Suite("Desktop widget presentation")
@MainActor
struct DesktopWidgetPresentationTests {
    @Test("Widget content preserves room for its perimeter")
    func contentSize() {
        #expect(CountdownWidgetView.contentSize == CGSize(width: 270, height: 160))
        #expect(CountdownWidgetView.closeButtonHitSize == 44)
    }

    @Test("New countdowns show a desktop widget by default")
    func defaults() {
        let item = CountdownItem(title: "Trip", targetDate: .now)
        #expect(item.isWidgetVisible)
    }

}
