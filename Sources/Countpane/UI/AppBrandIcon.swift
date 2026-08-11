import SwiftUI

struct AppBrandIcon: View {
    var size: CGFloat

    private var image: NSImage? {
        AppIconResource.image
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(.quaternary)
                    .overlay { Image(systemName: "calendar") }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct MenuBarAppIcon: View {
    static let size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.32), lineWidth: 1.15)

            Circle()
                .trim(from: 0.04, to: 0.78)
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: 1.6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("9")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityLabel("Countpane")
    }
}
