import Foundation
import Testing
@testable import Countpane

@Suite("Accessibility contracts")
struct AccessibilityContractTests {
    @Test("Countdown cards expose duration and urgency semantics")
    func countdownSemantics() {
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let item = CountdownItem(
            title: "Launch",
            targetDate: calendar.date(byAdding: .day, value: 2, to: now)!,
            createdAt: now
        )

        #expect(item.remainingDuration(from: now, calendar: calendar).accessibilityText == "2 days remaining")
        #expect(item.urgency(from: now, calendar: calendar) == .almost)
    }

    @Test("Widget close remains a reachable hit target")
    func widgetCloseTarget() {
        let contentSize = CGSize(width: 270, height: 160)
        let closeFrame = WidgetWindowDragRegion.closeButtonFrame(in: contentSize)

        #expect(closeFrame.width == WidgetWindowDragRegion.closeButtonHitSize)
        #expect(closeFrame.height == WidgetWindowDragRegion.closeButtonHitSize)
        #expect(!WidgetWindowDragRegion.shouldBeginDrag(at: closeFrame.center, in: contentSize))
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
