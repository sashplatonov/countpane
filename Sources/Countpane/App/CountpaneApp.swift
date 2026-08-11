import AppKit
import SwiftUI

@main
struct CountpaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window("Countpane", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 700, minHeight: 500)
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)
        .commands { AppCommands() }
        .handlesExternalEvents(matching: StartupPresentationPolicy.mainWindowEvents)

        MenuBarExtra {
            MenuBarView()
        } label: {
            AppBrandIcon(size: 18)
                .accessibilityLabel("Countpane")
        }
        .menuBarExtraStyle(.menu)

        Window("About Countpane", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSaveInProgress = false
    private var pendingInitialLoadTermination = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        installApplicationIcon()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Widget panels are restored after the persistent model has loaded.
        // The main window is opened only from the menu-bar action.
        UpdateController.shared.startAutomaticChecks()

        Task { @MainActor in
            await AppModel.shared.load()
            WidgetWindowController.shared.sync(with: AppModel.shared.visibleWidgetItems)
        }
    }


    private func installApplicationIcon() {
        guard let icon = AppIconResource.image else { return }

        icon.size = NSSize(width: 512, height: 512)
        NSApp.applicationIconImage = icon
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationSaveInProgress else { return .terminateLater }
        terminationSaveInProgress = true

        Task { @MainActor in
            let didSave = await AppModel.shared.saveForTermination()
            self.terminationSaveInProgress = false
            sender.reply(toApplicationShouldTerminate: didSave)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        guard AppModel.shared.isLoaded else {
            scheduleTerminationAfterInitialLoad()
            return false
        }

        // The persistent menu-bar entry point keeps Countpane available after
        // its management and widget windows have been closed.
        return AppLifetimePolicy.shouldTerminateAfterLastWindowClosed(
            isModelLoaded: AppModel.shared.isLoaded,
            visibleWidgetCount: AppModel.shared.visibleWidgetItems.count,
            hasMenuBarEntryPoint: true
        )
    }

    private func scheduleTerminationAfterInitialLoad() {
        pendingInitialLoadTermination = true
        Task { @MainActor [weak self] in
            await AppModel.shared.load()
            guard let self else { return }
            let shouldTerminate = AppLifetimePolicy.shouldTerminateAfterInitialLoad(
                hasPendingLastWindowClose: self.pendingInitialLoadTermination,
                visibleWindowCount: NSApp.windows.count(where: \.isVisible),
                visibleWidgetCount: AppModel.shared.visibleWidgetItems.count,
                hasMenuBarEntryPoint: true
            )
            self.pendingInitialLoadTermination = false
            if shouldTerminate {
                NSApp.terminate(nil)
            }
        }
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.newCountdownAction) private var newCountdownAction
    @FocusedValue(\.showSettingsAction) private var showSettingsAction

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Countpane") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "about")
            }
        }
        CommandGroup(replacing: .newItem) {
            Button("New Countdown") { newCountdownAction?() }
                .keyboardShortcut("n")
                .disabled(newCountdownAction == nil)
        }
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                UpdateController.shared.performPrimaryAction()
            }
        }
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { showSettingsAction?() }
                .keyboardShortcut(",")
                .disabled(showSettingsAction == nil)
        }
        CommandGroup(after: .windowArrangement) {
            Button("Show Main Window") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("0")
        }
    }
}

private struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Main Window") {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        }
        .keyboardShortcut("0")

        Divider()

        Button("Quit Countpane") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

private struct NewCountdownActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

private struct ShowSettingsActionKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var newCountdownAction: (() -> Void)? {
        get { self[NewCountdownActionKey.self] }
        set { self[NewCountdownActionKey.self] = newValue }
    }

    var showSettingsAction: (() -> Void)? {
        get { self[ShowSettingsActionKey.self] }
        set { self[ShowSettingsActionKey.self] = newValue }
    }
}

struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowObservationView {
        let view = WindowObservationView()
        view.onWindowChange = { window in configure(window) }
        return view
    }

    func updateNSView(_ view: WindowObservationView, context: Context) {
        view.onWindowChange = { window in configure(window) }
        if let window = view.window { configure(window) }
    }

    private func configure(_ window: NSWindow) {
        window.level = .normal
        window.collectionBehavior = [.managed]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.isMovableByWindowBackground = false
        window.setFrameAutosaveName("CountpaneMainWindow")
    }
}

final class WindowObservationView: NSView {
    var onWindowChange: ((NSWindow) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window { onWindowChange?(window) }
    }
}
