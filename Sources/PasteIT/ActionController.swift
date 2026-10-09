import Cocoa

/// Ties together the "Copy" and "Paste" actions used by both the menu bar
/// icon and the global hotkeys.
final class ActionController {
    static let shared = ActionController()
    private init() {}

    /// Simulates Cmd+C so the frontmost app copies its current selection,
    /// then pulls the result off the system pasteboard into our own buffer.
    /// Use this from triggers that don't already cause a native copy on
    /// their own (menu bar click, Services entry, or a hotkey combo other
    /// than plain ⌘C).
    func performCopy() {
        simulateCommandKeystroke(virtualKey: 8) // 'c'
        captureFromPasteboard()
    }

    /// Call this when the Copy hotkey itself is plain ⌘C and was left
    /// unconsumed: the real keystroke already reached the frontmost app and
    /// triggered its native copy, so just read the result. Simulating
    /// another ⌘C here would re-trigger the same global hotkey and loop
    /// forever.
    func captureRealCopy() {
        captureFromPasteboard()
    }

    /// Types text out at the current cursor location via synthetic
    /// keystrokes instead of a system paste. Defaults to the most recent
    /// copy; pass a specific history entry to paste an older one.
    ///
    /// If nothing has been explicitly selected and the system pasteboard
    /// currently holds something Paste.IT can't type (most commonly an
    /// image from a screenshot-to-clipboard shortcut), this defers to a
    /// real system paste instead of retyping whatever text came before it
    /// — copying new text, or picking an older entry from Recent Copies,
    /// switches it back to typing normally.
    func performPaste(_ text: String? = nil) {
        if text == nil && !ClipboardStore.shared.currentCopyIsText {
            simulateCommandKeystroke(virtualKey: 9) // 'v'
            return
        }
        guard let target = text ?? ClipboardStore.shared.history.first, !target.isEmpty else { return }
        KeystrokeTyper.type(target)
    }

    /// Makes an older Recent Copies entry the current one — moving it to
    /// the top of history and onto the system pasteboard, the same place a
    /// fresh Copy would put it — without typing anything. Paste (hotkey or
    /// menu) will then use this entry the next time it's triggered.
    func selectFromHistory(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        ClipboardStore.shared.add(text)
    }

    private func captureFromPasteboard() {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard pasteboard.changeCount != previousChangeCount,
                  let copied = pasteboard.string(forType: .string) else { return }
            ClipboardStore.shared.add(copied)
        }
    }

    /// Used for both triggering a native Copy (virtualKey 8, 'c') and
    /// falling back to a real native Paste (virtualKey 9, 'v') when the
    /// pasteboard holds something that can't be typed. Only needs to work
    /// against native Mac apps — if the frontmost app happens to be a VM
    /// window, forwarding this into the guest isn't attempted; pasting a
    /// screenshot there is a known, accepted limitation.
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
