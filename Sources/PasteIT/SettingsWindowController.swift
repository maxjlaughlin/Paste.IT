import Cocoa

final class SettingsWindowController: NSWindowController {
    private let copyRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
    private let pasteRecorder = HotkeyRecorderView(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
    private let overrideCheckbox = NSButton(checkboxWithTitle: "Use ⌘V / ⌘⇧V to trigger typed paste", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
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
        copyRecorder.onChange = { hotkey in
            HotkeySettings.shared.copyHotkey = hotkey
            HotkeySettings.shared.save()
        }
        pasteRecorder.onChange = { hotkey in
            HotkeySettings.shared.pasteHotkey = hotkey
            HotkeySettings.shared.save()
        }

        overrideCheckbox.target = self
        overrideCheckbox.action = #selector(overrideToggled)
        overrideCheckbox.state = HotkeySettings.shared.pasteHotkey.consumesEvent ? .on : .off

        let copyRow = NSStackView(views: [NSTextField(labelWithString: "Copy hotkey:"), copyRecorder])
        copyRow.orientation = .horizontal
        copyRow.spacing = 8

        let pasteRow = NSStackView(views: [NSTextField(labelWithString: "Paste hotkey:"), pasteRecorder])
        pasteRow.orientation = .horizontal
        pasteRow.spacing = 8

        let note = NSTextField(wrappingLabelWithString: "Paste always types the copied text out as keystrokes, so it works through remote desktop sessions and VMs.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [copyRow, pasteRow, overrideCheckbox, note])
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

    @objc private func overrideToggled() {
        HotkeySettings.shared.useSystemPasteOverride(overrideCheckbox.state == .on)
        pasteRecorder.hotkey = HotkeySettings.shared.pasteHotkey
    }
}
