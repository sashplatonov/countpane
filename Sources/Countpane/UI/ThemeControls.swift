import SwiftUI

struct ThemePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(theme.accent.opacity(!isEnabled ? 0.35 : (configuration.isPressed ? 0.78 : 1.0)))
            )
            .shadow(color: theme.accent.opacity(configuration.isPressed ? 0.08 : 0.22), radius: 8, y: 3)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.72)
            .contentShape(Rectangle())
            .focusEffectDisabled()
            .focusable(false)
    }
}

struct ThemeSecondaryButtonStyle: ButtonStyle {
    let theme: AppTheme
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? theme.accent : .primary)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? theme.accent.opacity(0.14) : theme.surface.opacity(configuration.isPressed ? 0.72 : 0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? theme.accent.opacity(0.58) : theme.border, lineWidth: selected ? 1.4 : 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .contentShape(Rectangle())
            .focusEffectDisabled()
            .focusable(false)
    }
}

struct ThemeIconButtonStyle: ButtonStyle {
    let theme: AppTheme
    var selected = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(selected ? .white : theme.accent)
            .frame(width: 38, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? theme.accent : theme.surface.opacity(configuration.isPressed ? 0.72 : 0.92))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? .clear : theme.border, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Rectangle())
            .focusEffectDisabled()
            .focusable(false)
    }
}

struct ThemeFieldBackground: ViewModifier {
    let theme: AppTheme
    var minHeight: CGFloat = 38

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .padding(.horizontal, 12)
            .frame(minHeight: minHeight)
            .background(theme.surface.opacity(0.94), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
            .focusEffectDisabled()
    }
}

extension View {
    func themedField(_ theme: AppTheme, minHeight: CGFloat = 38) -> some View {
        modifier(ThemeFieldBackground(theme: theme, minHeight: minHeight))
    }
}

struct ThemeSwitch: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    let theme: AppTheme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .frame(width: 17)
                Text(title)
                Spacer(minLength: 8)
                Capsule()
                    .fill(isOn ? theme.accent : Color.secondary.opacity(0.24))
                    .frame(width: 38, height: 22)
                    .overlay(alignment: isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .frame(width: 18, height: 18)
                            .shadow(color: .black.opacity(0.16), radius: 2, y: 1)
                            .padding(2)
                    }
            }
        }
        .buttonStyle(ThemeSecondaryButtonStyle(theme: theme, selected: isOn))
        .countpaneNoFocusRing()
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

struct ThemeControlLabel: View {
    let title: String
    let systemImage: String
    let theme: AppTheme

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 13)
            .frame(minHeight: 36)
            .background(theme.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .focusEffectDisabled()
            .focusable(false)
    }
}


struct SidebarButtonStyle: ButtonStyle {
    let theme: AppTheme
    let selected: Bool
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: selected ? .semibold : .medium))
            .foregroundStyle(prominent ? theme.accent : (selected ? Color.primary : Color.secondary))
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? theme.accent.opacity(0.20) : configuration.isPressed ? Color.primary.opacity(0.05) : .clear)
            )
            .overlay(alignment: .leading) {
                if selected {
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: 3, height: 24)
                        .padding(.leading, 4)
                }
            }
            .focusEffectDisabled()
            .focusable(false)
    }
}

extension View {
    /// Removes the native rectangular macOS focus halo from Countpane's mouse-first custom controls.
    func countpaneNoFocusRing() -> some View {
        self
            .focusEffectDisabled()
            .focusable(false)
    }
}
