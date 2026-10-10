import Cocoa
import Carbon

/// Listens system-wide for the configured Copy/Paste hotkeys using a
/// CGEventTap. This requires the app to be trusted for Accessibility in
/// System Settings > Privacy & Security > Accessibility — the same
/// permission needed to type synthetic keystrokes into other apps.
final class HotkeyManager {
    private let settings: HotkeySettings
    private let onCopy: () -> Void
    private let onNativeCopy: () -> Void
    private let onPaste: () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var trustCheckTimer: Timer?

    init(settings: HotkeySettings, onCopy: @escaping () -> Void, onNativeCopy: @escaping () -> Void, onPaste: @escaping () -> Void) {
        self.settings = settings
        self.onCopy = onCopy
        self.onNativeCopy = onNativeCopy
        self.onPaste = onPaste
    }

    func start() {
        if AXIsProcessTrusted() {
            createTap()
            return
        }

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // Accessibility is granted from System Settings while the app keeps
        // running, usually without a relaunch — poll until it's trusted
        // instead of giving up after this one check.
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.trustCheckTimer = nil
            self.createTap()
        }
        RunLoop.main.add(timer, forMode: .common)
        trustCheckTimer = timer
    }

    func stop() {
        trustCheckTimer?.invalidate()
        trustCheckTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func createTap() {
        guard eventTap == nil else { return }

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

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passRetained(event)
        }
        guard type == .keyDown else { return Unmanaged.passRetained(event) }

        let flags = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        // Escape cancels an in-progress paste. Only intercepted while
        // KeystrokeTyper is actually typing — the rest of the time Escape
        // passes through untouched, same as always, everywhere else.
        if keyCode == UInt16(kVK_Escape), KeystrokeTyper.isTypingNow() {
            KeystrokeTyper.cancel()
            return nil
        }

        if settings.copyHotkey.matches(keyCode: keyCode, flags: flags) {
            if settings.copyHotkey.isBareCommand(keyCode: 8) {
                // Plain ⌘C: let the frontmost app's own copy happen and just
                // capture the result — resimulating ⌘C here would match
                // this same hotkey again and loop forever.
                DispatchQueue.main.async { self.onNativeCopy() }
            } else {
                DispatchQueue.main.async { self.onCopy() }
            }
            return settings.copyHotkey.consumesEvent ? nil : Unmanaged.passRetained(event)
        }
        if settings.pasteHotkey.matches(keyCode: keyCode, flags: flags) {
            DispatchQueue.main.async { self.onPaste() }
            return settings.pasteHotkey.consumesEvent ? nil : Unmanaged.passRetained(event)
        }
        return Unmanaged.passRetained(event)
    }
}
