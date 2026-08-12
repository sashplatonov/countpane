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
                .stroke(.primary.opacity(0.55), lineWidth: 1.35)

            Circle()
                .trim(from: 0.02, to: 0.78)
                .stroke(
                    .primary,
                    style: StrokeStyle(lineWidth: 2.15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("9")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .frame(width: 15, height: 15)
        .frame(width: Self.size, height: Self.size)
        .accessibilityLabel("Countpane")
    }
}
