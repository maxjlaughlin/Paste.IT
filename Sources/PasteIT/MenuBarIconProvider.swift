import Cocoa

enum MenuBarIconProvider {
    /// Loads the bundled clipboard glyph as a template image (macOS tints
    /// template images automatically for light/dark menu bars). Falls back
    /// to an SF Symbol if the bundled resource can't be found, so the app
    /// still shows something even in unusual run contexts.
    static func icon() -> NSImage {
        if let url = Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        let fallback = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste.IT") ?? NSImage()
        fallback.isTemplate = true
        return fallback
    }
}
