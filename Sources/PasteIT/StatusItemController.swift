import Cocoa

final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let recentMenu = NSMenu()
    private var settingsWindowController: SettingsWindowController?

    func install() {
        if let button = statusItem.button {
            button.image = MenuBarIconProvider.icon()
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyTapped), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Paste", action: #selector(pasteTapped), keyEquivalent: "").target = self
        menu.addItem(.separator())

        recentMenu.delegate = self
        let recentItem = NSMenuItem(title: "Recent Copies", action: nil, keyEquivalent: "")
        recentItem.submenu = recentMenu
        menu.addItem(recentItem)

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

    // MARK: - Recent Copies submenu

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === recentMenu else { return }
        menu.removeAllItems()

        let history = ClipboardStore.shared.history
        guard !history.isEmpty else {
            let empty = NSMenuItem(title: "No recent copies", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
            return
        }

        for (index, entry) in history.enumerated() {
            let item = NSMenuItem(
                title: RecentCopyFormatter.title(for: entry),
                action: #selector(pasteHistoryItem(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = index
            menu.addItem(item)
        }

        menu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clear.target = self
        menu.addItem(clear)
    }

    @objc private func pasteHistoryItem(_ sender: NSMenuItem) {
        let history = ClipboardStore.shared.history
        guard history.indices.contains(sender.tag) else { return }
        ActionController.shared.selectFromHistory(history[sender.tag])
    }

    @objc private func clearHistory() {
        ClipboardStore.shared.clear()
    }
}

private enum RecentCopyFormatter {
    static func title(for text: String, maxLength: Int = 40) -> String {
        let collapsed = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return "(empty)" }
        guard collapsed.count > maxLength else { return collapsed }
        let cutoff = collapsed.index(collapsed.startIndex, offsetBy: maxLength)
        return collapsed[..<cutoff] + "…"
    }
}
