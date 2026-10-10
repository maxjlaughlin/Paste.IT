import Cocoa

/// Drives the single Paste action shared by the global hotkey, the
/// right-click Services entry, and the floating button. Always reads
/// straight off the system clipboard — Paste.IT keeps no clipboard
/// history or buffer of its own.
final class ActionController {
    static let shared = ActionController()
    private init() {}

    /// Types the current system clipboard contents out at the current
    /// cursor location via synthetic keystrokes instead of a system paste,
    /// so it works anywhere a real keyboard would — including inside
    /// RDP/VNC windows and VMs that don't sync the clipboard.
    ///
    /// If the clipboard currently holds something Paste.IT can't type
    /// (most commonly an image from a screenshot-to-clipboard shortcut),
    /// this falls back to a real system paste instead.
    func performPaste() {
        guard let text = NSPasteboard.general.string(forType: .string), !text.isEmpty else {
            simulateCommandV()
            return
        }
        KeystrokeTyper.type(text)
    }

    /// Fallback for when the clipboard holds something that can't be typed.
    /// Only works against native Mac apps — if the frontmost app happens to
    /// be a VM window, forwarding this into the guest isn't attempted;
    /// pasting a screenshot there is a known, accepted limitation.
    private func simulateCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
