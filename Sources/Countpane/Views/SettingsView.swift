import SwiftUI

@MainActor
struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue
    @State private var loginItemController = LoginItemController()
    @State private var updateController = UpdateController.shared
    @State private var showImporter = false
    @State private var showExporter = false
    @State private var exportFile = CountpaneBackupFile()
    @State private var pendingImport: CountpaneExportDocument?
    @State private var transferError: String?
    @State private var transferNotice: String?
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    private var selectedTheme: AppTheme { AppTheme(rawValue: appTheme) ?? .system }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                settingsHeader
                loginItemRow
                updateSection
                appearanceSection
                dataSection
                valueSection
            }
            .padding(20)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .preferredColorScheme(selectedTheme.colorScheme)
        .tint(selectedTheme.accent)
        .task { loginItemController.refresh() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false,
            onCompletion: handleImportSelection
        )
        .fileExporter(
            isPresented: $showExporter,
            document: exportFile,
            contentType: .json,
            defaultFilename: exportFilename,
            onCompletion: handleExportCompletion
        )
        .alert(
            "Replace Current Countdowns?",
            isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ),
            presenting: pendingImport
        ) { document in
            Button("Cancel", role: .cancel) { pendingImport = nil }
            Button("Replace \(model.items.count) with \(document.items.count)", role: .destructive) {
                importDocument(document)
            }
        } message: { document in
            Text("This backup was exported on \(document.exportedAt.formatted(date: .abbreviated, time: .shortened)). Importing replaces the current local data. This cannot be undone.")
        }
        .alert(
            "Data Transfer Failed",
            isPresented: Binding(
                get: { transferError != nil },
                set: { if !$0 { transferError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { transferError = nil }
        } message: {
            Text(transferError ?? "Unknown error")
        }
        .alert(
            "Countpane Data",
            isPresented: Binding(
                get: { transferNotice != nil },
                set: { if !$0 { transferNotice = nil } }
            )
        ) {
            Button("OK", role: .cancel) { transferNotice = nil }
        } message: {
            Text(transferNotice ?? "")
        }
        .alert(
            "Couldn’t Change Login Item",
            isPresented: Binding(
                get: { loginItemController.errorMessage != nil },
                set: { if !$0 { loginItemController.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { loginItemController.errorMessage = nil }
        } message: {
            Text(loginItemController.errorMessage ?? "Unknown error")
        }
    }

    private var settingsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Personalize how Countpane looks and how your countdowns are arranged.")
                .foregroundStyle(.secondary)
        }
    }

    private var loginItemRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            ThemeSwitch(
                title: "Launch Countpane at Login",
                systemImage: "power",
                isOn: Binding(
                    get: { loginItemController.isEnabled },
                    set: { loginItemController.setEnabled($0) }
                ),
                theme: selectedTheme
            )
            .disabled(loginItemController.isUpdating)

            Text("Starts quietly in the background and restores your enabled desktop countdowns.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if loginItemController.requiresApproval {
                Label(
                    "Approval is required in System Settings → General → Login Items.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 4)
            }
        }
    }


    private var updateSection: some View {
        UpdateSettingsSection(controller: updateController, theme: selectedTheme)
    }

    private var appearanceSection: some View {
        settingsCard(title: "App Appearance", systemImage: "paintpalette") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        appTheme = theme.rawValue
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(theme.canvas)
                                .frame(height: 72)
                                .overlay(alignment: .bottomLeading) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(theme.surface)
                                        .frame(height: 30)
                                        .padding(8)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if theme == selectedTheme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(theme.accent)
                                            .padding(8)
                                    }
                                }
                            Text(theme.rawValue)
                                .font(.caption.bold())
                        }
                        .padding(9)
                        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(theme == selectedTheme ? theme.accent : selectedTheme.border, lineWidth: theme == selectedTheme ? 2 : 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .countpaneNoFocusRing()
                }
            }
        }
    }

    private var dataSection: some View {
        settingsCard(title: "Data", systemImage: "externaldrive") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Move your countdowns between Macs or keep a manual backup. Exported files contain only your local countdown data.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                HStack(spacing: 10) {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export JSON", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ThemePrimaryButtonStyle(theme: selectedTheme))
        .countpaneNoFocusRing()

                    Button {
                        showImporter = true
                    } label: {
                        Label("Import JSON", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ThemeSecondaryButtonStyle(theme: selectedTheme))
        .countpaneNoFocusRing()
                }

                Text("Import validates the current Countpane schema and asks before replacing existing data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var exportFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Countpane-Backup-\(formatter.string(from: .now))"
    }

    private func prepareExport() {
        do {
            exportFile = CountpaneBackupFile(data: try CountpaneJSONTransfer.encode(items: model.items))
            showExporter = true
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessGranted = url.startAccessingSecurityScopedResource()
            defer { if accessGranted { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url, options: [.mappedIfSafe])
            pendingImport = try CountpaneJSONTransfer.decode(data)
        } catch {
            transferError = error.localizedDescription
        }
    }

    private func importDocument(_ document: CountpaneExportDocument) {
        pendingImport = nil
        Task {
            do {
                try await model.replaceAll(with: document.items)
                transferNotice = "Imported \(document.items.count) countdown\(document.items.count == 1 ? "" : "s")."
            } catch {
                transferError = error.localizedDescription
            }
        }
    }

    private func handleExportCompletion(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            transferNotice = "Exported \(model.items.count) countdown\(model.items.count == 1 ? "" : "s")."
        case .failure(let error):
            if (error as NSError).code != NSUserCancelledError {
                transferError = error.localizedDescription
            }
        }
    }

    private var valueSection: some View {
        settingsCard(title: "About Countpane", systemImage: "sparkles") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Important dates should stay visible, not buried in a calendar.")
                    .font(.system(size: 16, weight: .bold, design: .rounded))

                Text("Countpane keeps upcoming trips, launches, birthdays and personal milestones in calm desktop widgets, so you always know what is getting closer without breaking your focus.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)

                HStack(spacing: 10) {
                    valueBadge("Always visible", icon: "rectangle.on.rectangle")
                    valueBadge("Private by design", icon: "lock.fill")
                    valueBadge("Native for Mac", icon: "macbook")
                }

                Divider().opacity(0.45)

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Created by Sash Platonov")
                            .font(.system(size: 13.5, weight: .semibold))
                        Text("Version \(AppBuildInfo.displayVersion)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text("An independent macOS app built with SwiftUI.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("About") { openWindow(id: "about") }
                        .buttonStyle(ThemeSecondaryButtonStyle(theme: selectedTheme))
        .countpaneNoFocusRing()
                    Button("GitHub") {
                        openURL(URL(string: "https://github.com/sashplatonov/countpane")!)
                    }
                    .buttonStyle(ThemePrimaryButtonStyle(theme: selectedTheme))
        .countpaneNoFocusRing()
                }
            }
        }
    }

    private func valueBadge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(selectedTheme.accent)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(selectedTheme.accent.opacity(0.10), in: Capsule())
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(selectedTheme.accent)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selectedTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selectedTheme.border, lineWidth: 1)
        }
    }
}
