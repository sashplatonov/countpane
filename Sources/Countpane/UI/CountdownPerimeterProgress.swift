import SwiftUI

struct CountdownPerimeterProgressValue: Equatable, Sendable {
    let normalized: Double?

    init(_ progress: Double?) {
        normalized = progress.map { min(max($0, 0), 1) }
    }

    var showsActiveSegment: Bool {
        guard let normalized else { return false }
        return normalized > 0
    }

    var accessibilityValue: String? {
        normalized.map { "\(Int(($0 * 100).rounded())) percent elapsed" }
    }
}

struct CountdownCircularProgressValue: Equatable, Sendable {
    let progress: CountdownPerimeterProgressValue
    let remainingDays: Int

    init(progress: Double?, remainingDays: Int) {
        self.progress = CountdownPerimeterProgressValue(progress)
        self.remainingDays = max(0, remainingDays)
    }
}

struct CountdownCircularProgress: View {
    let progress: Double?
    let theme: CountdownTheme
    let remainingDays: Int
    var isDarkBackground = false
    var diameter: CGFloat = 36
    var lineWidth: CGFloat = 3

    private var value: CountdownPerimeterProgressValue {
        CountdownCircularProgressValue(progress: progress, remainingDays: remainingDays).progress
    }

    private var displayedDays: Int {
        CountdownCircularProgressValue(progress: progress, remainingDays: remainingDays).remainingDays
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    private var trackStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: max(1.2, lineWidth * 0.62),
            lineCap: .round,
            dash: [0.1, max(4.5, lineWidth * 2.4)]
        )
    }

    private var trackColor: Color {
        isDarkBackground ? .white.opacity(0.72) : .black.opacity(0.42)
    }

    private var progressColor: Color {
        isDarkBackground ? .white : theme.accent
    }

    private var numberColor: Color {
        isDarkBackground ? .white : theme.foreground
    }

    var body: some View {
        ZStack {
            if value.normalized != nil {
                Circle()
                    .stroke(trackColor, style: trackStyle)

                    if value.showsActiveSegment, let normalized = value.normalized {
                        Circle()
                            .trim(from: 0, to: normalized)
                            .stroke(progressColor, style: strokeStyle)
                            .rotationEffect(.degrees(-90))
                    }

            }

            Text("\(displayedDays)")
                .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(numberColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: diameter, height: diameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
