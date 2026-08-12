import Foundation
import Testing
@testable import Countpane

@Suite("Countdown duration formatting")
struct CountdownDurationTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Today has no remaining units")
    func today() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let duration = CountdownDuration.between(date, and: date, calendar: calendar)

        #expect(duration.totalDays == 0)
        #expect(duration.compactText == "Today")
        #expect(duration.accessibilityText == "today")
        #expect(!duration.isOverdue)
    }

    @Test("One day uses singular grammar")
    func oneDay() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let target = calendar.date(byAdding: .day, value: 1, to: start)!
        let duration = CountdownDuration.between(start, and: target, calendar: calendar)

        #expect(duration.compactText == "1 day")
        #expect(duration.accessibilityText == "1 day remaining")
    }

    @Test("Durations below a month use weeks and days", arguments: [
        (7, "1 week"),
        (8, "1 week 1 day"),
        (14, "2 weeks"),
        (23, "3 weeks 2 days"),
        (30, "4 weeks 2 days")
    ])
    func shortDuration(days: Int, expected: String) {
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let target = calendar.date(byAdding: .day, value: days, to: start)!
        let duration = CountdownDuration.between(start, and: target, calendar: calendar)

        #expect(duration.totalDays == days)
        #expect(duration.compactText == expected)
    }

    @Test("The 31 day boundary switches to calendar months")
    func monthBoundary() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let target = calendar.date(byAdding: .day, value: 31, to: start)!
        let duration = CountdownDuration.between(start, and: target, calendar: calendar)

        #expect(duration.totalDays == 31)
        #expect(duration.compactText == "1 month")
        #expect(duration.weeks == 0)
    }

    @Test("Long durations use calendar years, months, and days")
    func thousandDays() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let target = calendar.date(from: DateComponents(year: 2029, month: 4, day: 28))!
        let duration = CountdownDuration.between(start, and: target, calendar: calendar)

        #expect(duration.totalDays == 1000)
        #expect(duration.years == 2)
        #expect(duration.months == 8)
        #expect(duration.days == 26)
        #expect(duration.compactText == "2 years 8 months 26 days")
    }

    @Test("Leap day is handled by calendar arithmetic")
    func leapYear() {
        let start = calendar.date(from: DateComponents(year: 2024, month: 2, day: 28))!
        let target = calendar.date(from: DateComponents(year: 2024, month: 3, day: 1))!
        let duration = CountdownDuration.between(start, and: target, calendar: calendar)

        #expect(duration.totalDays == 2)
        #expect(duration.compactText == "2 days")
    }

    @Test("Overdue durations are symmetric")
    func overdue() {
        let target = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2))!
        let current = calendar.date(byAdding: .day, value: 9, to: target)!
        let duration = CountdownDuration.between(current, and: target, calendar: calendar)

        #expect(duration.isOverdue)
        #expect(duration.totalDays == 9)
        #expect(duration.compactText == "1 week 2 days")
        #expect(duration.accessibilityText == "1 week 2 days overdue")
        #expect(duration.progressDisplay == .init(value: 0, label: "days remaining"))
    }

    @Test("Progress display rounds to one readable remaining-time unit")
    func progressDisplay() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!

        let days = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 5, to: start)!, calendar: calendar)
        let weekBoundary = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 7, to: start)!, calendar: calendar)
        let oneWeek = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 8, to: start)!, calendar: calendar)
        let twoWeeks = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 11, to: start)!, calendar: calendar)
        let monthBoundary = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 30, to: start)!, calendar: calendar)
        let month = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 31, to: start)!, calendar: calendar)
        let twoMonths = CountdownDuration.between(start, and: calendar.date(byAdding: .day, value: 45, to: start)!, calendar: calendar)

        #expect(days.progressDisplay == .init(value: 5, label: "days remaining"))
        #expect(weekBoundary.progressDisplay == .init(value: 1, label: "week remaining"))
        #expect(oneWeek.progressDisplay == .init(value: 1, label: "week remaining"))
        #expect(twoWeeks.progressDisplay == .init(value: 2, label: "weeks remaining"))
        #expect(monthBoundary.progressDisplay == .init(value: 1, label: "month remaining"))
        #expect(month.progressDisplay == .init(value: 1, label: "month remaining"))
        #expect(twoMonths.progressDisplay == .init(value: 2, label: "months remaining"))
    }

    @Test("Time of day does not change the day count")
    func ignoresTimeOfDay() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 2, hour: 1))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 8, day: 3, hour: 23))!
        let duration = CountdownDuration.between(morning, and: evening, calendar: calendar)

        #expect(duration.totalDays == 1)
        #expect(duration.compactText == "1 day")
    }
}
