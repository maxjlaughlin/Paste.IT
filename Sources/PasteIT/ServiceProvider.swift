import Cocoa

/// Backs the "Copy.IT" entry that shows up in the system-wide right-click
/// Services menu (see NSServices in Resources/Info.plist). When the user
/// highlights text anywhere, right-clicks, and chooses Services > Copy.IT,
/// macOS calls this method with the selection on the pasteboard.
final class ServiceProvider: NSObject {
    @objc func copyIt(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        guard let text = pasteboard.string(forType: .string), !text.isEmpty else {
            error.pointee = "Paste.IT: no text was selected." as NSString
            return
        }
        ClipboardStore.shared.set(text)
    }
}
