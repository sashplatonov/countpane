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
}

struct CountdownPerimeterProgress: View {
    let progress: Double?
    let theme: CountdownTheme
    var cornerRadius: CGFloat = 18
    var lineWidth: CGFloat = 2

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
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            lineJoin: .round,
            dash: [2.5, 5.5]
        )
    }

    var body: some View {
        if value.normalized != nil {
            ZStack {
                contour
                    .stroke(Color.secondary.opacity(0.20), style: trackStyle)

                if value.showsActiveSegment, let normalized = value.normalized {
                    contour
                        .trim(from: 0, to: normalized)
                        .stroke(theme.gradient, style: strokeStyle)
                        .rotationEffect(.degrees(-90))
                }
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
