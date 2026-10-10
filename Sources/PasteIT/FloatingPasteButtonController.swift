import Cocoa

/// An optional, always-on-top button that triggers a typed paste without
/// ever taking keyboard focus away from whatever window the user was last
/// interacting with — e.g. an RDP/VM window — so the paste destination is
/// preserved exactly as if the hotkey had been used instead. Toggled from
/// the menu bar menu or Settings; the on/off choice is the only thing
/// persisted, not the button's screen position.
final class FloatingPasteButtonController {
    static let shared = FloatingPasteButtonController()

    private enum Keys {
        static let isEnabled = "com.pasteit.floatingButtonEnabled"
    }

    private(set) var isEnabled: Bool
    private var panel: NSPanel?

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: Keys.isEnabled)
    }

    /// Call once at launch to restore the button if it was left on last run.
    func restoreIfEnabled() {
        if isEnabled { show() }
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Keys.isEnabled)
        enabled ? show() : hide()
    }

    private func show() {
        guard panel == nil else { return }

        let size = NSSize(width: 64, height: 64)
        let panel = NonActivatingPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let button = FloatingPasteButton(frame: NSRect(origin: .zero, size: size))
        button.target = self
        button.action = #selector(buttonTapped)
        panel.contentView = button

        if let screenFrame = NSScreen.main?.visibleFrame {
            let origin = NSPoint(x: screenFrame.maxX - size.width - 32, y: screenFrame.maxY - size.height - 32)
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    @objc private func buttonTapped() {
        ActionController.shared.performPaste()
    }
}

/// A borderless, non-activating panel: clicking the button inside it must
/// never bring Paste.IT to the front or change which window has keyboard
/// focus, since the whole point is to type into whatever app — e.g. an
/// RDP/VM window — was focused right before the click. Returning false
/// from canBecomeKey/canBecomeMain is what keeps this panel out of the
/// normal key-window chain; .nonactivatingPanel in the style mask is what
/// keeps clicking it from activating the owning app at all. This is the
/// same combination macOS's own floating tool palettes (e.g. the color
/// picker) use to stay clickable without stealing focus from a document.
private final class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Small round button drawn in code (no image assets), reusing the same
/// clipboard glyph as the menu bar icon.
private final class FloatingPasteButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = frameRect.width / 2
        layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        image = MenuBarIconProvider.icon()
        image?.isTemplate = false
        contentTintColor = .white
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyUpOrDown
        toolTip = "Click to paste with Paste.IT"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
