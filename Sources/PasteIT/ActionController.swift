import Cocoa

/// Ties together the "Copy" and "Paste" actions used by both the menu bar
/// icon and the global hotkeys.
final class ActionController {
    static let shared = ActionController()
    private init() {}

    /// Simulates Cmd+C so the frontmost app copies its current selection,
    /// then pulls the result off the system pasteboard into our own buffer.
    func performCopy() {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        simulateCommandKeystroke(virtualKey: 8) // 'c'

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard pasteboard.changeCount != previousChangeCount,
                  let copied = pasteboard.string(forType: .string) else { return }
            ClipboardStore.shared.set(copied)
        }
    }

    /// Types the stored text out at the current cursor location via
    /// synthetic keystrokes instead of a system paste.
    func performPaste() {
        let text = ClipboardStore.shared.text
        guard !text.isEmpty else { return }
        KeystrokeTyper.type(text)
    }

    private func simulateCommandKeystroke(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
