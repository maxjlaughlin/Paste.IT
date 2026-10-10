import Cocoa

/// Ties together the "Copy" and "Paste" actions used by both the menu bar
/// icon and the global hotkeys.
final class ActionController {
    static let shared = ActionController()
    private init() {}

    /// Tags every synthetic Cmd+C / Cmd+V event posted by
    /// simulateCommandKeystroke below, so HotkeyManager's own event tap can
    /// recognize and ignore them instead of matching one as a fresh hotkey
    /// press. See the tap's check of this tag for why that matters.
    static let syntheticEventTag: Int64 = 0x5061_7374_4549_54 // "PastEIT", arbitrary non-zero

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
    /// real system paste instead of retyping whatever text came before it.
    /// Checked live against the pasteboard right here — not from
    /// PasteboardWatcher's periodic poll, which could still be a tick
    /// behind a screenshot taken just before Paste is triggered right after
    /// it, and was the source of the screenshot-paste only "working ~75% of
    /// the time". Copying new text, or picking an older entry from Recent
    /// Copies, naturally switches this back to typing since both already
    /// put real text on the pasteboard.
    func performPaste(_ text: String? = nil) {
        if text == nil, NSPasteboard.general.string(forType: .string) == nil {
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

        // Gives the frontmost app time to actually finish its native copy
        // before checking — too short a window here reads as an occasional
        // "Copy silently did nothing" under system load or in slower apps.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
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
    ///
    /// Tagged with syntheticEventTag because this posts at the HID tap
    /// level, which HotkeyManager's session-level tap also sees. Without
    /// the tag, this real ⌘V fallback could match the user's own paste
    /// hotkey (if they've bound it to bare ⌘V) and re-trigger Paste —
    /// which, while the pasteboard still isn't text, fires this same
    /// fallback again, forever, pegging the main thread until a real copy
    /// puts text on the pasteboard and breaks the cycle.
    private func simulateCommandKeystroke(virtualKey: CGKeyCode) {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventTag)
        up.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventTag)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
