import AppKit
import SwiftUI

@main
struct CountpaneApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    var body: some Scene {
        WindowGroup("Countpane", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 700, minHeight: 500)
                .task { await model.load() }
        }
        .defaultSize(width: 1200, height: 760)
        .windowResizability(.contentMinSize)
        .commands { AppCommands() }

        Window("About Countpane", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        WindowGroup("Countdown Widget", id: "widget", for: UUID.self) { $id in
            if let id {
                CountdownWidgetView(id: id)
                    .environment(model)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 270, height: 160)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var terminationSaveInProgress = false
    func applicationWillFinishLaunching(_ notification: Notification) {
        installApplicationIcon()

        // Swift Package executables do not always enter the normal foreground
        // application activation policy automatically. Without .regular, menu
        // actions such as Paste may work while physical keyDown events are not
        // delivered reliably to text fields.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchSession.shared.configure(from: notification)

        // Login launches always stay in the background. RootView opens the
        // enabled desktop widgets and closes the management window.
        UpdateController.shared.startAutomaticChecks()

        guard !LaunchSession.shared.isLoginLaunch else { return }

        NSApp.activate(ignoringOtherApps: true)

        // Activation can race with initial window creation when launched from
        // Xcode as a Swift Package executable. Re-activate on the next run loop.
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
        }
    }


    private func installApplicationIcon() {
        guard let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let icon = NSImage(contentsOf: iconURL) else {
            assertionFailure("AppIcon.png is missing from the application resources")
            return
        }

        icon.size = NSSize(width: 512, height: 512)
        NSApp.applicationIconImage = icon
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !terminationSaveInProgress else { return .terminateLater }
        terminationSaveInProgress = true

        Task { @MainActor in
            await AppModel.shared.saveImmediately()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep the app alive when countdown widgets are being used without the
        // management window. The user can still quit from the app menu.
        false
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
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("0")
        }
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
