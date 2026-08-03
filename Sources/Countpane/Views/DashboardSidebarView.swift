import SwiftUI

struct DashboardSidebarView: View {
    @Binding var selection: AppSection
    @Binding var filter: CountdownFilter
    let activeCount: Int
    let pinnedCount: Int
    let todayCount: Int
    let weekCount: Int
    let updateAvailable: Bool
    let theme: AppTheme
    let onNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                AppBrandIcon(size: 52)
                    .shadow(color: theme.accent.opacity(0.28), radius: 12, y: 6)
                Text("Countpane")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 22)
            .padding(.top, 34)
            .padding(.bottom, 36)

            VStack(spacing: 0) {
                filterButton(.all, title: "All Countdowns", icon: "list.bullet.rectangle", count: activeCount)
                filterButton(.pinned, title: "Pinned", icon: "pin", count: pinnedCount)
                filterButton(.today, title: "Today", icon: "calendar", count: todayCount)
                filterButton(.week, title: "This Week", icon: "calendar.badge.clock", count: weekCount)
            }
            .padding(.horizontal, 14)

            Spacer()

            Button {
                selection = .settings
            } label: {
                HStack(spacing: 10) {
                    Label("Settings", systemImage: "gearshape")
                    Spacer()
                    if updateAvailable {
                        Text("Update")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .background(theme.accent.opacity(0.14), in: Capsule())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(SidebarButtonStyle(theme: theme, selected: selection == .settings))
            .countpaneNoFocusRing()
            .accessibilityLabel(updateAvailable ? "Settings, update available" : "Settings")
            .padding(.horizontal, 14)

            Divider().opacity(0.35).padding(.horizontal, 18).padding(.vertical, 16)

            Button(action: onNew) {
                Label("New Countdown", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(SidebarButtonStyle(theme: theme, selected: false, prominent: true))
            .countpaneNoFocusRing()
            .keyboardShortcut("n", modifiers: [.command])
            .accessibilityLabel("New Countdown")
            .padding(.horizontal, 14)
            .padding(.bottom, 22)
        }
        .frame(width: 245)
        .background(.ultraThinMaterial.opacity(0.72))
    }

    private func filterButton(_ value: CountdownFilter, title: String, icon: String, count: Int) -> some View {
        Button {
            filter = value
            selection = .active
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 20)
                Text(title)
                Spacer()
                Text("\(count)").foregroundStyle(.secondary).monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(SidebarButtonStyle(theme: theme, selected: selection == .active && filter == value))
        .countpaneNoFocusRing()
        .accessibilityLabel("\(title), \(count)")
    }
}
