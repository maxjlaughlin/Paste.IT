import Foundation

/// Holds the last copied text in memory only. Nothing is ever written to disk
/// or sent off-device, and the buffer is cleared when the app quits.
final class ClipboardStore {
    static let shared = ClipboardStore()

    private(set) var text: String = ""

    private init() {}

    func set(_ newText: String) {
        text = newText
    }

    func clear() {
        text = ""
    }
}
