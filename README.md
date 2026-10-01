# Wakey Wakey

A tiny macOS menu bar utility that keeps your Mac awake. Click the eye to stop it sleeping, dimming or starting the screen saver; click again to let it rest.

- **Left-click** the icon to toggle. **Right-click** for durations and preferences.
- **Timed or indefinite** — 5 minutes to 5 hours, or until you switch it off.
- **Preferences** — default duration, activate at launch, keep display on, launch at login.
- No Dock icon, no windows, no background chatter.

Requires macOS 13 Ventura or later.

## Install

Grab `WakeyWakey-x.y.z.dmg` from the [latest release](https://github.com/amcode/WakeyWakey/releases/latest), drag **Wakey Wakey** to Applications and open it. Nothing to grant — it doesn't need any permissions.

## Build from source

```bash
git clone https://github.com/amcode/WakeyWakey.git
cd WakeyWakey
./build.sh          # runs the tests, then builds dist/Wakey Wakey.app (universal)
```

Needs the Xcode Command Line Tools (`xcode-select --install`). You can also open `Package.swift` in Xcode.

## Tests

```bash
swift test
```

All the logic lives in `WakeyWakeyCore`, a plain Swift library. The IOKit assertion and the clock are injected behind protocols, so the on/off/timeout state machine, settings and menu presentation are covered by fast XCTest unit tests. CI runs them on every push.

## How it works

```
click / menu ──▶ AwakeController ──▶ SleepPreventing ──▶ IOPMAssertionCreateWithName
                       │
                  Scheduling (auto-off countdown)
```

- `AwakeController` (core) holds the on/off state and the countdown; every keystroke-free decision is here and tested.
- `IOKitSleepPreventer` (app) takes out `kIOPMAssertionTypeNoDisplaySleep` (or `NoIdleSleep` if "Keep display on" is off) and releases it on deactivate or quit.
- `MenuBarPresenter` (core) decides the icon, tooltip and "Xh Ym left" text.

The assertion is always released on quit, so the Mac never gets stuck awake.

## Releasing

```bash
git tag v1.0.0
git push origin v1.0.0
```

The `Release` workflow runs on GitHub's macOS runners: tests, universal build with the tag stamped into `Info.plist`, then a `.dmg`, `.zip` and `SHA256SUMS.txt` attached to the GitHub release with auto-generated notes. Re-run it for an existing tag from the Actions tab if needed.

### Signing and notarisation

Without secrets the build is ad-hoc signed and users see a Gatekeeper warning on first open. With a paid Apple Developer account, add these repository secrets and the next release is signed, notarised and stapled automatically:

| Secret | Value |
|---|---|
| `MACOS_CERTIFICATE_P12` | `base64 -i cert.p12 \| pbcopy` — your Developer ID Application cert + key |
| `MACOS_CERTIFICATE_PWD` | the .p12 export password |
| `APPLE_ID` | your Apple ID email |
| `APPLE_TEAM_ID` | 10-character team ID |
| `APPLE_APP_PASSWORD` | an app-specific password from appleid.apple.com |

## Project layout

```
Package.swift
Sources/
  WakeyWakeyCore/      pure logic (tested)
    AwakeController.swift
    Settings.swift        (incl. Duration)
    MenuBarPresenter.swift
    Scheduling.swift
    SleepPreventing.swift
  WakeyWakey/          the app (thin AppKit/IOKit wiring)
    main.swift
    AppDelegate.swift
    IOKitSleepPreventer.swift
Tests/WakeyWakeyCoreTests/
Info.plist
WakeyWakey.entitlements
AppIcon.iconset/
build.sh
.github/workflows/{ci,release}.yml
```

## Website

The one-page site in `docs/` is published with GitHub Pages (Settings → Pages → Deploy from a branch → `main`, folder `/docs`). The download button reads the latest release from the GitHub API, so it updates itself when you tag a new version.

## Licence

MIT — see [LICENSE](LICENSE).
