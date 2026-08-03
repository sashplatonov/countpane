import Testing
@testable import Countpane

@Suite("Application lifetime policy")
struct AppLifetimePolicyTests {
    @Test("Loading keeps the process alive until persistence is ready")
    func loadingState() {
        #expect(!AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: false,
            visibleWidgetCount: 0
        ))
    }

    @Test("No visible widgets allow the process to terminate after loading")
    func emptyWidgetState() {
        #expect(AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: true,
            visibleWidgetCount: 0
        ))
    }

    @Test("Visible widgets keep the process alive")
    func visibleWidgetState() {
        #expect(!AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: true,
            visibleWidgetCount: 1
        ))
    }

    @Test("An early close terminates only after loading with no visible window or widget")
    func earlyWindowClose() {
        #expect(AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 0,
            visibleWidgetCount: 0
        ))
        #expect(!AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 1,
            visibleWidgetCount: 0
        ))
        #expect(!AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 0,
            visibleWidgetCount: 1
        ))
    }
}
