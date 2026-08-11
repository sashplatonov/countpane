import Foundation

struct CountdownItem: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var targetDate: Date
    var createdAt: Date = .now
    var note = ""
    var symbol = "star"
    var theme: CountdownTheme = .oceanLight
    var isCompleted = false
    var completedAt: Date?
    var isPinned = false
    var soonThreshold = 14
    var hurryThreshold = 7
    var almostThreshold = 3
    var attentionEnabled = true
    var isWidgetVisible = true

    mutating func normalizeThresholds() {
        almostThreshold = max(0, almostThreshold)
        hurryThreshold = max(almostThreshold + 1, hurryThreshold)
        soonThreshold = max(hurryThreshold + 1, soonThreshold)
    }

    func daysRemaining(from date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    func urgency(from date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> CountdownUrgency {
        let days = daysRemaining(from: date, calendar: calendar)
        if days < 0 { return .overdue }
        if days <= almostThreshold { return .almost }
        if days <= hurryThreshold { return .hurry }
        if days <= soonThreshold { return .soon }
        return .normal
    }

    func remainingDuration(from date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> CountdownDuration {
        CountdownDuration.between(date, and: targetDate, calendar: calendar)
    }

    func progress(at date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Double? {
        let start = calendar.startOfDay(for: createdAt)
        let end = calendar.startOfDay(for: targetDate)
        guard end > start else { return nil }
        let current = calendar.startOfDay(for: date)
        let total = end.timeIntervalSince(start)
        let elapsed = current.timeIntervalSince(start)
        return min(max(elapsed / total, 0), 1)
    }

    func shareText(from date: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> String {
        let duration = remainingDuration(from: date, calendar: calendar)
        let status = duration.isOverdue
            ? "\(duration.compactText) overdue"
            : duration.totalDays == 0 ? "Today" : "\(duration.compactText) remaining"
        return "\(title) - \(status)\nTarget date: \(targetDate.formatted(date: .long, time: .omitted))"
    }
}

struct CountdownDuration: Equatable, Sendable {
    let isOverdue: Bool
    let totalDays: Int
    let years: Int
    let months: Int
    let weeks: Int
    let days: Int

    static func between(_ currentDate: Date, and targetDate: Date, calendar: Calendar = .autoupdatingCurrent) -> Self {
        let current = calendar.startOfDay(for: currentDate)
        let target = calendar.startOfDay(for: targetDate)
        let isOverdue = target < current
        let start = isOverdue ? target : current
        let end = isOverdue ? current : target
        let totalDays = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        if totalDays < 31 {
            return Self(isOverdue: isOverdue, totalDays: totalDays, years: 0, months: 0, weeks: totalDays / 7, days: totalDays % 7)
        }

        let components = calendar.dateComponents([.year, .month, .day], from: start, to: end)
        return Self(
            isOverdue: isOverdue,
            totalDays: totalDays,
            years: components.year ?? 0,
            months: components.month ?? 0,
            weeks: 0,
            days: components.day ?? 0
        )
    }

    var compactText: String {
        let parts: [String]
        if totalDays < 31 {
            parts = [unit(weeks, singular: "week", plural: "weeks"), unit(days, singular: "day", plural: "days")].compactMap { $0 }
        } else {
            parts = [unit(years, singular: "year", plural: "years"), unit(months, singular: "month", plural: "months"), unit(days, singular: "day", plural: "days")].compactMap { $0 }
        }
        return parts.isEmpty ? "Today" : parts.joined(separator: " ")
    }

    var accessibilityText: String {
        if totalDays == 0 { return "today" }
        return isOverdue ? "\(compactText) overdue" : "\(compactText) remaining"
    }

    private func unit(_ value: Int, singular: String, plural: String) -> String? {
        guard value > 0 else { return nil }
        return "\(value) \(value == 1 ? singular : plural)"
    }
}

enum CountdownUrgency: String, CaseIterable, Sendable {
    case normal = "On Track", soon = "Coming Soon", hurry = "Time to Hurry", almost = "Almost There", overdue = "Overdue"
    var icon: String { switch self { case .normal: "checkmark.circle"; case .soon: "sparkles"; case .hurry: "bolt.fill"; case .almost: "flag.checkered"; case .overdue: "exclamationmark.triangle.fill" } }
    var emphasis: Double { switch self { case .normal: 0; case .soon: 0.08; case .hurry: 0.16; case .almost: 0.25; case .overdue: 0.30 } }
    var pulseInterval: TimeInterval? {
        switch self {
        case .normal: nil
        case .soon: 3 * 60 * 60
        case .hurry: 90 * 60
        case .almost: 30 * 60
        case .overdue: 15 * 60
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable {
    case active = "Active"
    case completed = "Completed"
    case settings = "Settings"
    var id: Self { self }
    var icon: String {
        switch self {
        case .active: "clock"
        case .completed: "checkmark.circle"
        case .settings: "gearshape"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable { case date = "Date", title = "Title", urgency = "Urgency"; var id: Self { self } }
enum DisplayDensity: String, CaseIterable, Identifiable {
    case compactRow = "Compact Row"
    case cardGrid = "Card Grid"
    var id: Self { self }

}

enum CountdownFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All Countdowns"
    case pinned = "Pinned"
    case today = "Today"
    case week = "This Week"
    var id: Self { self }
}

enum CountdownDatePreset: String, CaseIterable, Identifiable, Sendable {
    case sevenDays = "7 days"
    case thirtyDays = "30 days"
    case threeMonths = "3 months"
    case oneYear = "1 year"

    var id: Self { self }

    func date(from base: Date = .now, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let (component, value): (Calendar.Component, Int) = switch self {
        case .sevenDays: (.day, 7)
        case .thirtyDays: (.day, 30)
        case .threeMonths: (.month, 3)
        case .oneYear: (.year, 1)
        }
        return calendar.date(byAdding: component, value: value, to: base) ?? base
    }
}


enum CountdownDateShift: String, CaseIterable, Identifiable, Sendable {
    case oneDay = "1 day"
    case oneWeek = "1 week"
    case oneMonth = "1 month"

    var id: Self { self }

    func shifted(_ date: Date, calendar: Calendar = .autoupdatingCurrent) -> Date {
        let (component, value): (Calendar.Component, Int) = switch self {
        case .oneDay: (.day, 1)
        case .oneWeek: (.weekOfYear, 1)
        case .oneMonth: (.month, 1)
        }
        return calendar.date(byAdding: component, value: value, to: date) ?? date
    }
}
