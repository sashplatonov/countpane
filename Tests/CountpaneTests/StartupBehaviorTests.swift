import Foundation
import Testing
@testable import Countpane

@Suite("Startup presentation")
struct StartupPresentationTests {
    @Test("The management window requires an explicit main-window event")
    func mainWindowRequiresExplicitEvent() {
        #expect(StartupPresentationPolicy.mainWindowEvents == ["main"])
    }
}
