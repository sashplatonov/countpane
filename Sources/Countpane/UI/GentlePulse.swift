import SwiftUI

private struct GentlePulseSchedule: Hashable {
    let interval: TimeInterval?
    let reduceMotion: Bool
}

private struct GentlePulse: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    let interval: TimeInterval?

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.005 : 1)
            .task(id: GentlePulseSchedule(interval: interval, reduceMotion: reduceMotion)) {
                guard let interval, !reduceMotion else {
                    isPulsing = false
                    return
                }

                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 1.6)) { isPulsing = true }
                    do { try await Task.sleep(for: .seconds(1.6)) } catch { return }
                    withAnimation(.easeInOut(duration: 1.6)) { isPulsing = false }
                    do { try await Task.sleep(for: .seconds(max(0, interval - 1.6))) } catch { return }
                }
            }
    }
}

extension View {
    func gentlePulse(every interval: TimeInterval?) -> some View {
        modifier(GentlePulse(interval: interval))
    }
}
