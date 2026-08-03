import Testing
@testable import Countpane

@Suite("Application lifetime policy")
struct AppLifetimePolicyTests {
    @Test("Loading keeps the process alive until persistence is ready")
    func loadingState() {
        #expect(!AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: false,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: true
        ))
    }

    @Test("No visible entry point allows the process to terminate after loading")
    func emptyWidgetState() {
        #expect(AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: true,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: false
        ))
    }

    @Test("Menu bar keeps the loaded app alive without widgets")
    func menuBarEntryPoint() {
        #expect(!AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: true,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: true
        ))
    }

    @Test("Visible widgets keep the process alive")
    func visibleWidgetState() {
        #expect(!AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: true,
            visibleWidgetCount: 1,
            hasMenuBarEntryPoint: false
        ))
    }

    @Test("An early close terminates only with no visible entry point")
    func earlyWindowClose() {
        #expect(AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 0,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: false
        ))
        #expect(!AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 1,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: false
        ))
        #expect(!AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 0,
            visibleWidgetCount: 1,
            hasMenuBarEntryPoint: false
        ))
        #expect(!AppLifetimePolicy.shouldTerminateAfterInitialLoad(
            hasPendingLastWindowClose: true,
            visibleWindowCount: 0,
            visibleWidgetCount: 0,
            hasMenuBarEntryPoint: true
        ))
    }
}
