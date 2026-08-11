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

struct CountdownPerimeterProgress: View {
    let progress: Double?
    let theme: CountdownTheme
    var cornerRadius: CGFloat = 18
    var lineWidth: CGFloat = 2.5

    private var value: CountdownPerimeterProgressValue {
        CountdownPerimeterProgressValue(progress)
    }

    private var contourInset: CGFloat {
        lineWidth / 2 + 1
    }

    private var contourRadius: CGFloat {
        max(0, cornerRadius - contourInset)
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    private var trackStyle: StrokeStyle {
        StrokeStyle(lineWidth: max(1, lineWidth * 0.55), lineCap: .round, lineJoin: .round)
    }

    var body: some View {
        if value.normalized != nil {
            ZStack {
                contour
                    .stroke(theme.accent.opacity(0.42), style: trackStyle)

                if value.showsActiveSegment, let normalized = value.normalized {
                    contour
                        .trim(from: 0, to: normalized)
                        .stroke(theme.gradient, style: strokeStyle)
                        .rotationEffect(.degrees(-90))
                }

                Circle()
                    .fill(theme.accent)
                    .frame(width: lineWidth * 1.8, height: lineWidth * 1.8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, lineWidth / 2)
            }
            .padding(contourInset)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private var contour: RoundedRectangle {
        RoundedRectangle(cornerRadius: contourRadius, style: .continuous)
    }
}
