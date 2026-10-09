import Cocoa
import Carbon

/// Types text out as synthetic keystrokes rather than placing it on the system
/// pasteboard. This is what makes paste work inside remote desktop / VM
/// windows: the host OS sees real key events instead of relying on clipboard
/// sync between the local machine and the remote session.
///
/// Each character is sent as a real key code + modifier combo looked up for
/// the current keyboard layout (CurrentKeyboardLayout below), not a dummy key
/// code with a Unicode-string override. A Unicode override is only honored by
/// things that read NSEvent's characters (regular Mac apps); a VM's
/// virtualized keyboard forwards raw key codes straight to the guest OS and
/// ignores it, so a dummy code gets typed as whatever key that code actually
/// is — on this app's events, key code 0, the "A" key.
enum KeystrokeTyper {
    static func type(_ text: String, delayMicroseconds: UInt32 = 1_500) {
        guard !text.isEmpty else { return }
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeMap = CurrentKeyboardLayout.characterKeyCodes()

        for character in text {
            let mapped = keyCodeMap[character]
            let virtualKey = mapped?.0 ?? 0

            guard let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false) else {
                continue
            }

            if let (_, modifiers) = mapped {
                // A real key + modifiers for this character, indistinguishable
                // from an actual keystroke to anything reading raw key codes.
                down.flags = modifiers
                up.flags = modifiers
            } else {
                // No key on the current layout produces this character (e.g.
                // an emoji, or a script outside the keyboard layout) — fall
                // back to a Unicode override. Works in regular Mac apps, but
                // a VM's virtualized keyboard will see the dummy "A" key code
                // instead; there's no real keycode to send for a character
                // the keyboard can't physically produce.
                down.flags = []
                up.flags = []
                let units = Array(String(character).utf16)
                down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
                up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }

            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)

            usleep(delayMicroseconds)
        }
    }
}

/// Maps characters to the (keyCode, modifier flags) that produce them on the
/// current keyboard layout, by running every key + modifier combo through
/// the same translation macOS itself uses (UCKeyTranslate).
private enum CurrentKeyboardLayout {
    static func characterKeyCodes() -> [Character: (CGKeyCode, CGEventFlags)] {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return [:]
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutDataPtr).takeUnretainedValue() as Data

        // (CGEventFlags to apply to the synthetic event, raw Carbon modifier
        // bits to pass into UCKeyTranslate for that same combo).
        let modifierCombos: [(CGEventFlags, UInt32)] = [
            ([], 0),
            (.maskShift, UInt32(shiftKey)),
            (.maskAlternate, UInt32(optionKey)),
            ([.maskShift, .maskAlternate], UInt32(shiftKey | optionKey)),
        ]

        var map: [Character: (CGKeyCode, CGEventFlags)] = [:]

        layoutData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            guard let base = buffer.baseAddress else { return }
            let keyboardLayout = base.assumingMemoryBound(to: UCKeyboardLayout.self)

            for keyCode: UInt16 in 0..<128 {
                for (flags, rawModifiers) in modifierCombos {
                    var deadKeyState: UInt32 = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    var length = 0

                    let status = UCKeyTranslate(
                        keyboardLayout,
                        keyCode,
                        UInt16(kUCKeyActionDown),
                        (rawModifiers >> 8) & 0xFF,
                        UInt32(LMGetKbdType()),
                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                        &deadKeyState,
                        chars.count,
                        &length,
                        &chars
                    )

                    guard status == noErr, length > 0, let scalar = Unicode.Scalar(chars[0]) else { continue }
                    let character = Character(scalar)
                    // Prefer the combo found first (none, then shift, ...)
                    // so a character reachable without modifiers keeps that
                    // simpler mapping even if a later combo also produces it.
                    if map[character] == nil {
                        map[character] = (CGKeyCode(keyCode), flags)
                    }
                }
            }
        }

        // Make sure these are present even if a given layout's translation
        // table happens to omit them.
        map["\n"] = (CGKeyCode(kVK_Return), [])
        map["\r"] = (CGKeyCode(kVK_Return), [])
        map["\t"] = (CGKeyCode(kVK_Tab), [])

        return map
    }
}
