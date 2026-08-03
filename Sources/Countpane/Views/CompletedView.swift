import AppKit
import SwiftUI

struct CompletedView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.ink.rawValue
    @Environment(AppModel.self) private var model
    let items: [CountdownItem]
    private var theme: AppTheme { AppTheme(rawValue: appTheme) ?? .ink }

    var body: some View {
        ScrollView {
            if items.isEmpty {
                ContentUnavailableView(
                    "No Completed Countpane",
                    systemImage: "checkmark.circle",
                    description: Text("Finished countdowns will appear here.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { item in
                        completedRow(item)
                    }
                }
                .padding(14)
            }
        }
    }

    private func completedRow(_ item: CountdownItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(item.theme.accent)
                .frame(width: 46, height: 46)
                .background(item.theme.gradient, in: .rect(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.targetDate.formatted(date: .long, time: .omitted))
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                if let date = item.completedAt {
                    Text("Completed \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            Button("Restore") { model.restore(item) }
                .buttonStyle(ThemeSecondaryButtonStyle(theme: theme))
                .countpaneNoFocusRing()
            Menu {
                Button("Copy Countdown", systemImage: "doc.on.doc") {
                    copyToPasteboard(item.shareText())
                }
                Divider()
                Button("Delete", systemImage: "trash", role: .destructive) {
                    model.delete(item)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .countpaneNoFocusRing()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        }
        .contextMenu {
            Button("Restore", systemImage: "arrow.uturn.backward") { model.restore(item) }
            Button("Copy Countdown", systemImage: "doc.on.doc") { copyToPasteboard(item.shareText()) }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) { model.delete(item) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title), completed countdown")
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
