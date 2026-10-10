import Cocoa

final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var settingsWindowController: SettingsWindowController?
    private var floatingButtonItem: NSMenuItem?

    func install() {
        if let button = statusItem.button {
            button.image = MenuBarIconProvider.icon()
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Paste", action: #selector(pasteTapped), keyEquivalent: "").target = self
        menu.addItem(.separator())

        let floatingItem = NSMenuItem(title: "Floating Paste.IT Button", action: #selector(floatingButtonToggled), keyEquivalent: "")
        floatingItem.target = self
        menu.addItem(floatingItem)
        floatingButtonItem = floatingItem

        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settingsTapped), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Paste.IT", action: #selector(quitTapped), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    /// Keeps the checkmark in sync even when the floating button was
    /// toggled from the Settings window instead of this menu.
    func menuNeedsUpdate(_ menu: NSMenu) {
        floatingButtonItem?.state = FloatingPasteButtonController.shared.isEnabled ? .on : .off
    }

    @objc private func pasteTapped() {
        ActionController.shared.performPaste()
    }

    @objc private func floatingButtonToggled() {
        FloatingPasteButtonController.shared.setEnabled(!FloatingPasteButtonController.shared.isEnabled)
    }

    @objc private func settingsTapped() {
        let controller = settingsWindowController ?? SettingsWindowController()
        settingsWindowController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitTapped() {
        NSApp.terminate(nil)
    }
}
