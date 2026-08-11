import Cocoa

/// A button that, when clicked, captures the next key combination the user
/// presses and reports it back as a Hotkey.
final class HotkeyRecorderView: NSButton {
    var hotkey = Hotkey(keyCode: 0, modifiers: 0, consumesEvent: false) {
        didSet { title = HotkeyFormatter.string(for: hotkey) }
    }
    var onChange: ((Hotkey) -> Void)?

    private var monitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        target = self
        action = #selector(startRecording)
        title = HotkeyFormatter.string(for: hotkey)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func startRecording() {
        guard monitor == nil else { return }
        title = "Press keys…"
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.finishRecording(with: event)
            return nil
        }
    }

    private func finishRecording(with event: NSEvent) {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil

        var flags: UInt64 = 0
        if event.modifierFlags.contains(.command) { flags |= CGEventFlags.maskCommand.rawValue }
        if event.modifierFlags.contains(.shift) { flags |= CGEventFlags.maskShift.rawValue }
        if event.modifierFlags.contains(.control) { flags |= CGEventFlags.maskControl.rawValue }
        if event.modifierFlags.contains(.option) { flags |= CGEventFlags.maskAlternate.rawValue }

        let newHotkey = Hotkey(keyCode: UInt16(event.keyCode), modifiers: flags, consumesEvent: hotkey.consumesEvent)
        hotkey = newHotkey
        onChange?(newHotkey)
    }
}

enum HotkeyFormatter {
    static func string(for hotkey: Hotkey) -> String {
        let flags = CGEventFlags(rawValue: hotkey.modifiers)
        var symbols = ""
        if flags.contains(.maskControl) { symbols += "⌃" }
        if flags.contains(.maskAlternate) { symbols += "⌥" }
        if flags.contains(.maskShift) { symbols += "⇧" }
        if flags.contains(.maskCommand) { symbols += "⌘" }
        return symbols + KeyCodeNames.name(for: hotkey.keyCode)
    }
}

enum KeyCodeNames {
    // Common US keyboard layout letter keys, enough for the default
    // copy/paste bindings. Extend this table if you bind other keys.
    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N", 46: "M",
    ]

    static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key\(keyCode)"
    }
}
