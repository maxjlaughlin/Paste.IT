# Paste.IT

A minimal, local-only macOS menu bar utility for copying and pasting text via
synthetic keystrokes instead of the system clipboard — so paste keeps working
inside remote desktop sessions and VMs that don't sync the clipboard.

## How it works

- **Copy.IT**: highlight text anywhere, then either right-click and choose
  **Services > Copy.IT**, or click the menu bar icon and choose **Copy**.
  Either path simulates Cmd+C to capture the selection, then stores it in an
  in-memory buffer inside the app (nothing is written to disk).
- **Paste**: click where you want the text, then click the menu bar icon and
  choose **Paste**. Paste.IT types the stored text out character by
  character using synthetic key events (`CGEvent`), so it works anywhere a
  real keyboard would — including inside RDP/VNC windows and VMs.
- **Hotkeys**: optional global hotkeys for Copy and Paste, configurable in
  **Settings**. There's also a toggle to make Cmd+V / Cmd+Shift+V itself
  trigger a typed paste instead of the default combo.

## Compatibility

Apple Silicon and Intel are both fully supported. There's no CPU-specific
code anywhere (just AppKit/Core Graphics APIs that exist on both), and
`Scripts/build_app.sh` compiles for `arm64` and `x86_64` separately and
merges them into one universal binary with `lipo`, so a single build of
`Paste.IT.app` runs natively on either kind of Mac. Minimum OS is macOS 12
(Monterey), which covers both architectures.

## Security notes

- 100% local. No network code, no analytics, no external dependencies.
- The copied buffer lives in memory only and is cleared when the app quits.
- Built entirely on Apple's own frameworks (AppKit / Core Graphics) — nothing
  to install beyond Xcode's command line tools.
- Requires the **Accessibility** permission, because that's what macOS
  requires for any app that posts synthetic keyboard events or listens for
  global hotkeys. This is the same permission clipboard managers, window
  tilers, and text expanders (e.g. Rectangle, Karabiner-Elements) need.
- The app is not sandboxed (`PasteIT.entitlements`), because App Sandbox is
  incompatible with system-wide keystroke injection. This means it can't be
  distributed through the Mac App Store as-is, but is normal for this class
  of utility distributed directly (e.g. via GitHub Releases + notarization).

## Building

Requires a Mac with Xcode or the Xcode Command Line Tools installed. This
can't be built or run outside macOS (no simulator/Linux path — it depends on
AppKit and Core Graphics).

**Option A — open in Xcode:**

1. `open Package.swift` — Xcode will load it as a project automatically.
2. Product > Run to test from Xcode directly (Accessibility prompts still
   apply).

**Option B — command line:**

```sh
./Scripts/build_app.sh
```

This produces a universal `build/Paste.IT.app` (arm64 + x86_64), ad-hoc code
signed, with the app icon baked in. Move it to `/Applications`, open it, and
grant Accessibility access when prompted (**System Settings > Privacy &
Security > Accessibility**).

Note: running via Xcode's Product > Run (Option A) launches the raw
executable directly, so it won't show the custom icon or Info.plist
metadata — those only apply to the `.app` produced by `build_app.sh`. Use
Option A for quick iteration, Option B for the real installable app.

## First run checklist

1. Launch the app — a clipboard icon appears in the menu bar (no Dock icon).
2. Grant Accessibility access when prompted (required for both typing
   keystrokes and listening for hotkeys).
3. Try it: select some text anywhere, click the menu bar icon > **Copy**,
   click into a destination field, click the icon > **Paste**.
4. Optionally set custom hotkeys and the Cmd+V override in **Settings**.

## Project layout

```
Package.swift                  Swift Package Manager manifest
Sources/PasteIT/
  main.swift                   App entry point
  AppDelegate.swift            Wires everything together on launch
  StatusItemController.swift   Menu bar icon + menu
  ActionController.swift       Copy / Paste actions
  ClipboardStore.swift         In-memory buffer for the copied text
  KeystrokeTyper.swift         Synthetic keystroke typing engine
  HotkeyManager.swift          Global hotkey listener (CGEventTap)
  HotkeySettings.swift         Hotkey persistence (UserDefaults, local only)
  HotkeyRecorderView.swift     "Click to record a hotkey" control
  SettingsWindowController.swift  Settings window UI
  ServiceProvider.swift        Backs the right-click "Copy.IT" Services entry
  MenuBarIconProvider.swift    Loads the menu bar glyph
  Resources/MenuBarIcon.png    Menu bar template glyph (bundled via SPM resources)
Resources/Info.plist           App bundle metadata + Services registration
Assets/AppIcon.iconset/        Source PNGs for the app icon (all required sizes)
Assets/logo.png                1024x1024 logo, for docs/marketing use
Scripts/generate_icons.py      Regenerates the icon + logo + menu bar glyph
Scripts/build_app.sh           Builds a universal binary + packages Paste.IT.app
PasteIT.entitlements           Sandbox-disabled entitlements
```

## Regenerating the icon

The icon is code-generated (no external image assets), so it's easy to
tweak. Edit `Scripts/generate_icons.py` and rerun:

```sh
pip install Pillow
python3 Scripts/generate_icons.py
```

This rewrites `Assets/AppIcon.iconset/*.png`, `Assets/logo.png`, and
`Sources/PasteIT/Resources/MenuBarIcon.png`. `build_app.sh` then compiles
those into `AppIcon.icns` via `iconutil` (macOS only) as part of the build.

## Known limitations / next steps

- Default hotkey key-code table only covers letter keys — fine for the
  default C/V bindings, extend `KeyCodeNames` if you bind other keys.
- Ad-hoc signing is fine for local use; distributing to other machines will
  need a Developer ID certificate + notarization so Gatekeeper doesn't block
  it, and so the Accessibility grant survives rebuilds.
- The right-click "Copy.IT" Services entry may need to be enabled once under
  **System Settings > Keyboard > Keyboard Shortcuts > Services** the first
  time, depending on macOS version.
