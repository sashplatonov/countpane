import AppKit
import Foundation
import Observation
import ServiceManagement

struct StartupPresentationDecision: Equatable, Sendable {
    let showMainWindow: Bool
    let showCountdownWidgets: Bool

    static func resolve(isLoginLaunch: Bool) -> Self {
        Self(showMainWindow: !isLoginLaunch, showCountdownWidgets: true)
    }

    static func shouldDismissMainWindow(
        isLoginLaunch: Bool,
        hasAppliedStartupPresentation: Bool
    ) -> Bool {
        isLoginLaunch && !hasAppliedStartupPresentation
    }
}

enum AppLifetimePolicy {
    /// Keep the process alive while the model is still loading so closing a
    /// window cannot race the initial persistence read. A menu-bar entry point
    /// is also a user-visible reason to keep the process alive.
    static func shouldTerminateAfterLastWindowClosed(
        isModelLoaded: Bool,
        visibleWidgetCount: Int,
        hasMenuBarEntryPoint: Bool
    ) -> Bool {
        isModelLoaded && visibleWidgetCount == 0 && !hasMenuBarEntryPoint
    }

    static func shouldTerminateAfterInitialLoad(
        hasPendingLastWindowClose: Bool,
        visibleWindowCount: Int,
        visibleWidgetCount: Int,
        hasMenuBarEntryPoint: Bool
    ) -> Bool {
        hasPendingLastWindowClose && visibleWindowCount == 0 && visibleWidgetCount == 0 && !hasMenuBarEntryPoint
    }
}

@MainActor
@Observable
final class LaunchSession {
    static let shared = LaunchSession()

    private(set) var isLoginLaunch = false
    private var hasAppliedStartupPresentation = false

    private init() {}

    func configure(from notification: Notification) {
        // AppKit publishes this Boolean in the launch notification. A default
        // launch is a normal user launch; a login-item launch is non-default.
        let defaultLaunch = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        isLoginLaunch = !defaultLaunch
    }

    func shouldDismissMainWindowForStartup() -> Bool {
        let shouldDismiss = StartupPresentationDecision.shouldDismissMainWindow(
            isLoginLaunch: isLoginLaunch,
            hasAppliedStartupPresentation: hasAppliedStartupPresentation
        )
        hasAppliedStartupPresentation = true
        return shouldDismiss
    }
}

@MainActor
@Observable
final class LoginItemController {
    private(set) var isEnabled = false
    private(set) var requiresApproval = false
    private(set) var isUpdating = false
    var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        isEnabled = status == .enabled
        requiresApproval = status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) {
        guard !isUpdating else { return }
        isUpdating = true
        errorMessage = nil

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = Self.userFacingMessage(for: error)
        }

        refresh()
        isUpdating = false
    }

    static func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        if Bundle.main.bundleURL.pathExtension.lowercased() != "app" {
            return "Launch at Login is available after exporting and running Countpane as a macOS .app bundle."
        }
        return nsError.localizedDescription
    }
}
