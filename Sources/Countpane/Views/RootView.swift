import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage("appTheme") private var appTheme = AppTheme.ink.rawValue
    @AppStorage("displayDensity") private var displayDensity = DisplayDensity.compactRow.rawValue
    @State private var selection: AppSection = .active
    @State private var filter: CountdownFilter = .all
    @State private var editorItem: CountdownItem?
    @State private var showEditor = false
    @State private var updateController = UpdateController.shared

    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .ink }
    private var density: DisplayDensity { DisplayDensity(rawValue: displayDensity) ?? .compactRow }

    var body: some View {
        @Bindable var model = model

        TimelineView(.periodic(from: .now, by: 3600)) { context in
            let snapshot = model.dashboardSnapshot(
                at: context.date,
                filter: filter,
                includesCompletedItems: selection == .completed
            )
            HStack(spacing: 0) {
                sidebar(snapshot: snapshot)
                Divider().opacity(0.35)
                mainContent(now: context.date, snapshot: snapshot)
            }
            .background(theme.canvas)
        }
        .frame(minWidth: 980, minHeight: 650)
        .background(WindowConfigurator())
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .safeAreaInset(edge: .bottom) { undoBar }
        .animation(.snappy, value: model.undoNotice)
        .sheet(isPresented: $showEditor, onDismiss: { editorItem = nil }) {
            CountdownEditor(item: editorItem) { saved in
                if editorItem == nil { model.add(saved) } else { model.update(saved) }
                showEditor = false
            }
        }
        .task {
            await model.load()
            applyStartupPresentation()
        }
        .onChange(of: widgetIDs) { _, _ in openVisibleWidgets() }
        .focusedSceneValue(\.newCountdownAction, newCountdown)
        .focusedSceneValue(\.showSettingsAction, { selection = .settings })
        .alert(
            "Couldn’t Save Data",
            isPresented: Binding(
                get: { model.persistenceError != nil },
                set: { if !$0 { model.persistenceError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { model.persistenceError = nil }
        } message: {
            Text(model.persistenceError ?? "Unknown error")
        }
    }

    private func sidebar(snapshot: DashboardSnapshot) -> some View {
        DashboardSidebarView(
            selection: $selection,
            filter: $filter,
            activeCount: snapshot.activeCount,
            pinnedCount: snapshot.pinnedCount,
            todayCount: snapshot.todayCount,
            weekCount: snapshot.weekCount,
            updateAvailable: {
                if case .available = updateController.status { return true }
                return false
            }(),
            theme: theme,
            onNew: newCountdown
        )
    }

    @ViewBuilder
    private func mainContent(now: Date, snapshot: DashboardSnapshot) -> some View {
        VStack(spacing: 0) {
            if selection == .settings {
                HStack {
                    Text("Settings")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 28)
                .frame(height: 66)
                .background(.ultraThinMaterial.opacity(0.55))
                SettingsView()
            } else {
                topTabs(now: now)
                ScrollView {
                    VStack(spacing: 20) {
                        dashboardHeader(now: now, snapshot: snapshot)
                        controlBar

                        Group {
                            switch selection {
                            case .active:
                                ActiveView(
                                    now: now,
                                    filter: filter,
                                    items: snapshot.filteredActiveItems,
                                    nextItemID: snapshot.nextItem?.id,
                                    onEdit: edit,
                                    onNew: newCountdown
                                )
                            case .completed:
                                CompletedView(items: snapshot.completedItems)
                            case .settings:
                                EmptyView()
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if selection == .active {
                            Text("\(snapshot.activeCount) active countdowns")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func topTabs(now: Date) -> some View {
        HStack(spacing: 70) {
            topTab(.active, title: "Active", icon: "calendar.badge.clock")
            topTab(.completed, title: "Completed", icon: "checkmark.circle")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(.ultraThinMaterial.opacity(0.55))
        .overlay(alignment: .bottom) { Divider().opacity(0.32) }
    }

    private func topTab(_ section: AppSection, title: String, icon: String) -> some View {
        Button { selection = section } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 220, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(selection == section ? theme.accent.opacity(0.18) : .clear)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(selection == section ? theme.accent.opacity(0.52) : .clear, lineWidth: 1)
                }
                .foregroundStyle(selection == section ? theme.accent : .secondary)
        }
        .buttonStyle(.plain)
        .countpaneNoFocusRing()
    }

    private func dashboardHeader(now: Date, snapshot: DashboardSnapshot) -> some View {
        let count = selection == .active ? snapshot.activeCount : snapshot.completedItems.count
        let next = snapshot.nextItem

        return HStack(spacing: 24) {
            dashboardSummary(now: now, next: next)
            Spacer(minLength: 18)
            CircularCount(count: count, label: selection == .active ? "Active" : "Done", accent: theme.accent, foreground: theme.heroForeground)
                .frame(width: 112, height: 112)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(theme.heroGradient(for: selection))
                .overlay(alignment: .trailing) {
                    HeaderLandscape(accent: theme.heroForeground).frame(width: 520).clipped().opacity(theme.colorScheme == .dark ? 0.82 : 0.46)
                }
        }
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(theme.heroBorder, lineWidth: 1) }
        .shadow(color: theme.heroShadow, radius: 18, y: 10)
        .padding(.top, 20)
    }

    @ViewBuilder
    private func dashboardSummary(now: Date, next: CountdownItem?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(selection == .active ? "Next Up" : "History")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.heroForeground.opacity(0.82))

            if let next, selection == .active {
                Text(next.title)
                    .font(.system(size: 30, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.heroForeground)
                    .lineLimit(1)
                Text(next.remainingDuration(from: now).compactText)
                    .font(.system(size: 29, weight: .regular, design: .rounded))
                    .foregroundStyle(theme.heroForeground)
                Text(next.targetDate.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(theme.heroForeground.opacity(0.72))
            } else {
                Text(selection == .active ? "Nothing urgent right now" : "Completed countdowns")
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.heroForeground)
                Text(selection == .active ? "Create a countdown for something worth anticipating." : "Restore or remove completed entries at any time.")
                    .foregroundStyle(theme.heroForeground.opacity(0.70))
            }
        }
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            searchField

            ModernSortPicker(
                selection: Binding(
                    get: { model.sortMode },
                    set: { model.sortMode = $0 }
                ),
                theme: theme
            )

            Button {
                model.searchText = ""
                model.sortMode = .date
                filter = .all
            } label: {
                ThemeControlLabel(title: "Reset View", systemImage: "arrow.counterclockwise", theme: theme)
            }
            .buttonStyle(.plain)
            .countpaneNoFocusRing()

            Spacer()

            HStack(spacing: 4) {
                displayModeButton(.cardGrid, icon: "square.grid.2x2")
                displayModeButton(.compactRow, icon: "list.bullet")
            }
            .padding(3)
            .background(theme.surface.opacity(0.72), in: RoundedRectangle(cornerRadius: 11))
            .overlay { RoundedRectangle(cornerRadius: 11).stroke(theme.border, lineWidth: 1) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search countdowns…", text: Binding(get: { model.searchText }, set: { model.searchText = $0 }))
                .textFieldStyle(.plain)
            if !model.searchText.isEmpty {
                Button { model.searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain)
                    .countpaneNoFocusRing()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(width: 275, height: 42)
        .background(theme.surface.opacity(0.74), in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(theme.border, lineWidth: 1) }
    }

    private func displayModeButton(_ mode: DisplayDensity, icon: String) -> some View {
        Button { displayDensity = mode.rawValue } label: {
            Image(systemName: icon).frame(width: 34, height: 32)
        }
        .buttonStyle(ThemeIconButtonStyle(theme: theme, selected: density == mode))
        .countpaneNoFocusRing()
    }

    @ViewBuilder
    private var undoBar: some View {
        if let notice = model.undoNotice {
            HStack(spacing: 14) {
                Image(systemName: notice.kind == .completed ? "checkmark.circle.fill" : "trash.fill")
                Text(notice.message).lineLimit(1)
                Spacer()
                Button("Undo") { model.undoLastAction() }.keyboardShortcut("z", modifiers: .command)
                Button { model.dismissUndo() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain)
        .countpaneNoFocusRing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 10, y: 4)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var widgetIDs: [UUID] {
        model.visibleWidgetItems.map(\.id).sorted { $0.uuidString < $1.uuidString }
    }

    private func openVisibleWidgets() {
        for id in widgetIDs { openWindow(id: "widget", value: id) }
    }

    private func applyStartupPresentation() {
        openVisibleWidgets()
        if LaunchSession.shared.shouldDismissMainWindowForStartup() {
            DispatchQueue.main.async { dismissWindow(id: "main") }
        }
    }

    private func newCountdown() {
        editorItem = nil
        showEditor = true
    }

    private func edit(_ item: CountdownItem) {
        editorItem = item
        showEditor = true
    }
}

private struct HeaderLandscape: View {
    let accent: Color
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                Circle().fill(Color.pink.opacity(0.46)).frame(width: 108, height: 108).offset(x: proxy.size.width * 0.08, y: -24)
                Capsule().fill(accent.opacity(0.10)).frame(width: proxy.size.width * 0.88, height: proxy.size.height * 0.48).offset(x: 18, y: 20).rotationEffect(.degrees(-5))
                Capsule().fill(Color.indigo.opacity(0.38)).frame(width: proxy.size.width * 0.78, height: proxy.size.height * 0.34).offset(x: 55, y: 34).rotationEffect(.degrees(4))
                Capsule().fill(Color.blue.opacity(0.42)).frame(width: proxy.size.width * 0.72, height: proxy.size.height * 0.27).offset(x: 76, y: 45).rotationEffect(.degrees(-2))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CircularCount: View {
    let count: Int
    let label: String
    let accent: Color
    let foreground: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.13), lineWidth: 9)
            Circle()
                .trim(from: 0, to: max(0.12, min(Double(count) / 8.0, 1)))
                .stroke(
                    AngularGradient(colors: [.pink, accent, .cyan], center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(count)").font(.system(size: 31, weight: .medium, design: .rounded)).monospacedDigit()
                Text(label).font(.subheadline)
            }
            .foregroundStyle(foreground)
        }
    }
}


private struct ModernSortPicker: View {
    @Binding var selection: SortMode
    let theme: AppTheme
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "arrow.up.arrow.down")
                    .foregroundStyle(theme.accent)
                Text("Sort")
                    .foregroundStyle(.secondary)
                Text(selection.rawValue)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(theme.surface.opacity(0.82), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(isPresented ? theme.accent.opacity(0.65) : theme.border, lineWidth: isPresented ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .countpaneNoFocusRing()
        .popover(isPresented: $isPresented, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sort countdowns")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 5)

                ForEach(SortMode.allCases) { option in
                    Button {
                        selection = option
                        isPresented = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: option == selection ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(option == selection ? theme.accent : Color.secondary.opacity(0.45))
                            Text(option.rawValue)
                                .font(.system(size: 13.5, weight: option == selection ? .semibold : .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 11)
                        .frame(width: 210, height: 38)
                        .background(
                            option == selection ? theme.accent.opacity(0.12) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .countpaneNoFocusRing()
                }
            }
            .padding(8)
            .background(theme.canvas)
            .preferredColorScheme(theme.colorScheme)
        }
    }
}
