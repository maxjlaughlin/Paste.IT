# Paste.IT

A minimal, local-only macOS menu bar utility that pastes the system
clipboard's text via synthetic keystrokes instead of a normal paste — so
paste keeps working inside remote desktop sessions and VMs that don't sync
the clipboard. Copying is just the normal system clipboard; Paste.IT doesn't
touch it or keep any history of its own.

## How it works

- **Paste**: copy something normally (Cmd+C, right-click Copy, whatever),
  click where you want it, then trigger a paste one of these ways:
  - the menu bar icon's **Paste** item,
  - the configurable global **Paste hotkey** (see Settings),
  - right-click where you want the text and choose **Services > Paste with
    Paste.IT** (wherever macOS's Services menu is supported — most native
    text fields), or
  - the optional **floating Paste.IT button** — toggle it on from the menu
    bar menu or Settings, then click it from anywhere without shifting
    keyboard focus off the window you're pasting into, so a VM/RDP window
    stays the paste destination even though the button floats above it.

  However it's triggered, Paste.IT reads whatever is currently on the system
  clipboard and types it out character by character using synthetic key
  events (`CGEvent`), so it works anywhere a real keyboard would — including
  inside RDP/VNC windows and VMs.
- **Hotkey**: an optional global hotkey for Paste, configurable in
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
- Keeps no clipboard history or buffer of its own — always reads directly
  from the system clipboard at the moment Paste is triggered, and nothing is
  ever written to disk.
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

## Using alongside other clipboard managers (e.g. CopyClip)

Paste.IT doesn't keep any clipboard history of its own — it always types out
whatever is currently on the system clipboard — so it runs alongside other
clipboard managers with no conflict there. The one setting to watch is the
**"Use ⌘V / ⌘⇧V to trigger typed paste"** override in Settings: when enabled
it intercepts *every* Cmd+V system-wide, including synthetic ones other apps
send (e.g. CopyClip pasting a selected history item), and replaces them with
Paste.IT's own typed paste. Leave that toggle off and use Paste.IT's
dedicated hotkey instead if you want both tools running side by side.

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

### Avoiding repeated Accessibility prompts while iterating

