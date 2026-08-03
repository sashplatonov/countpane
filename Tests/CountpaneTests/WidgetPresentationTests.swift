import Foundation
import Testing
@testable import Countpane

@Suite("Desktop widget presentation")
struct DesktopWidgetPresentationTests {
    @Test("New countdowns show a desktop widget by default")
    func defaults() {
        let item = CountdownItem(title: "Trip", targetDate: .now)
        #expect(item.isWidgetVisible)
    }

}
