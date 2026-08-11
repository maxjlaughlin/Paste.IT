import Cocoa

final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var settingsWindowController: SettingsWindowController?

    func install() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Paste.IT")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyTapped), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Paste", action: #selector(pasteTapped), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(settingsTapped), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Paste.IT", action: #selector(quitTapped), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    @objc private func copyTapped() {
        ActionController.shared.performCopy()
    }

    @objc private func pasteTapped() {
        ActionController.shared.performPaste()
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
