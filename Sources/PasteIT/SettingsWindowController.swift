import Cocoa

final class SettingsWindowController: NSWindowController {
    private let pasteRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
    private let pasteOverrideCheckbox = NSButton(checkboxWithTitle: "Use ⌘V / ⌘⇧V to trigger typed paste", target: nil, action: nil)
    private let floatingButtonCheckbox = NSButton(checkboxWithTitle: "Show floating Paste.IT button", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Paste.IT Settings"
        window.center()
        self.init(window: window)
        buildUI()
    }

    /// Refreshes every control from the current settings each time the
    /// window is shown, since either hotkey or the floating button can also
    /// be changed from outside this window (e.g. the menu bar menu).
    override func showWindow(_ sender: Any?) {
        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
        pasteOverrideCheckbox.state = HotkeySettings.shared.pasteHotkey.isBareCommand(keyCode: 9) ? .on : .off
        floatingButtonCheckbox.state = FloatingPasteButtonController.shared.isEnabled ? .on : .off
        super.showWindow(sender)
    }

    private func buildUI() {
        guard let window = window else { return }

        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
        pasteRecorder.onChange = { [weak self] hotkey in
            // Paste always types the text itself, so the real keystroke
            // should always be swallowed — there's no case where letting it
            // through to the frontmost app helps.
            var updated = hotkey
            updated.consumesEvent = true
            HotkeySettings.shared.pasteHotkey = updated
            HotkeySettings.shared.save()
            self?.pasteOverrideCheckbox.state = updated.isBareCommand(keyCode: 9) ? .on : .off
        }

        pasteOverrideCheckbox.target = self
        pasteOverrideCheckbox.action = #selector(pasteOverrideToggled)
        pasteOverrideCheckbox.state = HotkeySettings.shared.pasteHotkey.isBareCommand(keyCode: 9) ? .on : .off

        floatingButtonCheckbox.target = self
        floatingButtonCheckbox.action = #selector(floatingButtonToggled)
        floatingButtonCheckbox.state = FloatingPasteButtonController.shared.isEnabled ? .on : .off

        let pasteRow = NSStackView(views: [NSTextField(labelWithString: "Paste hotkey:"), pasteRecorder])
        pasteRow.orientation = .horizontal
        pasteRow.spacing = 8

        let note = NSTextField(wrappingLabelWithString: "Paste always types the clipboard's text out as keystrokes, so it works through remote desktop sessions and VMs.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [pasteRow, pasteOverrideCheckbox, floatingButtonCheckbox, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(stack)
        window.contentView = contentView

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    @objc private func pasteOverrideToggled() {
        HotkeySettings.shared.useSystemPasteOverride(pasteOverrideCheckbox.state == .on)
        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
    }

    @objc private func floatingButtonToggled() {
        FloatingPasteButtonController.shared.setEnabled(floatingButtonCheckbox.state == .on)
    }
}
