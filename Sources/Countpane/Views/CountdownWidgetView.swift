import SwiftUI

struct CountdownWidgetView: View {
    @Environment(AppModel.self) private var model
    @State private var isCompletionConfirmationPresented = false
    let id: UUID

    static let contentSize = CGSize(width: 270, height: 160)
    static let closeButtonHitSize: CGFloat = 44

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3600)) { context in
            if let item = model.item(id: id), !item.isCompleted, item.isWidgetVisible {
                widget(item, now: context.date)
                    .frame(width: Self.contentSize.width, height: Self.contentSize.height)
            } else {
                Color.clear
                    .frame(width: 1, height: 1)
                    .task { WidgetWindowController.shared.dismiss(id: id) }
            }
        }
    }

    private func widget(_ item: CountdownItem, now: Date) -> some View {
        let duration = item.remainingDuration(from: now)
        let urgency = item.urgency(from: now)
        let progress = item.progress(at: now)
        let progressDisplay = duration.progressDisplay

        return ZStack {
            item.theme.gradient
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())

            Circle()
                .fill(item.theme.accent.opacity(0.14))
                .frame(width: 150, height: 150)
                .offset(x: 112, y: -65)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: item.symbol)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(item.theme.accent)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())

                    Text(item.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.trailing, Self.closeButtonHitSize)
                .gesture(WindowDragGesture())

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    CountdownCircularProgress(
                        progress: progress,
                        theme: item.theme,
                        remainingDays: progressDisplay.value,
                        isDarkBackground: item.theme.isDark,
                        diameter: 46,
                        lineWidth: 3.5
                    )
                    Text(progressDisplay.label)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                }
                .gesture(WindowDragGesture())

                HStack {
                    Label(urgency.rawValue, systemImage: urgency.icon)
                        .font(.caption.bold())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(item.theme.accent.opacity(0.18 + urgency.emphasis), in: Capsule())
                        .gesture(WindowDragGesture())
                    Spacer()

                    Button {
                        isCompletionConfirmationPresented = true
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .countpaneNoFocusRing()
                    .help("Mark countdown completed")
                    .accessibilityLabel("Mark countdown completed")

                    Text(item.targetDate, format: .dateTime.day().month(.abbreviated))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(item.theme.secondary)
                        .gesture(WindowDragGesture())
                }
            }
            .foregroundStyle(item.theme.foreground)
            .padding(14)
            .overlay(alignment: .topTrailing) {
                Button {
                    model.setWidgetVisible(item, false)
                    WidgetWindowController.shared.dismiss(id: id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .frame(width: 26, height: 26)
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: Self.closeButtonHitSize, height: Self.closeButtonHitSize)
                }
                .buttonStyle(.plain)
                .countpaneNoFocusRing()
                .help("Hide desktop widget")
                .accessibilityLabel("Hide desktop widget")
                .accessibilityIdentifier("widget-close-\(id.uuidString)")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(item.theme.isDark ? 0.12 : 0.34), lineWidth: 1)
        }
        .gentlePulse(every: item.attentionEnabled ? urgency.pulseInterval : nil)
        .padding(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), \(duration.accessibilityText)")
        .accessibilityValue(CountdownPerimeterProgressValue(progress).accessibilityValue ?? "")
        .confirmationDialog(
            "Mark countdown completed?",
            isPresented: $isCompletionConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Mark Completed", role: .destructive) {
                model.complete(item)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(item.title) will move to Completed.")
        }
    }
}
