# AGENTS.md

Native SwiftUI app for iOS 17 or newer, intended for direct installation on an
enrolled device. Use `cf-site` when a website is sufficient, `macos-app` for a
macOS app, and `appstore-app` for TestFlight or App Store distribution.

## Generated project

`project.yml` is the source of truth. The generated `.xcodeproj` and
`App/Info.plist` are ignored. Edit `project.yml`, then run `just gen`. Source
files below `App/` and `Tests/` are discovered by XcodeGen.

XcodeGen belongs in the declared developer environment. `just gen` resolves the
real executable behind `command -v xcodegen`; keep this because Nix and other
package managers may expose it through a symlink, and XcodeGen locates its
settings presets relative to the real binary.

All Xcode commands quote project and build paths. Derived data defaults to
`$HOME/Library/Developer/Xcode/DerivedData/CHANGEME`, outside the synced source
tree, and can be overridden with `IOS_DERIVED_DATA`.

## Signing and installation

- `just test` runs on `IOS_TEST_DESTINATION`, or the documented default, with
  local ad hoc signing: `CODE_SIGN_IDENTITY=-`, `CODE_SIGNING_ALLOWED=YES`, and
  `CODE_SIGNING_REQUIRED=YES`. This needs no developer account and permits real
  simulator Keychain access.
- `just check` performs an unsigned generic simulator build and needs no Apple
  account.
- `just build` requires `IOS_DEVELOPMENT_TEAM` and `IOS_DEVICE_ID`. It uses
  Xcode-managed Apple Development signing, builds Debug, and installs with
  `devicectl`.
- `just deploy` additionally requires `IOS_PROFILE`. It archives Release with
  an installed Apple Distribution identity and Ad Hoc profile, exports
  `build/<App>.ipa`, then installs it with `devicectl`.
- `IOS_INSTALL_HOST` (optional, `build` and `deploy`) is the ssh host of the
  Mac the phone is paired to. When set, the artifact is copied there and
  `devicectl` runs there, so a build host without the phone can still
  install. Unreachable host: the recipe prints the artifact path and the
  install command and exits non-zero; it never retries.
- Install order: local network first (`devicectl`, direct or through
  `IOS_INSTALL_HOST`). When that fails because the phone is unreachable, do
  not pick a fallback yourself: ask the owner whether they prefer the
  **tailnet install link** (`just ota`, one tap on the phone, any network,
  needs the `.ipa` from `just deploy`) or the **cable** (they plug the phone
  into the paired Mac, then the printed install command runs). `just ota`
  blocks while it serves; run it in the background and give the owner the
  URL it prints.
- `just run` builds Debug for `IOS_TEST_DESTINATION`, boots that simulator if
  needed, installs and launches the app, and prints `bundle=<id>
  simulator=<udid>` for simulator tooling.
- `just logs` requires `IOS_DEVICE_ID`. Device logs are readable only when the
  installed build and profile permit them.

## Verify

1. Logic: `just test` (write the test first).
2. The running app: `just run`, then drive the simulator - taps, text,
   screenshots with the accessibility tree - and read its console.
3. Hardware-only behavior (camera, microphone, push): `just build` on the
   phone, then the one check only a human can do.

Procedure, simulator tooling and gotchas: the `apple-dev` skill.

Do not add team IDs, device IDs, profile names, certificate locations, personal
bundle prefixes, or credential-provider commands to app/runtime code. Signing and
device enrollment use Xcode, Keychain Access, the Apple Developer portal, and
the environment-variable interface documented in README.md. Development
profile validity comes from the enrolled account and generated profile; do not
describe all development installs as lasting seven days.

## Conventions

- Analytics is opt-in for each scaffolded project. Ask the project owner before
  keeping it. Personal and internal apps default to no analytics. When declined,
  remove the PostHog package and both target dependencies from `project.yml`,
  then remove the PostHog import, key, and initializer from `App/App.swift`.
  When adopted, provision a dedicated PostHog project, fill its publishable key,
  keep autocapture disabled, and record only explicit named events.
- Keep source files flat under `App/` until their count justifies `Views/`,
  `Models/`, or `Services/`.
- Store no secrets in the app bundle. User-entered credentials belong in
  Keychain. Shared nonsecret preferences may use App Group defaults when the app
  has that entitlement.
- Use `App/Assets.xcassets`; supply one 1024 by 1024 AppIcon and let iOS produce
  other sizes.

## New-project checklist

Delete this section after scaffolding.

1. Replace `com.example.CHANGEME` in `project.yml` with the chosen reverse-DNS
   bundle ID. Replace every remaining `CHANGEME` with the app's PascalCase name.
2. Ask whether the app gets analytics. Personal and internal apps default to no;
   remove or configure the existing PostHog wiring as described above.
3. Run `just gen`, `just check`, and `just test`. Override
   `IOS_TEST_DESTINATION` when the default simulator is unavailable or in use.
4. Complete the README enrollment steps, then set `IOS_DEVELOPMENT_TEAM` and
   `IOS_DEVICE_ID` for `just build`.
5. For an Ad Hoc release install, provision and install the distribution
   certificate and profile through Apple, then also set `IOS_PROFILE` for
   `just deploy`.

## CI Ad Hoc signing

`.github/workflows/build-ios.yml` is manual dispatch only. It uses the project's
single `OP_SERVICE_ACCOUNT_TOKEN` GitHub secret and the approved shared Apple
Signing vault exception. `.env.tpl` and workflow refs are bootstrap manifests;
provider access stays there, outside the generic signer and app. Device selection
is the project's ENV `IOS_DEVICE_ID`, required by CI and checked against both
source and exported profiles. Never print signing values or device identifiers.

`scripts/sign-ios.py` exports exactly `App.ipa`, with temporary keychain/profile
cleanup and app-target-only `IOS_PROFILE`. Keep helper regression tests passing,
including the actual macOS certificate extraction test. Unsupported entitlement
shapes fail closed. No global provisioning profile build setting.

Every dispatch accepts a public `artifact_recipient` age key whose private
identity stays temporarily with the operator. Upload only encrypted `App.ipa.age`
with one-day retention. Public-repo artifact login is not confidentiality; the
embedded profile necessarily includes registered devices. Never upload separate
profiles, P12s, keychains or raw signing logs. Installation is a separate owner
choice; a successful workflow is not a successful phone installation.
