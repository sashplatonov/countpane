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
        Image(nsImage: AppIconResource.menuBarImage(size: Self.size))
            .interpolation(.high)
        .frame(width: Self.size, height: Self.size)
        .accessibilityLabel("Countpane")
    }
}
