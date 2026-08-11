import Cocoa

/// Listens system-wide for the configured Copy/Paste hotkeys using a
/// CGEventTap. This requires the app to be trusted for Accessibility in
/// System Settings > Privacy & Security > Accessibility — the same
/// permission needed to type synthetic keystrokes into other apps.
final class HotkeyManager {
    private let settings: HotkeySettings
    private let onCopy: () -> Void
    private let onPaste: () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(settings: HotkeySettings, onCopy: @escaping () -> Void, onPaste: @escaping () -> Void) {
        self.settings = settings
        self.onCopy = onCopy
        self.onPaste = onPaste
    }

    func start() {
        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
                return manager.handle(type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        if settings.copyHotkey.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { self.onCopy() }
            return settings.copyHotkey.consumesEvent ? nil : Unmanaged.passRetained(event)
        }
        if settings.pasteHotkey.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { self.onPaste() }
            return settings.pasteHotkey.consumesEvent ? nil : Unmanaged.passRetained(event)
        }
        return Unmanaged.passRetained(event)
    }
}
