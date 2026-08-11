import Foundation
import Testing
@testable import Countpane

@Suite("Countdown progress")
struct CountdownProgressTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Progress is clamped between zero and one")
    func clampedProgress() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let target = calendar.date(from: DateComponents(year: 2026, month: 1, day: 11))!
        var item = CountdownItem(title: "Test", targetDate: target, createdAt: start)

        #expect(item.progress(at: calendar.date(byAdding: .day, value: -2, to: start)!, calendar: calendar) == 0)
        #expect(item.progress(at: calendar.date(byAdding: .day, value: 5, to: start)!, calendar: calendar) == 0.5)
        #expect(item.progress(at: calendar.date(byAdding: .day, value: 20, to: start)!, calendar: calendar) == 1)

        item.createdAt = target
        #expect(item.progress(at: start, calendar: calendar) == nil)
    }

    @Test("Invalid progress ranges are hidden")
    func invalidRange() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let item = CountdownItem(title: "Invalid", targetDate: date, createdAt: date)
        #expect(item.progress(at: date, calendar: calendar) == nil)
    }
}
