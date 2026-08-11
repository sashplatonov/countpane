import SwiftUI

struct CountdownEditor: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue
    private let originalItem: CountdownItem
    private let isNewCountdown: Bool
    @State private var draft: CountdownItem
    @State private var title: String
    @State private var showUrgencySettings = false
    @State private var showThemePicker = false
    @State private var showDatePicker = false
    @State private var showUnsavedChangesAlert = false

    let onSave: (CountdownItem) -> Void

    private let symbols = [
        "star", "airplane", "gift", "briefcase", "shippingbox",
        "heart", "graduationcap", "figure.run", "house", "calendar"
    ]

    init(item: CountdownItem?, onSave: @escaping (CountdownItem) -> Void) {
        isNewCountdown = item == nil
        let initialItem = item ?? CountdownItem(
            title: "",
            targetDate: Calendar.autoupdatingCurrent.date(byAdding: .day, value: 30, to: .now) ?? .now
        )
        originalItem = initialItem
        _draft = State(initialValue: initialItem)
        _title = State(initialValue: initialItem.title)
        self.onSave = onSave
    }

    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .system }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var thresholdsValid: Bool {
        draft.almostThreshold >= 0 &&
        draft.hurryThreshold > draft.almostThreshold &&
        draft.soonThreshold > draft.hurryThreshold
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && thresholdsValid
    }

    private var hasChanges: Bool {
        CountdownEditorDraft.hasChanges(
            original: originalItem,
            draft: draft,
            title: title
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            editorHeader

            ScrollView {
                VStack(spacing: 14) {
                    primaryCard
                    optionsCard
                    urgencyCard
                    themeCard
                }
                .padding(20)
            }

            Divider()
            actionBar
        }
        .frame(width: 640, height: 680)
        .background {
            theme.canvas.ignoresSafeArea()
            EditorWindowActivationView(onOutsideClick: requestClose)
                .frame(width: 0, height: 0)
        }
        .tint(theme.accent)
        .preferredColorScheme(theme.colorScheme)
        .interactiveDismissDisabled(hasChanges)
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save") { saveDraft() }
                .disabled(!canSave)
            Button("Don’t Save", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Do you want to save your changes before closing this countdown?")
        }
    }

    private var editorHeader: some View {
        HStack(spacing: 13) {
            Image(systemName: draft.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(draft.theme.accent)
                .frame(width: 44, height: 44)
                .background(draft.theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(trimmedTitle.isEmpty ? "New Countdown" : trimmedTitle)
                    .font(.title3.bold())
                    .lineLimit(1)
                Text("Create a focused reminder for an important date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button(action: requestClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .countpaneNoFocusRing()
            .help("Close editor")
            .accessibilityLabel("Close editor")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(theme.surface.opacity(0.90))
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }

    private var primaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 10) {
                iconMenu
                    .frame(width: 46, height: 52)
                    .fixedSize()

                ReliableTitleField(
                    text: $title,
                    placeholder: "Vacation, launch, birthday…"
                )
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 52, maxHeight: 52, alignment: .leading)
                .layoutPriority(1)
                .padding(.horizontal, 15)
                .background(theme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("Target date", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button {
                    showDatePicker.toggle()
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(draft.targetDate.formatted(.dateTime.weekday(.wide)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(draft.targetDate.formatted(.dateTime.day().month(.wide).year()))
                                .font(.headline)
                                .foregroundStyle(.primary)
                        }

                        Spacer()

                        Image(systemName: "calendar.badge.clock")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.accent)
                            .frame(width: 38, height: 38)
                            .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 64)
                    .contentShape(Rectangle())
                    .background(theme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .countpaneNoFocusRing()
                .popover(isPresented: $showDatePicker, arrowEdge: .bottom) {
                    CountpaneCalendarView(
                        selection: $draft.targetDate,
                        theme: theme,
                        onDone: { showDatePicker = false }
                    )
                }

                presetButtons
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Note")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField("Optional note", text: $draft.note, axis: .vertical)
                    .themedField(theme, minHeight: 76)
                    .lineLimit(2...4)
            }
        }
        .countdownEditorCard(theme: theme)
    }

    private var iconMenu: some View {
        Menu {
            ForEach(symbols, id: \.self) { symbol in
                Button {
                    draft.symbol = symbol
                } label: {
                    Label(symbol.capitalized, systemImage: symbol)
                }
            }
        } label: {
            Image(systemName: draft.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(draft.theme.accent)
                .frame(width: 42, height: 52)
                .background(draft.theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(draft.theme.accent.opacity(0.24), lineWidth: 1)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.caption)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, draft.theme.accent)
                        .offset(x: 4, y: 4)
                }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 46, height: 52)
        .countpaneNoFocusRing()
        .help("Choose icon")
    }

    private var optionsCard: some View {
        VStack(spacing: 12) {
            ThemeSwitch(
                title: "Gentle pulse",
                systemImage: "waveform.path",
                isOn: $draft.attentionEnabled,
                theme: theme
            )
            .help("Briefly pulses urgent countdowns at an urgency-based interval")

            Divider().opacity(0.45)

            ThemeSwitch(
                title: "Desktop widget",
                systemImage: "rectangle.on.rectangle",
                isOn: $draft.isWidgetVisible,
                theme: theme
            )
            .help("Show this countdown in its own rounded always-on-top window")
        }
        .countdownEditorCard(theme: theme)
    }

    private var urgencyCard: some View {
        DisclosureGroup(isExpanded: $showUrgencySettings) {
            VStack(spacing: 10) {
                ThresholdRow(title: "Coming Soon", icon: "sparkles", value: $draft.soonThreshold, range: 2...365)
                ThresholdRow(title: "Time to Hurry", icon: "bolt.fill", value: $draft.hurryThreshold, range: 1...180)
                ThresholdRow(title: "Almost There", icon: "flag.checkered", value: $draft.almostThreshold, range: 0...90)

                if !thresholdsValid {
                    Label("Use descending thresholds, for example 14, 7, and 3 days.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 12)
        } label: {
            Label("Urgency thresholds", systemImage: "gauge.with.dots.needle.50percent")
                .font(.headline)
        }
        .countdownEditorCard(theme: theme)
    }

    private var themeCard: some View {
        DisclosureGroup(isExpanded: $showThemePicker) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                ForEach(CountdownTheme.allCases) { countdownTheme in
                    Button {
                        draft.theme = countdownTheme
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(countdownTheme.gradient)
                                .frame(height: 48)
                                .overlay(alignment: .topTrailing) {
                                    if draft.theme == countdownTheme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.white, countdownTheme.accent)
                                            .padding(6)
                                    }
                                }
                            Text(countdownTheme.rawValue)
                                .font(.caption2.bold())
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .countpaneNoFocusRing()
                }
            }
            .padding(.top, 12)
        } label: {
            HStack {
                Label("Theme", systemImage: "paintpalette")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(draft.theme.gradient)
                    .frame(width: 20, height: 20)
                Text(draft.theme.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .countdownEditorCard(theme: theme)
    }

    private var actionBar: some View {
        HStack {
            Button("Cancel", role: .cancel) {
                requestClose()
            }
            .buttonStyle(ThemeSecondaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
            .keyboardShortcut(.cancelAction)

            Spacer()

            if trimmedTitle.isEmpty {
                Text("Enter a title to continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Save") {
                saveDraft()
            }
            .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(theme.surface.opacity(0.92))
        .overlay(alignment: .top) { Divider().opacity(0.35) }
    }

    private func requestClose() {
        guard !showUnsavedChangesAlert else { return }
        if hasChanges {
            showUnsavedChangesAlert = true
        } else {
            dismiss()
        }
    }

    private func saveDraft() {
        guard canSave else { return }
        onSave(CountdownEditorDraft.itemForSaving(
            draft,
            title: trimmedTitle,
            isNewCountdown: isNewCountdown
        ))
        dismiss()
    }

    private var presetButtons: some View {
        HStack(spacing: 8) {
            Text("Quick date")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ForEach(CountdownDatePreset.allCases) { preset in
                Button(preset.rawValue) {
                    draft.targetDate = preset.date()
                }
                .buttonStyle(ThemeSecondaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
                .controlSize(.small)
            }
        }
    }
}

enum CountdownEditorDraft {
    static func itemForSaving(
        _ draft: CountdownItem,
        title: String,
        isNewCountdown: Bool,
        now: Date = .now
    ) -> CountdownItem {
        var saved = draft
        saved.title = title
        saved.normalizeThresholds()
        if isNewCountdown, saved.createdAt == nil {
            saved.createdAt = now
        }
        return saved
    }

    static func hasChanges(
        original: CountdownItem,
        draft: CountdownItem,
        title: String
    ) -> Bool {
        draft != original || title != original.title
    }
}

private struct ThresholdRow: View {
    let title: String
    let icon: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: icon)
            Spacer()

            HStack(spacing: 4) {
                Button {
                    value = max(range.lowerBound, value - 1)
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(ThresholdAdjustButtonStyle())
        .countpaneNoFocusRing()
                .disabled(value <= range.lowerBound)
                .countpaneNoFocusRing()

                Text("\(value) days")
                    .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(width: 82)

                Button {
                    value = min(range.upperBound, value + 1)
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(ThresholdAdjustButtonStyle())
        .countpaneNoFocusRing()
                .disabled(value >= range.upperBound)
                .countpaneNoFocusRing()
            }
            .padding(4)
            .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

private extension View {
    func countdownEditorCard(theme: AppTheme) -> some View {
        self
            .padding(18)
            .background(theme.surface.opacity(0.90), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
    }
}

private struct ThresholdAdjustButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold))
            .frame(width: 30, height: 30)
            .background(Color.secondary.opacity(configuration.isPressed ? 0.18 : 0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isEnabled ? 1 : 0.35)
            .contentShape(Rectangle())
            .countpaneNoFocusRing()
    }
}
