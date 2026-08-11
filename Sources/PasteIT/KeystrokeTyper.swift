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

            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            usleep(delayMicroseconds)
        }
    }
}
