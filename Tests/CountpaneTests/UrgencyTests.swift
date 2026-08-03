import Foundation
import Testing
@testable import Countpane

@Suite("Urgency thresholds")
struct UrgencyTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Default 14, 7, and 3 day boundaries")
    func defaultBoundaries() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        var item = CountdownItem(title: "Test", targetDate: now)

        item.targetDate = calendar.date(byAdding: .day, value: 15, to: now)!
        #expect(item.urgency(from: now) == .normal)

        item.targetDate = calendar.date(byAdding: .day, value: 14, to: now)!
        #expect(item.urgency(from: now) == .soon)

        item.targetDate = calendar.date(byAdding: .day, value: 7, to: now)!
        #expect(item.urgency(from: now) == .hurry)

        item.targetDate = calendar.date(byAdding: .day, value: 3, to: now)!
        #expect(item.urgency(from: now) == .almost)

        item.targetDate = now
        #expect(item.urgency(from: now) == .almost)

        item.targetDate = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(item.urgency(from: now) == .overdue)
    }

    @Test("Custom thresholds are respected")
    func customThresholds() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        var item = CountdownItem(title: "Launch", targetDate: now)
        item.soonThreshold = 60
        item.hurryThreshold = 30
        item.almostThreshold = 10

        item.targetDate = calendar.date(byAdding: .day, value: 45, to: now)!
        #expect(item.urgency(from: now) == .soon)

        item.targetDate = calendar.date(byAdding: .day, value: 20, to: now)!
        #expect(item.urgency(from: now) == .hurry)

        item.targetDate = calendar.date(byAdding: .day, value: 5, to: now)!
        #expect(item.urgency(from: now) == .almost)
    }

    @Test("Invalid thresholds are normalized into strict descending order")
    func normalizesInvalidThresholds() {
        var item = CountdownItem(title: "Test", targetDate: .now)
        item.soonThreshold = 1
        item.hurryThreshold = 1
        item.almostThreshold = -3

        item.normalizeThresholds()

        #expect(item.almostThreshold == 0)
        #expect(item.hurryThreshold == 1)
        #expect(item.soonThreshold == 2)
    }
}
