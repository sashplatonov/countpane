import Foundation
import Testing
@testable import Countpane

@Suite("Startup presentation")
struct StartupPresentationTests {
    @Test("Normal launches show the management window and widgets")
    func normalLaunch() {
        let decision = StartupPresentationDecision.resolve(isLoginLaunch: false)
        #expect(decision.showMainWindow)
        #expect(decision.showCountdownWidgets)
    }

    @Test("Login launches stay in the background and show widgets")
    func loginLaunch() {
        let decision = StartupPresentationDecision.resolve(isLoginLaunch: true)
        #expect(!decision.showMainWindow)
        #expect(decision.showCountdownWidgets)
    }
}
