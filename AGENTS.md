# AGENTS.md

Native iOS app (SwiftUI, iOS 17+) for Alex's own iPhone — WKWebView
wrappers, App Intents / Shortcuts companions, widgets, anything needing
native APIs. Local build, wildcard Ad Hoc signing, cable install; no CI
deploy. If it could be a website instead, use `cf-site` (see the `infra`
skill). Personal macOS apps → the `macos-app` template; apps headed for
TestFlight / the App Store → the `appstore-app` template.

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

**Signing material lives in 1Password, not the keychain.** The `Apple
Signing` vault holds the durable copies (Apple Distribution p12 in
`Apple Distribution Cert`, the wildcard profile in
`Wildcard Ad Hoc Profile`); the local keychain and profile dirs are a
disposable cache. `just signing-setup` pulls and imports them;
`just signing-cleanup` removes them again — the keychain can stay empty
between build sessions. Both must run from Alex's OWN terminal
(desktop-authed `op`): the claude-code service account cannot see the
Apple Signing vault, so Claude pastes the command for Alex instead of
running it.

Rules:

- **If Alex asks for device logs → the app must be a DEBUG install.** Release
  strips `get-task-allow`; `just logs` reads nothing from a STABLE install.
- **STABLE signing defaults to the wildcard profile** `"Alexander Wildcard
  Ad Hoc"` (`com.alexmiller.*`, expires 2027-02, installed by
  `just signing-setup` into both
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
  runs `apple-signing renew-wildcard` (1password skill, `scripts/`) — it
  rebuilds the profile via the ASC API and updates the `Apple Signing`
  vault item — then re-runs `just signing-setup` (README).
- If `just deploy` fails with "no identity found" / no Apple Distribution
  certificate, the keychain cache is empty — Alex runs `just signing-setup`.
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

- **Analytics: PostHog, OPT-IN per project** (house standard when wanted -
  every adopting app gets its OWN PostHog Cloud project). The wiring ships
  in `App/App.swift`; at scaffold time ASK Alex whether this app gets
  analytics:
  - **Personal/internal apps default to NO** - an audience of one produces
    no data worth reading. Declined → delete the `PostHog` package + both
    targets' `- package: PostHog` dependencies from `project.yml`, and
    strip the import, `posthogAPIKey` constant, and `init()` from
    `App/App.swift`.
  - Adopted → the agent CREATES a PostHog project for this app and fills
    its publishable `phc_` token into the `posthogAPIKey` constant (it is
    not a secret, so it lives in source). Management key = "AI Agent
    PostHog Personal API Key"
    (`op://4eeyrkqibibn7k4j6rz2fbzvxm/mmwl3dsd7kbsfc62osuj43ovvm/credential`),
    org `01a06053-2eab-0000-6350-0004810c636e`, US Cloud:
    ```bash
    KEY=$(op read "op://4eeyrkqibibn7k4j6rz2fbzvxm/mmwl3dsd7kbsfc62osuj43ovvm/credential")
    curl -s -X POST -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
      -d '{"name":"<project-slug>"}' \
      "https://us.posthog.com/api/organizations/01a06053-2eab-0000-6350-0004810c636e/projects/" \
      | jq -r .api_token   # → posthogAPIKey
    ```
    Free tier allows ONE project (the org's existing project - rename and
    reuse it for the first adopter instead of creating); more projects need
    Alex to add a card first - ask him, and remind him to SET BILLING
    LIMITS then (they default OFF once a card exists). Capture explicit
    named events with `PostHogSDK.shared.capture("event")`; no autocapture
    is enabled, keep it that way (event budget + narrow App Store privacy
    labels: Identifiers + Usage Data, not linked to identity, no ATT
    prompt).
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
   Also ASK Alex whether this app gets analytics (personal/internal apps
   default no → delete the PostHog wiring per the Conventions bullet);
   adopted → create this app's own PostHog project and fill `posthogAPIKey`
   in `App/App.swift` (API call in the Conventions bullet above).
2. `just gen && just check` — must build clean.
3. `just build` — DEBUG install to the phone, confirm it launches.
4. When the app graduates to daily use: Alex runs `just signing-setup` (his
   terminal, desktop-authed op), then `just deploy`. Apps with entitlements
   first need their explicit profile (README "Stable installs" section).

## Hardcoded owner defaults

Unlike the per-app CHANGEME placeholders, these values are constant across
Alex's projects and hardcoded for convenience: `DEVELOPMENT_TEAM: 467A4PRB8F`
(project.yml + justfile `team_id`), `bundleIdPrefix: com.alexmiller`
(project.yml), the justfile `device_id` default (Alex's iPhone UDID), the
`profile` default `"Alexander Wildcard Ad Hoc"`, and the 1Password
`Apple Signing` vault item names baked into `signing-setup`. The 1-year
signing flow assumes his paid Apple Developer Program membership.
