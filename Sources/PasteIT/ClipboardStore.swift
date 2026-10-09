import Foundation

/// Holds recent copies in memory only, most recent first. Nothing is ever
/// written to disk or sent off-device, and the whole history is cleared
/// when the app quits.
final class ClipboardStore {
    static let shared = ClipboardStore()

    static let maxHistory = 20

    private(set) var history: [String] = []

    /// Whether the most recent pasteboard change was text we captured here
    /// (so Paste should type it out) or something else entirely — most
    /// commonly an image, e.g. from a Cmd+Ctrl+Shift+4 screenshot-to-
    /// clipboard shortcut, which can't be represented as keystrokes. When
    /// this is false, Paste defers to a real system paste instead of
    /// retyping stale text, so the screenshot still pastes normally.
    private(set) var currentCopyIsText = true

    private init() {}

    /// Adds an entry to the top of the history. Re-adding an existing entry
    /// moves it back to the top instead of creating a duplicate.
    func add(_ text: String) {
        guard !text.isEmpty else { return }
        currentCopyIsText = true
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > Self.maxHistory {
            history.removeLast(history.count - Self.maxHistory)
        }
    }

    /// Call when the pasteboard changed to something that isn't plain text.
    /// History is left untouched (any previous text copy is still there to
    /// select from the Recent Copies menu) — this only flags that the
    /// *current* pasteboard content isn't something Paste.IT can type.
    func markCurrentCopyAsNonText() {
        currentCopyIsText = false
    }

    func clear() {
        history.removeAll()
        currentCopyIsText = true
    }
}
