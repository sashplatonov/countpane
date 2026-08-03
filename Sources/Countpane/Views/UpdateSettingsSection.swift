import SwiftUI

@MainActor
struct UpdateSettingsSection: View {
    @Bindable var controller: UpdateController
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(theme.accent.opacity(0.12))
                    Image(systemName: updateIcon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .symbolEffect(.rotate, options: .repeating, isActive: controller.isBusy)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.statusTitle)
                        .font(.system(size: 14.5, weight: .semibold))
                    if let detail = controller.statusDetail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    } else {
                        Text(controller.automaticChecksEnabled
                             ? "Checks run at launch and every six hours while Countpane is open."
                             : "Use Check for Updates whenever you want to contact GitHub Releases.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 12)

                Button(controller.primaryButtonTitle) {
                    controller.performPrimaryAction()
                }
                .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
                .disabled(controller.isBusy)
                .accessibilityLabel(controller.primaryButtonTitle)
            }

            Divider().opacity(0.5)

            ThemeSwitch(
                title: "Automatically check for updates",
                systemImage: "network",
                isOn: Binding(
                    get: { controller.automaticChecksEnabled },
                    set: { controller.setAutomaticChecksEnabled($0) }
                ),
                theme: theme
            )

            Text("Checks use the public GitHub Releases API. No countdown titles, dates, notes, or other personal data are sent.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
    }

    private var updateIcon: String {
        switch controller.status {
        case .available: "arrow.down.circle.fill"
        case .installed: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .checking, .installing: "arrow.triangle.2.circlepath"
        default: "checkmark.shield"
        }
    }
}
