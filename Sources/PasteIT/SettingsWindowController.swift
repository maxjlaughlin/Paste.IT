import Cocoa

final class SettingsWindowController: NSWindowController {
    private let copyRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
    private let pasteRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
    private let copyOverrideCheckbox = NSButton(checkboxWithTitle: "Use ⌘C to capture copies", target: nil, action: nil)
    private let pasteOverrideCheckbox = NSButton(checkboxWithTitle: "Use ⌘V / ⌘⇧V to trigger typed paste", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 220),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Paste.IT Settings"
        window.center()
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let window = window else { return }

        copyRecorder.hotkey = HotkeySettings.shared.copyHotkey
        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
        copyRecorder.onChange = { [weak self] hotkey in
            // Bare ⌘C must stay unconsumed no matter how it was recorded —
            // that passthrough is what lets the frontmost app's native copy
            // fire at all. Anything else should always be swallowed, since
            // nothing legitimately binds a custom combo like Option+Cmd+C.
            var updated = hotkey
            updated.consumesEvent = !updated.isBareCommand(keyCode: 8)
            HotkeySettings.shared.copyHotkey = updated
            HotkeySettings.shared.save()
            self?.copyOverrideCheckbox.state = updated.isBareCommand(keyCode: 8) ? .on : .off
        }
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

        copyOverrideCheckbox.target = self
        copyOverrideCheckbox.action = #selector(copyOverrideToggled)
        copyOverrideCheckbox.state = HotkeySettings.shared.copyHotkey.isBareCommand(keyCode: 8) ? .on : .off

        pasteOverrideCheckbox.target = self
        pasteOverrideCheckbox.action = #selector(pasteOverrideToggled)
        pasteOverrideCheckbox.state = HotkeySettings.shared.pasteHotkey.isBareCommand(keyCode: 9) ? .on : .off

        let copyRow = NSStackView(views: [NSTextField(labelWithString: "Copy hotkey:"), copyRecorder])
        copyRow.orientation = .horizontal
        copyRow.spacing = 8

        let pasteRow = NSStackView(views: [NSTextField(labelWithString: "Paste hotkey:"), pasteRecorder])
        pasteRow.orientation = .horizontal
        pasteRow.spacing = 8

        let note = NSTextField(wrappingLabelWithString: "Paste always types the copied text out as keystrokes, so it works through remote desktop sessions and VMs.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [copyRow, copyOverrideCheckbox, pasteRow, pasteOverrideCheckbox, note])
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

    @objc private func copyOverrideToggled() {
        HotkeySettings.shared.useSystemCopyOverride(copyOverrideCheckbox.state == .on)
        copyRecorder.hotkey = HotkeySettings.shared.copyHotkey
    }

    @objc private func pasteOverrideToggled() {
        HotkeySettings.shared.useSystemPasteOverride(pasteOverrideCheckbox.state == .on)
        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
    }
}
