import Cocoa

/// Types text out as synthetic keystrokes rather than placing it on the system
/// pasteboard. This is what makes paste work inside remote desktop / VM
/// windows: the host OS sees real key events instead of relying on clipboard
/// sync between the local machine and the remote session.
enum KeystrokeTyper {
    static func type(_ text: String, delayMicroseconds: UInt32 = 1_500) {
        guard !text.isEmpty else { return }
        let source = CGEventSource(stateID: .hidSystemState)

        for character in text {
            // Send the whole grapheme cluster's UTF-16 units together so
            // combining characters/emoji are typed as a single keystroke.
            let units = Array(String(character).utf16)

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            // Events from .hidSystemState otherwise inherit whatever modifier
            // keys are physically still held down (e.g. the Cmd/Option the
            // user is holding to trigger the paste hotkey itself), and macOS
            // treats any keystroke carrying Cmd as a shortcut attempt instead
            // of text input — silently swallowing the typed text instead of
            // inserting it. Clearing flags makes every character a plain,
            // unmodified keystroke regardless of what's really being held.
            down.flags = []
            up.flags = []

            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            usleep(delayMicroseconds)
        }
    }
}
