import Foundation
import Testing
@testable import Countpane

@Suite("Sharing text")
struct CountdownShareTextTests {
    @Test("Future countdown copy contains status and target date")
    func futureText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let target = calendar.date(byAdding: .day, value: 8, to: now)!
        let item = CountdownItem(title: "Vacation", targetDate: target, createdAt: now)
        let text = item.shareText(from: now, calendar: calendar)

        #expect(text.contains("Vacation - 1 week 1 day remaining"))
        #expect(text.contains("Target date:"))
    }

    @Test("Overdue copy says overdue")
    func overdueText() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let target = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let now = calendar.date(byAdding: .day, value: 2, to: target)!
        let item = CountdownItem(title: "Deadline", targetDate: target, createdAt: target)
        #expect(item.shareText(from: now, calendar: calendar).contains("2 days overdue"))
    }
}
