import SwiftUI

enum CountdownTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case oceanLight = "Ocean Light", peach = "Peach", midnight = "Midnight", forest = "Forest"
    case lavender = "Lavender", graphite = "Graphite", minimalLight = "Minimal Light", aurora = "Aurora"
    var id: String { rawValue }
    var isDark: Bool { [.midnight, .graphite, .aurora].contains(self) }
    var foreground: Color { isDark ? .white : Color(nsColor: .labelColor) }
    var secondary: Color { isDark ? .white.opacity(0.72) : Color(nsColor: .secondaryLabelColor) }
    var accent: Color { switch self { case .oceanLight, .minimalLight: .blue; case .peach: .orange; case .midnight, .lavender: .purple; case .forest: .green; case .graphite: .gray; case .aurora: .mint } }
    var gradient: LinearGradient {
        let colors: [Color] = switch self {
        case .oceanLight: [Color(red: 0.89, green: 0.96, blue: 1), Color(red: 0.70, green: 0.88, blue: 0.98)]
        case .peach: [Color(red: 1, green: 0.91, blue: 0.86), Color(red: 1, green: 0.76, blue: 0.67)]
        case .midnight: [Color(red: 0.07, green: 0.09, blue: 0.20), Color(red: 0.15, green: 0.12, blue: 0.34)]
        case .forest: [Color(red: 0.88, green: 0.95, blue: 0.89), Color(red: 0.60, green: 0.76, blue: 0.64)]
        case .lavender: [Color(red: 0.95, green: 0.91, blue: 1), Color(red: 0.78, green: 0.68, blue: 0.94)]
        case .graphite: [Color(red: 0.16, green: 0.17, blue: 0.20), Color(red: 0.07, green: 0.08, blue: 0.10)]
        case .minimalLight: [.white, Color(red: 0.91, green: 0.92, blue: 0.94)]
        case .aurora: [Color(red: 0.04, green: 0.11, blue: 0.23), Color(red: 0.12, green: 0.48, blue: 0.46), Color(red: 0.28, green: 0.15, blue: 0.50)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case system = "System"
    case paper = "Paper"
    case mist = "Mist"
    case sand = "Warm Sand"
    case sage = "Soft Sage"
    case dusk = "Dusk"
    case ink = "Ink"
    case plum = "Muted Plum"

    var id: Self { self }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .paper, .mist, .sand, .sage: .light
        case .dusk, .ink, .plum: .dark
        }
    }

    var accent: Color {
        switch self {
        case .system: .accentColor
        case .paper: Color(red: 0.25, green: 0.38, blue: 0.66)
        case .mist: Color(red: 0.34, green: 0.48, blue: 0.65)
        case .sand: Color(red: 0.67, green: 0.43, blue: 0.30)
        case .sage: Color(red: 0.31, green: 0.49, blue: 0.40)
        case .dusk: Color(red: 0.55, green: 0.60, blue: 0.88)
        case .ink: Color(red: 0.45, green: 0.67, blue: 0.86)
        case .plum: Color(red: 0.72, green: 0.55, blue: 0.74)
        }
    }

    var canvas: LinearGradient {
        let colors: [Color] = switch self {
        case .system:
            [Color(nsColor: .windowBackgroundColor), Color(nsColor: .underPageBackgroundColor)]
        case .paper:
            [Color(red: 0.98, green: 0.97, blue: 0.94), Color(red: 0.94, green: 0.95, blue: 0.97)]
        case .mist:
            [Color(red: 0.93, green: 0.96, blue: 0.98), Color(red: 0.88, green: 0.92, blue: 0.95)]
        case .sand:
            [Color(red: 0.98, green: 0.94, blue: 0.89), Color(red: 0.94, green: 0.89, blue: 0.83)]
        case .sage:
            [Color(red: 0.93, green: 0.96, blue: 0.92), Color(red: 0.87, green: 0.91, blue: 0.86)]
        case .dusk:
            [Color(red: 0.10, green: 0.12, blue: 0.18), Color(red: 0.15, green: 0.16, blue: 0.23)]
        case .ink:
            [Color(red: 0.07, green: 0.09, blue: 0.12), Color(red: 0.11, green: 0.14, blue: 0.18)]
        case .plum:
            [Color(red: 0.14, green: 0.11, blue: 0.16), Color(red: 0.20, green: 0.15, blue: 0.22)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var surface: Color {
        switch self {
        case .system: Color(nsColor: .controlBackgroundColor)
        case .paper: Color.white.opacity(0.78)
        case .mist: Color.white.opacity(0.66)
        case .sand: Color(red: 1.0, green: 0.98, blue: 0.94).opacity(0.82)
        case .sage: Color(red: 0.97, green: 0.99, blue: 0.96).opacity(0.80)
        case .dusk: Color(red: 0.16, green: 0.18, blue: 0.25).opacity(0.88)
        case .ink: Color(red: 0.12, green: 0.15, blue: 0.19).opacity(0.92)
        case .plum: Color(red: 0.22, green: 0.17, blue: 0.24).opacity(0.90)
        }
    }

    var border: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    func heroGradient(for section: AppSection) -> LinearGradient {
        let base: [Color]
        switch self {
        case .system:
            base = [accent.opacity(0.86), accent.opacity(0.50), surface]
        case .paper:
            base = [Color(red: 0.88, green: 0.91, blue: 0.98), Color(red: 0.76, green: 0.84, blue: 0.96), Color.white.opacity(0.78)]
        case .mist:
            base = [Color(red: 0.76, green: 0.87, blue: 0.94), Color(red: 0.67, green: 0.80, blue: 0.91), Color.white.opacity(0.55)]
        case .sand:
            base = [Color(red: 0.93, green: 0.76, blue: 0.58), Color(red: 0.84, green: 0.61, blue: 0.43), Color(red: 0.98, green: 0.89, blue: 0.76)]
        case .sage:
            base = [Color(red: 0.67, green: 0.82, blue: 0.70), Color(red: 0.48, green: 0.68, blue: 0.56), Color(red: 0.83, green: 0.91, blue: 0.82)]
        case .dusk:
            base = [Color(red: 0.29, green: 0.31, blue: 0.49), Color(red: 0.42, green: 0.39, blue: 0.64), Color(red: 0.18, green: 0.20, blue: 0.31)]
        case .ink:
            base = [Color(red: 0.14, green: 0.30, blue: 0.46), Color(red: 0.25, green: 0.49, blue: 0.66), Color(red: 0.10, green: 0.18, blue: 0.27)]
        case .plum:
            base = [Color(red: 0.35, green: 0.20, blue: 0.39), Color(red: 0.55, green: 0.34, blue: 0.57), Color(red: 0.25, green: 0.16, blue: 0.29)]
        }
        let adjusted = section == .completed ? base.map { $0.opacity(0.82) } : base
        return LinearGradient(colors: adjusted, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var heroForeground: Color {
        colorScheme == .dark ? .white : Color(red: 0.13, green: 0.16, blue: 0.22)
    }

    var heroBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.58)
    }

    var heroShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : accent.opacity(0.16)
    }
}
