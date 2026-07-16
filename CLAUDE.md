# CLAUDE.md

Native iOS app (SwiftUI, iOS 17+). This is the template for anything that
must run as a real app on Alex's iPhone — WKWebView wrappers, App Intents /
Shortcuts companions, anything needing native APIs. If it could be a website
instead, use `cf-site` (see the `personal-infra` skill).

## Project file is generated — project.yml is the source of truth

The `.xcodeproj` is NOT committed. `project.yml` (XcodeGen) declares the
project; `just gen` regenerates the xcodeproj from it. Edit project.yml for
targets/settings/entitlements — never hand-edit the pbxproj. New source
files under `App/` are picked up automatically on the next `just gen`.

XcodeGen is a brew dependency: `brew install xcodegen`.

## Signing: Alex has the paid Apple Developer Program

Team ID: `467A4PRB8F` (personal team, $99/yr membership — NOT the free
7-day-only tier). Bundle IDs are always `com.alexmiller.<app>`. Two install
modes, same split Receptor uses:

| Mode | Recipe | Signing | Validity | Logs |
|---|---|---|---|---|
| DEBUG (dev loop) | `just build` | Automatic, Apple Development | 7 days | readable |
| STABLE (daily use) | `just deploy` | Manual, Apple Distribution + Ad Hoc profile | 1 year | stripped |

Rules:

- **If Alex asks for device logs → the app must be a DEBUG install.** Release
  strips `get-task-allow`; `just logs` reads nothing from a STABLE install.
- STABLE needs a per-app Ad Hoc provisioning profile named
  `"<App> Ad Hoc Provisioning Profile"` installed in
  `~/Library/MobileDevice/Provisioning Profiles/`. Creating it is one-time
  click-ops on developer.apple.com (see README). If `just deploy` fails with
  "Profile doesn't match", the profile is missing or expired.
- Device installs use `xcrun devicectl device install app` (wired into the
  just recipes). Alex's iPhone UDID is the justfile default; override with
  `IOS_DEVICE_ID`.
- `just check` is the CI-able correctness gate: simulator build with
  `CODE_SIGNING_ALLOWED=NO` — no signing, no device needed. `just test`
  runs the unit-test target (`Tests/`) the same way.
- Automatic signing requires Xcode to be signed into the Apple ID
  (Xcode → Settings → Accounts) — a one-time per-machine step. Without it
  `just build` fails with "No Accounts" / "No profiles found".

## Conventions

- Sources live flat under `App/`; grow `Views/`, `Models/`, `Services/`
  subfolders only when the file count demands it (Receptor's layout is the
  reference for a grown app).
- No secrets in the app bundle. Anything sensitive is entered in a Settings
  screen at runtime and stored in Keychain/App Group defaults (see
  Receptor's `Configuration.swift` for the pattern).
- Assets: `App/Assets.xcassets`; the single 1024×1024 AppIcon slot is the
  only icon you provide (iOS scales the rest).

## New-project checklist (delete this section after scaffolding)

1. `grep -rn CHANGEME .` → replace every hit (project.yml ×3, justfile,
   ContentView.swift, README.md). App name is PascalCase; bundle id stays
   `com.alexmiller.<lowercase-app>`.
2. `just gen && just check` — must build clean.
3. `just build` — DEBUG install to the phone, confirm it launches.
4. When the app graduates to daily use: create the Ad Hoc profile
   (README "Stable installs" section), then `just deploy`.
