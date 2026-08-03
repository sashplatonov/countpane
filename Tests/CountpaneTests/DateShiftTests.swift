import Foundation
import Testing
@testable import Countpane

@Suite("Date shifting")
struct CountdownDateShiftTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Date shifts use calendar arithmetic")
    func shifts() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        #expect(CountdownDateShift.oneDay.shifted(base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)))
        #expect(CountdownDateShift.oneWeek.shifted(base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 2, day: 7)))
        #expect(CountdownDateShift.oneMonth.shifted(base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 2, day: 28)))
    }
}