Ad-hoc signing (the default) derives the app's signing identity from its own
binary contents, so it's different on every rebuild. macOS ties Accessibility
trust to that identity, so each rebuild looks like a brand-new app — you'll
be asked to re-grant Accessibility every time, and if the old grant lingers
stale in System Settings, Copy/Paste can silently stop working (synthetic
keystrokes fail quietly when the running binary isn't actually trusted).

To fix a stuck/stale grant immediately:

```sh
tccutil reset Accessibility com.pasteit.app
```

Then relaunch the app and grant Accessibility fresh.

To stop this from recurring on every rebuild, sign with a stable local
identity instead of ad-hoc: open **Keychain Access > Certificate Assistant >
Create a Certificate…**, name it anything, set Identity Type to **Self Signed
Root** and Certificate Type to **Code Signing**, then build with:

```sh
DEVELOPER_ID_APPLICATION="Your Cert Name" ./Scripts/build_app.sh
```

Since that identity doesn't change between builds, Accessibility trust
persists across rebuilds. (This is unrelated to the real Developer ID
certificate used for distribution below — `build_app.sh` only applies
hardened-runtime signing when the identity string actually starts with
`Developer ID Application:`.)

## Distributing outside your own Mac (code signing & notarization)

An ad-hoc signed build (the default) only runs on the Mac that built it —
Gatekeeper blocks it everywhere else with an "unidentified developer"
warning. To hand `Paste.IT.app` to someone else, you need Apple to sign
off on it via a **Developer ID** certificate and **notarization**. This is
also the relevant step for the SOC 2 / compliance conversation: it proves
the binary a customer runs is exactly the one you built, untampered.

**1. Enroll in the Apple Developer Program** (if you haven't already) —
[developer.apple.com/programs](https://developer.apple.com/programs/),
$99/year, tied to your Apple ID.

**2. Create a "Developer ID Application" certificate** — this is the
certificate type for software distributed outside the Mac App Store
(different from the "Apple Development" certificate used for testing).
Easiest path:
   - Open Xcode > Settings > Accounts, add your Apple ID if it's not there.
   - Select your team, click **Manage Certificates…**, click **+**, choose
     **Developer ID Application**. Xcode generates the key pair and
     installs the certificate in your login keychain for you.
   - (Manual alternative: Keychain Access > Certificate Assistant > Request
     a Certificate From a Certificate Authority, upload the CSR at
     [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates/list),
     download and double-click the issued certificate to install it.)

**3. Find your Team ID** — developer.apple.com > Account > Membership
details, a 10-character string like `A1B2C3D4E5`.

**4. Find your exact signing identity string** — run:
   ```sh
   security find-identity -v -p codesigning
   ```
   Look for a line like `"Developer ID Application: Your Name (A1B2C3D4E5)"`
   — that full string is what you'll pass as `DEVELOPER_ID_APPLICATION`.

**5. Set up notarization credentials, once** — create an app-specific
password at [appleid.apple.com](https://appleid.apple.com) (Sign-In and
Security > App-Specific Passwords), then store it in your Keychain so it
never needs to touch a script or the repo:
   ```sh
   xcrun notarytool store-credentials "PasteIT-Notary" \
     --apple-id "you@example.com" \
     --team-id "A1B2C3D4E5" \
     --password "the-app-specific-password"
   ```
   (For CI/automation later, an App Store Connect API key is the more
   robust option — App Store Connect > Users and Access > Integrations —
   but an app-specific password is simplest for manual releases.)

**6. Build, sign, and notarize:**
   ```sh
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (A1B2C3D4E5)" \
     ./Scripts/build_app.sh
   ./Scripts/notarize.sh
   ```
   `build_app.sh` signs with the hardened runtime enabled (required for
   notarization); `notarize.sh` submits the build to Apple, waits for
   approval, and staples the ticket so Gatekeeper accepts it even offline.

Re-run both scripts for every release — the signing identity doesn't
expire per-build, but Apple notarizes each binary individually.

## First run checklist

1. Launch the app — a clipboard icon appears in the menu bar (no Dock icon).
2. Grant Accessibility access when prompted (required for both typing
   keystrokes and listening for hotkeys).
3. Try it: copy some text normally (Cmd+C), click into a destination field,
   then click the menu bar icon > **Paste**.
4. Optionally set a custom Paste hotkey, the Cmd+V override, and the
   floating button in **Settings**.

## Project layout

```
Package.swift                  Swift Package Manager manifest
Sources/PasteIT/
  main.swift                   App entry point
  AppDelegate.swift            Wires everything together on launch
  StatusItemController.swift   Menu bar icon + menu
  ActionController.swift       Paste action (reads the system clipboard)
  KeystrokeTyper.swift         Synthetic keystroke typing engine
  HotkeyManager.swift          Global hotkey listener (CGEventTap)
  HotkeySettings.swift         Hotkey persistence (UserDefaults, local only)
  HotkeyRecorderView.swift     "Click to record a hotkey" control
  SettingsWindowController.swift  Settings window UI
  FloatingPasteButtonController.swift  Optional always-on-top paste button
  ServiceProvider.swift        Backs the right-click "Paste with Paste.IT" Services entry
  MenuBarIconProvider.swift    Loads the menu bar glyph
  Resources/MenuBarIcon.png    Menu bar template glyph (bundled via SPM resources)
Resources/Info.plist           App bundle metadata + Services registration
Assets/AppIcon.iconset/        Source PNGs for the app icon (all required sizes)
Assets/logo.png                1024x1024 logo, for docs/marketing use
Scripts/generate_icons.py      Regenerates the icon + logo + menu bar glyph
Scripts/build_app.sh           Builds a universal binary + packages Paste.IT.app
Scripts/notarize.sh            Submits a Developer ID build to Apple for notarization
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
  default V binding, extend `KeyCodeNames` if you bind another key.
- Ad-hoc builds only run on the Mac that built them; see "Distributing
  outside your own Mac" above for Developer ID signing + notarization.
- The right-click "Paste with Paste.IT" Services entry may need to be
  enabled once under **System Settings > Keyboard > Keyboard Shortcuts >
  Services** the first time, depending on macOS version — and only appears
  where the focused view supports Services at all (most native Cocoa text
  fields). A VM/RDP window's rendered screen typically won't offer it; use
  the hotkey or floating button there instead.
- The floating button's position isn't remembered across toggles — it
  reappears in the top-right corner of the main screen each time it's shown.
