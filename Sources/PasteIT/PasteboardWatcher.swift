import Cocoa

/// Watches the system pasteboard for any change and pulls new text into
/// ClipboardStore automatically — regardless of how the copy happened.
/// Without this, only copies triggered through Paste.IT's own menu, hotkey,
/// or Services entry would ever show up as "pasteable" here; a right-click
/// Copy, an app's Edit menu, or any other app's own shortcut writes straight
/// to NSPasteboard and Paste.IT would otherwise never know it happened.
///
/// Polling is the standard approach for this (it's what other clipboard
/// managers do too) since NSPasteboard has no change notification API.
/// changeCount is a cheap integer compare, so this costs effectively nothing
/// even at a short interval.
final class PasteboardWatcher {
    static let shared = PasteboardWatcher()
    private init() {}

    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount

        let timer = Timer(timeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForChanges() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            ClipboardStore.shared.add(text)
        } else {
            // Something was copied that isn't plain text — most commonly an
            // image from a screenshot-to-clipboard shortcut (Cmd+Ctrl+Shift+4).
            // Leave any earlier text history alone, but flag that the
            // *current* clipboard content isn't something Paste.IT can type.
            ClipboardStore.shared.markCurrentCopyAsNonText()
        }
    }
}
