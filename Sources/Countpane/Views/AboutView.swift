import SwiftUI

struct AboutView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue
    @Environment(\.openURL) private var openURL

    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .system }



    var body: some View {
        VStack(spacing: 18) {
            AppBrandIcon(size: 92)
                .shadow(color: .black.opacity(0.12), radius: 12, y: 5)

            VStack(spacing: 5) {
                Text("Countpane")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Desktop Countdown Widgets for Mac")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Version \(AppBuildInfo.displayVersion)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            Text("Keep meaningful dates visible without opening a calendar. Countpane turns upcoming moments into calm, always-on-top desktop widgets that stay out of your way until they matter.")
                .font(.system(size: 13.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            VStack(spacing: 6) {
                Text("Created by Sash Platonov")
                    .font(.system(size: 13.5, weight: .semibold))
                Text("Native SwiftUI app for macOS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("View on GitHub") {
                openURL(URL(string: "https://github.com/sashplatonov/countpane")!)
            }
            .buttonStyle(ThemePrimaryButtonStyle(theme: theme))
        .countpaneNoFocusRing()
        }
        .padding(28)
        .frame(width: 430, height: 430)
        .background(theme.canvas)
        .preferredColorScheme(theme.colorScheme)
    }
}
