import AppKit
import SwiftUI

struct ReliableTitleField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit)
    }

    func makeNSView(context: Context) -> TitleFieldContainer {
        let container = TitleFieldContainer()
        let field = container.textField

        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.stringValue = text
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 15, weight: .medium)
        field.lineBreakMode = .byTruncatingTail
        field.usesSingleLineMode = true
        field.cell?.sendsActionOnEndEditing = true
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)

        container.onReadyForFocus = {
            guard let window = container.window else { return }
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(field)
            field.selectText(nil)
        }

        return container
    }

    func updateNSView(_ container: TitleFieldContainer, context: Context) {
        context.coordinator.onSubmit = onSubmit
        if container.textField.stringValue != text {
            container.textField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        var onSubmit: (() -> Void)?

        init(text: Binding<String>, onSubmit: (() -> Void)?) {
            _text = text
            self.onSubmit = onSubmit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text = field.stringValue
        }

        @objc func submit() {
            onSubmit?()
        }
    }
}

final class TitleFieldContainer: NSView {
    let textField = NSTextField(frame: .zero)
    var onReadyForFocus: (() -> Void)?
    private var focusTask: Task<Void, Never>?
    private var hasRequestedInitialFocus = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusTask?.cancel()
        guard window != nil, !hasRequestedInitialFocus else { return }
        hasRequestedInitialFocus = true

        focusTask = Task { @MainActor [weak self] in
            // Wait until the sheet is key and SwiftUI has finished assigning its default responder.
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled, let self, self.window != nil else { return }
            self.onReadyForFocus?()

            // A second pass prevents another SwiftUI field from stealing first responder
            // during the final sheet layout transaction.
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled, self.window != nil else { return }
            self.onReadyForFocus?()
        }
    }

    deinit {
        focusTask?.cancel()
    }
}

struct EditorWindowActivationView: NSViewRepresentable {
    let onOutsideClick: () -> Void

    func makeNSView(context: Context) -> EditorWindowObserver {
        EditorWindowObserver(onOutsideClick: onOutsideClick)
    }

    func updateNSView(_ nsView: EditorWindowObserver, context: Context) {
        nsView.onOutsideClick = onOutsideClick
    }
}

final class EditorWindowObserver: NSView {
    private var activationTask: Task<Void, Never>?
    private let mouseMonitors = EditorWindowMouseMonitors()
    var onOutsideClick: () -> Void

    init(onOutsideClick: @escaping () -> Void) {
        self.onOutsideClick = onOutsideClick
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        activationTask?.cancel()
        removeMouseMonitors()
        guard window != nil else { return }

        installMouseMonitors()

        activationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled, let window = self?.window else { return }
            window.level = .normal
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    deinit {
        activationTask?.cancel()
    }

    private func installMouseMonitors() {
        let eventMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]

        mouseMonitors.local = NSEvent.addLocalMonitorForEvents(matching: eventMask) { [weak self] event in
            self?.handleOutsideClick(event)
            return event
        }

        mouseMonitors.global = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] _ in
            guard let self, let window = self.window, !window.frame.contains(NSEvent.mouseLocation) else { return }
            self.onOutsideClick()
        }
    }

    private func removeMouseMonitors() {
        mouseMonitors.remove()
    }

    private func handleOutsideClick(_ event: NSEvent) {
        guard let window, !isInEditorWindow(event, editorWindow: window) else { return }
        onOutsideClick()
    }

    private func isInEditorWindow(_ event: NSEvent, editorWindow: NSWindow) -> Bool {
        guard let eventWindow = event.window else {
            return editorWindow.frame.contains(NSEvent.mouseLocation)
        }

        return eventWindow == editorWindow ||
            eventWindow.sheetParent == editorWindow ||
            editorWindow.childWindows?.contains(eventWindow) == true
    }
}

private final class EditorWindowMouseMonitors {
    var local: Any?
    var global: Any?

    func remove() {
        if let local {
            NSEvent.removeMonitor(local)
            self.local = nil
        }
        if let global {
            NSEvent.removeMonitor(global)
            self.global = nil
        }
    }

    deinit {
        remove()
    }
}
