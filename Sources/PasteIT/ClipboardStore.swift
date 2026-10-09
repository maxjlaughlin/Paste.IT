import Foundation

/// Holds recent copies in memory only, most recent first. Nothing is ever
/// written to disk or sent off-device, and the whole history is cleared
/// when the app quits.
final class ClipboardStore {
    static let shared = ClipboardStore()

    static let maxHistory = 20

    private(set) var history: [String] = []

    private init() {}

    /// Adds an entry to the top of the history. Re-adding an existing entry
    /// moves it back to the top instead of creating a duplicate.
    func add(_ text: String) {
        guard !text.isEmpty else { return }
        history.removeAll { $0 == text }
        history.insert(text, at: 0)
        if history.count > Self.maxHistory {
            history.removeLast(history.count - Self.maxHistory)
        }
    }

    func clear() {
        history.removeAll()
    }
}
