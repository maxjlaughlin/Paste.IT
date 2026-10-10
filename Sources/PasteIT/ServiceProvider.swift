import Cocoa

/// Backs the "Paste with Paste.IT" entry that shows up in the system-wide
/// right-click Services menu (see NSServices in Resources/Info.plist).
/// Triggers the same typed-keystroke paste as the hotkey and floating
/// button, straight into whatever's focused where the user right-clicked —
/// useful for bypassing an app's own paste restrictions (e.g. a form field
/// that blocks Cmd+V), not just VMs.
///
/// This entry only appears where macOS's Services menu is actually
/// supported by the focused view (most native Cocoa text fields) — a
/// VM/RDP window's rendered screen typically won't offer it; the hotkey or
/// floating button cover that case instead.
final class ServiceProvider: NSObject {
    @objc func pasteWithPasteIt(_ pasteboard: NSPasteboard, userData: String, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        ActionController.shared.performPaste()
    }
}
