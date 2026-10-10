import Cocoa

struct Hotkey: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64 // raw CGEventFlags value
    /// When true, the underlying system shortcut is swallowed (e.g. so
    /// Cmd+V triggers a typed paste instead of the normal system paste).
    var consumesEvent: Bool

    func matches(keyCode: UInt16, flags: CGEventFlags) -> Bool {
        guard keyCode == self.keyCode else { return false }
        let relevant: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        return flags.intersection(relevant) == CGEventFlags(rawValue: modifiers).intersection(relevant)
    }

    /// True when this is just ⌘ + the given key with no other modifiers —
    /// the same combo macOS itself binds to Edit > Paste.
    func isBareCommand(keyCode code: UInt16) -> Bool {
        keyCode == code && CGEventFlags(rawValue: modifiers) == .maskCommand
    }
}

/// Persists the Paste hotkey choice locally via UserDefaults. Nothing here
/// ever leaves the machine.
final class HotkeySettings {
    static let shared = HotkeySettings()

    private enum Keys {
        static let pasteHotkey = "com.pasteit.pasteHotkey"
    }

    // Default: Option+Cmd+V, chosen so it doesn't collide with the system's
    // own Cmd+V out of the box. consumesEvent is true because nothing
    // legitimately binds this combo — letting the real keystroke pass
    // through to the frontmost app (or a web page's own key handler) only
    // risks it doing something unwanted alongside us.
    var pasteHotkey = Hotkey(keyCode: 9, modifiers: CGEventFlags([.maskCommand, .maskAlternate]).rawValue, consumesEvent: true)

    private init() {
        load()
    }

    /// Toggle for "use Cmd+V / Cmd+Shift+V as the paste trigger" from the
    /// original spec: when enabled, plain Cmd+V is intercepted and replaced
    /// with a typed paste; when disabled, Paste.IT falls back to its own
    /// non-conflicting hotkey and leaves system Cmd+V alone.
    func useSystemPasteOverride(_ enabled: Bool) {
        pasteHotkey = enabled
            ? Hotkey(keyCode: 9, modifiers: CGEventFlags([.maskCommand]).rawValue, consumesEvent: true)
            : Hotkey(keyCode: 9, modifiers: CGEventFlags([.maskCommand, .maskAlternate]).rawValue, consumesEvent: true)
        save()
    }

    func save() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(pasteHotkey) { defaults.set(data, forKey: Keys.pasteHotkey) }
    }

    private func load() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Keys.pasteHotkey),
           let decoded = try? JSONDecoder().decode(Hotkey.self, from: data) {
            pasteHotkey = decoded
        }
    }
}
