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

    @Test("Panel converts window clicks to top-left hosting coordinates")
    func dragCoordinates() {
        let panel = WidgetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 294, height: 184),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        let hostingView = WidgetHostingView(rootView: AnyView(Color.clear))
        panel.contentView = hostingView
        hostingView.frame = NSRect(x: 0, y: 0, width: 294, height: 184)

        #expect(hostingView.isFlipped)
        for windowPoint in [CGPoint(x: 260, y: 154), CGPoint(x: 210, y: 154)] {
            let contentPoint = hostingView.convert(windowPoint, from: nil)
            #expect(contentPoint.y == 30)
            #expect(!WidgetWindowDragRegion.shouldBeginDrag(at: contentPoint, in: hostingView.bounds.size))
        }
        let bodyPoint = hostingView.convert(CGPoint(x: 40, y: 90), from: nil)
        #expect(WidgetWindowDragRegion.shouldBeginDrag(at: bodyPoint, in: hostingView.bounds.size))
    }

    @Test("Widget content accepts the first click on an inactive panel")
    func acceptsFirstMouse() {
        let hostingView = WidgetHostingView(rootView: AnyView(Color.clear))
        #expect(hostingView.acceptsFirstMouse(for: nil))
    }

}
