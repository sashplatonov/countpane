import AppKit
import SwiftUI

struct ActiveView: View {
    @Environment(AppModel.self) private var model
    @AppStorage("displayDensity") private var displayDensity = DisplayDensity.compactRow.rawValue
    @AppStorage("appTheme") private var appTheme = AppTheme.ink.rawValue
    let now: Date
    let filter: CountdownFilter
    let items: [CountdownItem]
    let nextItemID: UUID?
    let onEdit: (CountdownItem) -> Void
    let onNew: () -> Void

    private var density: DisplayDensity { DisplayDensity(rawValue: displayDensity) ?? .compactRow }
    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .ink }
    private var columns: [GridItem] {
        switch density {
        case .compactRow:
            [GridItem(.flexible(), spacing: 10)]
        case .cardGrid:
            [GridItem(.adaptive(minimum: 285, maximum: 420), spacing: 14)]
        }
    }

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView {
                Label(
                    "No Countdowns Here",
                    systemImage: filter == .all ? "hourglass" : "line.3.horizontal.decrease.circle"
                )
            } description: {
                Text(filter == .all ? "Create a countdown for an upcoming event." : "No active countdowns match this view.")
            } actions: {
                if filter == .all {
                    Button("New Countdown", action: onNew)
                        .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
                        .countpaneNoFocusRing()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else {
            LazyVGrid(columns: columns, spacing: density == .compactRow ? 10 : 14) {
                ForEach(items) { item in
                    CountdownCard(
                        item: item,
                        now: now,
                        density: density,
                        isNext: nextItemID == item.id,
                        onEdit: { onEdit(item) }
                    )
                }
            }
            .padding(.top, 2)
        }
    }
}

struct CountdownCard: View {
    @Environment(AppModel.self) private var model
    @State private var isHovering = false
    @AppStorage("appTheme") private var appTheme = AppTheme.ink.rawValue

    let item: CountdownItem
    let now: Date
    let density: DisplayDensity
    let isNext: Bool
    let onEdit: () -> Void

    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .ink }
    private var urgency: CountdownUrgency { item.urgency(from: now) }
    private var duration: CountdownDuration { item.remainingDuration(from: now) }
    private var progress: Double? { item.progress(at: now) }
    private var progressAccessibilityValue: String {
        CountdownPerimeterProgressValue(progress).accessibilityValue ?? ""
    }
    private var pulseInterval: TimeInterval? {
        guard item.attentionEnabled else { return nil }
        return urgency.pulseInterval
    }

    var body: some View {
        Group {
            switch density {
            case .compactRow: compactRow
            case .cardGrid: gridCard
            }
        }
        .background(cardBackground)
        .clipShape(.rect(cornerRadius: density == .compactRow ? 15 : 18))
        .overlay {
            CountdownPerimeterProgress(
                progress: progress,
                theme: item.theme,
                cornerRadius: density == .compactRow ? 15 : 18,
                lineWidth: 2
            )
        }
        .overlay { cardBorder }
        .shadow(color: .black.opacity(isHovering ? 0.24 : 0.14), radius: isHovering ? 18 : 10, y: isHovering ? 9 : 5)
        .gentlePulse(every: pulseInterval)
        .offset(y: isHovering ? -1 : 0)
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(duration.accessibilityText), \(urgency.rawValue)")
        .accessibilityValue(progressAccessibilityValue)
        .contextMenu { cardActions }
    }

    private var compactRow: some View {
        HStack(spacing: 18) {
            symbolTile(size: 72)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(item.theme.accent)
                    }
                }

                Text(item.targetDate.formatted(date: .long, time: .omitted))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 20)

            urgencyPill
                .frame(minWidth: 92)

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(duration.totalDays)")
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(duration.totalDays == 1 ? "day" : "days")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 74, alignment: .trailing)

            Button(action: onEdit) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 48)
            }
            .buttonStyle(.plain)
            .countpaneNoFocusRing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, minHeight: 118)
        .contentShape(.rect)
        .onTapGesture(perform: onEdit)
    }

    private var gridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                symbolTile(size: 58)
                Spacer()
                Menu { cardActions } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .menuStyle(.borderlessButton)
                .countpaneNoFocusRing()
            }

            Text(item.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .lineLimit(2)

            Text(item.targetDate.formatted(date: .long, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(duration.totalDays)")
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(duration.totalDays == 1 ? "day remaining" : "days remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                urgencyPill
            }

            HStack {
                if item.isWidgetVisible {
                    Label("Widget", systemImage: "rectangle.on.rectangle")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(item.theme.accent)
                }
                Spacer()
                Button("Edit", action: onEdit)
                    .buttonStyle(ThemeSecondaryButtonStyle(theme: theme))
                    .countpaneNoFocusRing()
                Button("Complete") { model.complete(item) }
                    .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
                    .countpaneNoFocusRing()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
    }

    private func symbolTile(size: CGFloat) -> some View {
        Image(systemName: item.symbol)
            .font(.system(size: size * 0.34, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [item.theme.accent.opacity(0.92), item.theme.accent.opacity(0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            )
            .shadow(color: item.theme.accent.opacity(0.24), radius: 8, y: 5)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: density == .compactRow ? 15 : 18, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            .overlay(item.theme.accent.opacity(isNext ? 0.035 : 0))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: density == .compactRow ? 15 : 18, style: .continuous)
            .stroke(
                isNext ? item.theme.accent.opacity(0.85) : Color(nsColor: .separatorColor).opacity(0.24),
                lineWidth: isNext ? 1.4 : 1
            )
    }

    private var urgencyPill: some View {
        Text(duration.totalDays == 0 ? "Today" : "\(duration.totalDays) days")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(pillForeground)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(pillBackground, in: Capsule())
    }

    private var statusText: String {
        if duration.totalDays == 0 { return "Today" }
        if duration.isOverdue { return "Overdue" }
        if duration.totalDays <= 7 {
            let weekday = item.targetDate.formatted(.dateTime.weekday(.wide))
            return "This \(weekday)"
        }
        return "In \(duration.totalDays) days"
    }

    private var statusColor: Color {
        if duration.isOverdue { return .red }
        if duration.totalDays <= 7 { return .green }
        return .blue
    }

    private var pillBackground: Color {
        switch urgency {
        case .overdue: .red.opacity(0.18)
        case .almost: .pink.opacity(0.19)
        case .hurry: .orange.opacity(0.18)
        case .soon: .blue.opacity(0.17)
        case .normal: item.theme.accent.opacity(0.14)
        }
    }

    private var pillForeground: Color {
        switch urgency {
        case .overdue: .red
        case .almost: .pink
        case .hurry: .orange
        case .soon: .blue
        case .normal: item.theme.accent
        }
    }

    @ViewBuilder private var cardActions: some View {
        Button(item.isWidgetVisible ? "Hide Desktop Widget" : "Show Desktop Widget", systemImage: item.isWidgetVisible ? "rectangle.slash" : "rectangle.on.rectangle") {
            model.setWidgetVisible(item, !item.isWidgetVisible)
        }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") { model.togglePinned(item) }
        Button("Copy Countdown", systemImage: "doc.on.doc") { copyToPasteboard(item.shareText(from: now)) }
        Menu("Move Date", systemImage: "calendar.badge.plus") {
            ForEach(CountdownDateShift.allCases) { shift in
                Button("Move by \(shift.rawValue)") { model.shiftDate(of: item, by: shift) }
            }
        }
        Button("Edit", systemImage: "pencil", action: onEdit)
        Button("Mark Completed", systemImage: "checkmark.circle") { model.complete(item) }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(item) }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
