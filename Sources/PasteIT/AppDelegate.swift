import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItemController = StatusItemController()
    private let serviceProvider = ServiceProvider()
    private var hotkeyManager: HotkeyManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only — no Dock icon, no app windows unless Settings is opened.
        NSApp.setActivationPolicy(.accessory)

        statusItemController.install()

        // Registers this app so "Copy.IT" appears in the system-wide right-click Services menu.
        NSApp.servicesProvider = serviceProvider
        NSUpdateDynamicServices()

        let manager = HotkeyManager(
            settings: HotkeySettings.shared,
            onCopy: { ActionController.shared.performCopy() },
            onNativeCopy: { ActionController.shared.captureRealCopy() },
            onPaste: { ActionController.shared.performPaste() }
        )
        manager.start()
        hotkeyManager = manager

        PasteboardWatcher.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        PasteboardWatcher.shared.stop()
        hotkeyManager?.stop()
        ClipboardStore.shared.clear()
    }
}
