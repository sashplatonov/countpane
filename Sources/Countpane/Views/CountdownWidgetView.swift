import AppKit
import SwiftUI

struct CountdownWidgetView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismissWindow) private var dismissWindow
    let id: UUID

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3600)) { context in
            if let item = model.item(id: id), !item.isCompleted, item.isWidgetVisible {
                widget(item, now: context.date)
                    .frame(width: 270, height: 160)
                    .background(
                        WidgetWindowConfigurator(
                            id: item.id,
                            size: CGSize(width: 270, height: 160)
                        )
                    )
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .task { dismissWindow(id: "widget", value: id) }
            }
        }
    }

    private func widget(_ item: CountdownItem, now: Date) -> some View {
        let duration = item.remainingDuration(from: now)
        let urgency = item.urgency(from: now)

        return ZStack {
            item.theme.gradient

            Circle()
                .fill(item.theme.accent.opacity(0.14))
                .frame(width: 150, height: 150)
                .offset(x: 112, y: -65)

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 9) {
                    Image(systemName: item.symbol)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(item.theme.accent)
                        .frame(width: 34, height: 34)
                        .background(.ultraThinMaterial, in: Circle())

                    Text(item.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button {
                        model.setWidgetVisible(item, false)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .frame(width: 26, height: 26)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
        .countpaneNoFocusRing()
                    .help("Hide desktop widget")
                }

                Spacer(minLength: 0)

                Text(duration.compactText)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.62)
                    .lineLimit(1)
                    .contentTransition(.numericText())

                HStack {
                    Label(urgency.rawValue, systemImage: urgency.icon)
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(item.theme.accent.opacity(0.18 + urgency.emphasis), in: Capsule())
                    Spacer()
                    Text(item.targetDate, format: .dateTime.day().month(.abbreviated))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.theme.secondary)
                }
            }
            .foregroundStyle(item.theme.foreground)
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(item.theme.isDark ? 0.12 : 0.34), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(duration.accessibilityText)")
    }
}

struct WidgetWindowConfigurator: NSViewRepresentable {
    let id: UUID
    let size: CGSize

    func makeNSView(context: Context) -> WindowObservationView {
        let view = WindowObservationView()
        view.onWindowChange = configure
        return view
    }

    func updateNSView(_ view: WindowObservationView, context: Context) {
        view.onWindowChange = configure
        if let window = view.window { configure(window) }
    }

    private func configure(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.setContentSize(size)
        window.setFrameAutosaveName("CountpaneWidget-\(id.uuidString)")
    }
}
