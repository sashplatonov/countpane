import Foundation
import Testing
@testable import Countpane

@Suite("Quick date presets")
struct CountdownDatePresetTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    @Test("Presets use calendar arithmetic")
    func presets() {
        let base = calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        #expect(CountdownDatePreset.sevenDays.date(from: base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 2, day: 7)))
        #expect(CountdownDatePreset.thirtyDays.date(from: base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)))
        #expect(CountdownDatePreset.threeMonths.date(from: base, calendar: calendar) == calendar.date(from: DateComponents(year: 2026, month: 4, day: 30)))
        #expect(CountdownDatePreset.oneYear.date(from: base, calendar: calendar) == calendar.date(from: DateComponents(year: 2027, month: 1, day: 31)))
    }
}
