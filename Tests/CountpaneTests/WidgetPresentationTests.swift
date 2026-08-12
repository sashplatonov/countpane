import AppKit
import SwiftUI
import Testing
@testable import Countpane

@Suite("Desktop widget presentation")
@MainActor
struct DesktopWidgetPresentationTests {
    @Test("Widget content preserves room for its perimeter")
    func contentSize() {
        #expect(CountdownWidgetView.contentSize == CGSize(width: 270, height: 160))
        #expect(CountdownWidgetView.closeButtonHitSize == 44)
    }

    @Test("New countdowns show a desktop widget by default")
    func defaults() {
        let item = CountdownItem(title: "Trip", targetDate: .now)
        #expect(item.isWidgetVisible)
    }

    @Test("Widget drags all content except button hit views")
    func dragHitTesting() {
        let content = NSView(frame: .zero)
        let text = NSView(frame: .zero)
        let button = NSButton(title: "Complete", target: nil, action: nil)
        let buttonContent = NSView(frame: .zero)

        content.addSubview(text)
        content.addSubview(button)
        button.addSubview(buttonContent)

        #expect(WidgetPanel.shouldStartDrag(from: text))
        #expect(!WidgetPanel.shouldStartDrag(from: button))
        #expect(!WidgetPanel.shouldStartDrag(from: buttonContent))
    }

    @Test("Widget content accepts the first click on an inactive panel")
    func acceptsFirstMouse() {
        let hostingView = WidgetHostingView(rootView: AnyView(Color.clear))
        #expect(hostingView.acceptsFirstMouse(for: nil))
    }

}
