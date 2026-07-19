# CLAUDE.md

Native Apple app (SwiftUI, iOS 17+ / macOS 14+). This is the template for
anything that must run as a real app on Alex's iPhone and/or Mac — WKWebView
wrappers, App Intents / Shortcuts companions, menu-bar extras, widgets,
anything needing native APIs. If it could be a website instead, use
`cf-site` (see the `infra` skill).

## Platforms: multiplatform by default, iOS-only by deletion

The app target uses XcodeGen `supportedDestinations: [iOS, macOS]`, so one
SwiftUI codebase builds for both. For an iOS-only app, delete `macOS` from
the two `supportedDestinations` lines in project.yml at scaffold time —
that's the entire opt-out; nothing else in the template is Mac-specific.

The Mac side has none of the iOS signing treadmill: `just mac` builds
Release with local Apple Development signing and installs to
`/Applications` — no Ad Hoc profile, no yearly expiry. Platform-specific
code uses `#if os(macOS)` / `#if os(iOS)`; platform-specific files can use
XcodeGen `destinationFilters` in project.yml sources if the split grows.

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
- **STABLE signing defaults to the wildcard profile** `"Alexander Wildcard
  Ad Hoc"` (`com.alexmiller.*`, expires 2027-02, installed in both
  `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` and
  `~/Library/MobileDevice/Provisioning Profiles/`). Any app with NO
  entitlements deploys with zero portal click-ops.
- **Apps that need entitlements — push notifications, Apple Wallet, App
  Groups, HealthKit, iCloud, Sign in with Apple, etc. — cannot use the
  wildcard.** They need one-time click-ops on developer.apple.com: an
  explicit App ID with the capability enabled + a dedicated Ad Hoc profile
  (steps in README). Then set `IOS_PROFILE` or the justfile `profile` var to
  that profile's name. Receptor is the worked example (App Groups).
- If `just deploy` fails with "Profile doesn't match" or "doesn't include
  the ... entitlement", the app grew an entitlement — switch it off the
  wildcard per the previous bullet. If the wildcard itself expired, Alex
  regenerates it on the portal and reinstalls (README).
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

1. `grep -rn CHANGEME .` → replace every hit (project.yml, justfile,
   ContentView.swift, Tests, README.md). App name is PascalCase; bundle id
   stays `com.alexmiller.<lowercase-app>`.
2. iOS-only app? Delete `macOS` from both `supportedDestinations` lines in
   project.yml. Keeping the Mac app costs nothing if undecided.
3. `just gen && just check` — must build clean.
4. `just build` — DEBUG install to the phone, confirm it launches.
   Multiplatform: `just mac` too.
5. When the app graduates to daily use: create the Ad Hoc profile
   (README "Stable installs" section), then `just deploy`.

## Hardcoded owner defaults

Unlike the per-app CHANGEME placeholders, these values are constant across
Alex's projects and hardcoded for convenience: `DEVELOPMENT_TEAM: 467A4PRB8F`
(project.yml + justfile `team_id`), `bundleIdPrefix: com.alexmiller`
(project.yml), the justfile `device_id` default (Alex's iPhone UDID), and the
`profile` default `"Alexander Wildcard Ad Hoc"`. The 1-year signing flow
assumes his paid Apple Developer Program membership.
