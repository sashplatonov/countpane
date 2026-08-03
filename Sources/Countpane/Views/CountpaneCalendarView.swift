import SwiftUI

struct CountpaneCalendarView: View {
    @Binding var selection: Date
    let theme: AppTheme
    let onDone: () -> Void

    @State private var visibleMonth: Date
    private let calendar = Calendar.autoupdatingCurrent

    init(selection: Binding<Date>, theme: AppTheme, onDone: @escaping () -> Void) {
        _selection = selection
        self.theme = theme
        self.onDone = onDone
        let start = Calendar.autoupdatingCurrent.dateInterval(of: .month, for: selection.wrappedValue)?.start ?? selection.wrappedValue
        _visibleMonth = State(initialValue: start)
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = max(0, calendar.firstWeekday - 1)
        return Array(symbols[first...] + symbols[..<first])
    }

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: visibleMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }

        let weekday = calendar.component(.weekday, from: interval.start)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        result += dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }.map(Optional.some)
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Button { moveMonth(-1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(ThemeIconButtonStyle(theme: theme))
        .countpaneNoFocusRing()
                .help("Previous month")

                Text(monthTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)

                Button { moveMonth(1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(ThemeIconButtonStyle(theme: theme))
        .countpaneNoFocusRing()
                .help("Next month")
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 7), spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(height: 20)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayButton(date)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }

            Divider().opacity(0.45)

            HStack(spacing: 10) {
                Button("Today") {
                    selection = .now
                    visibleMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
                }
                .buttonStyle(ThemeSecondaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()

                Spacer()

                Button("Done", action: onDone)
                    .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 330)
        .background(theme.canvas)
        .preferredColorScheme(theme.colorScheme)
    }

    private func dayButton(_ date: Date) -> some View {
        let selected = calendar.isDate(date, inSameDayAs: selection)
        let today = calendar.isDateInToday(date)

        return Button {
            selection = date
        } label: {
            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 13, weight: selected ? .bold : .medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.accent)
                    } else if today {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(theme.accent.opacity(0.12))
                    }
                }
                .overlay {
                    if today && !selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.accent.opacity(0.45), lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .countpaneNoFocusRing()
    }

    private func moveMonth(_ offset: Int) {
        if let next = calendar.date(byAdding: .month, value: offset, to: visibleMonth) {
            visibleMonth = calendar.dateInterval(of: .month, for: next)?.start ?? next
        }
    }
}
