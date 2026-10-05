# CHANGEME

One-sentence description of the app.

## Develop

Xcode and XcodeGen are required. Keep both in the machine's declared developer
environment. The generated project and derived build products do not belong in
the source tree.

```bash
just dev    # generate the project and open Xcode
just test   # run signed simulator tests, including Keychain-dependent tests
just check  # unsigned simulator build
just run    # Debug build, install and launch on the test simulator
```

`just gen` resolves XcodeGen's real executable so installations exposed through
a package-manager symlink can still find their settings presets. Build products
default to `$HOME/Library/Developer/Xcode/DerivedData/CHANGEME`. Set
`IOS_DERIVED_DATA` to another absolute path when needed. Set
`IOS_TEST_DESTINATION` to any installed simulator destination if the default is
not available.

Simulator tests use Xcode's local ad hoc signature and need no Apple developer
account. The signature allows tests to exercise services such as Keychain.

## Install on a device

Use Apple's supported enrollment flow before the first device build:

1. Sign in under Xcode Settings, Accounts and select the development team for
   the app target under Signing & Capabilities.
2. Connect the device, trust the Mac, enable Developer Mode when iOS requests
   it, and let Xcode register the device.
3. Find the team ID in the Apple developer account and the device identifier
   with `xcrun devicectl list devices`.

Then provide the installation-specific values at runtime:

```bash
IOS_DEVELOPMENT_TEAM="<team-id>" \
IOS_DEVICE_ID="<device-id>" \
just build
```

`just build` uses Xcode-managed Apple Development signing, builds Debug, and
installs the app with `devicectl`. Building on a Mac the phone is not paired
to? Set `IOS_INSTALL_HOST=<ssh host of the paired Mac>` and the artifact is
copied there and installed from there (the phone on the same Wi-Fi as that
Mac is enough after the first cable pairing). The provisioning profile's expiration is
determined by the enrolled Apple account and profile. A free Personal Team may
produce short-lived profiles; paid developer teams are governed by their own
profile expiration dates.

## Ad Hoc release install

`just deploy` builds Release with manual Ad Hoc signing. In the Apple Developer
portal, register the App ID and device, create an Ad Hoc provisioning profile,
and download it. Install the distribution certificate with Keychain Access and
install the profile with Xcode or by opening the downloaded profile. Apps that
use capabilities such as App Groups, HealthKit, iCloud, Wallet, push
notifications, or Sign in with Apple need an explicit App ID with those
capabilities enabled.

```bash
IOS_DEVELOPMENT_TEAM="<team-id>" \
IOS_DEVICE_ID="<device-id>" \
IOS_PROFILE="<installed-profile-name>" \
just deploy          # writes build/<App>.ipa, then installs it
```

## When the phone is not on the local network

`devicectl` finds the phone through local-network discovery, so an install
fails on networks that isolate clients (train, hotel, guest Wi-Fi) or when
the phone is somewhere else. Two ways through, the owner picks:

- **Tailnet install link**: `just ota` serves `build/<App>.ipa` on this
  machine's Tailscale name over HTTPS and prints a URL. Open it in Safari on
  the phone (Tailscale connected), tap Install. Works on any network,
  including cellular; needs an Ad Hoc `.ipa` (from `just deploy`), HTTPS
  certificates enabled on the tailnet, and one tap. The page is temporary
  (`OTA_TTL` seconds, default 900).
- **Cable**: plug the phone into the Mac it is paired to and run the install
  command the failed recipe printed.

Signing material and enrollment are operator-managed state. Never commit them.
Credential retrieval belongs only in the CI workflow or bootstrap manifest; the
app and signing helper accept environment variables.

macOS app? Use the `macos-app` template. TestFlight or App Store app? Use the
`appstore-app` template.

## Manual CI Ad Hoc build

The `Build iOS Ad Hoc` workflow archives and verifies a Release IPA without
installing it or publishing an App Store release. Replace `CHANGEME` with the
app PascalCase name and `PROJECT_TITLE` with its Title (spaces preserved) in
workflow/bootstrap vault and ENV item references when scaffolding. Bootstrap the project with
`op-project-bootstrap .env.tpl --repo <owner>/<repo>`. The only GitHub secret is
`OP_SERVICE_ACCOUNT_TOKEN`, a project CI service account authorized for its own
vault and the existing shared Apple Signing exception.

Durable signing material lives in the **Apple Signing** vault: **Apple
Distribution Cert** holds `p12_base64` and `password`; **Wildcard Ad Hoc Profile**
holds `mobileprovision_base64`. The project ENV item's `IOS_DEVICE_ID` selects a
registered device. CI refuses a profile that does not include it. Shared signing
rotation affects consumers of that certificate/profile; project credentials
remain independently owned. Capabilities requiring an explicit profile need
an appropriate profile reference instead of the wildcard profile.

Create a fresh age identity locally for each dispatch, outside the repository:

```bash
umask 077
age-keygen -o <private-identity-path>
age-keygen -y <private-identity-path>
gh workflow run build-ios.yml --ref <reviewed-branch-or-tag> -f artifact_recipient=<public-age-recipient>
```

Keep the private identity locally until download and decryption finish. Never
send it to GitHub, commit it, or store a permanent encryption key in 1Password.
The workflow input is only the public recipient. Download the artifact from the
specific successful run, then decrypt:

```bash
gh run download <run-id> --dir <private-download-directory>
age --decrypt -i <private-identity-path> -o <private-output-path>/App.ipa <downloaded-App.ipa.age>
```

GitHub artifacts in public repositories may be downloadable by other signed-in
users. Encryption provides confidentiality; login alone does not. CI uploads
only `App.ipa.age`, retained for one day. An IPA necessarily embeds its profile,
including registered device identifiers. No standalone profile, certificate,
private key, keychain, archive or raw build log is uploaded. Handle the decrypted
IPA privately, confirm its SHA256 matches the successful run, and retain only
what installation requires. Delete the temporary private identity after a
verified download/decryption. Deleting the artifact early after receipt is also
appropriate.

The helper checks profile expiry, selected-device membership, distribution
private-key identity, exported bundle/team/profile UUID, signature, leaf
certificate and signed entitlement authorization. It supports boolean/string
claims and arrays of those; other entitlement shapes fail closed. Xcode signing
material is confined to a temporary keychain/profile, restored and removed on
success or failure. Runner destruction is the fallback for a hard kill.
`IOS_PROFILE` applies only to the app target, preserving package resource builds.

For local helper use, provide `IOS_CERTIFICATE_P12_BASE64`,
`IOS_CERTIFICATE_PASSWORD`, `IOS_PROFILE_BASE64`, and optionally `IOS_DEVICE_ID`,
then run `python3 scripts/sign-ios.py --project CHANGEME.xcodeproj --scheme
CHANGEME --output <private-output-directory>`. It writes `App.ipa` and refuses to
overwrite it. CI requires the selected device even though the generic helper
can validate a profile without one. Run `python3 scripts/sign_ios_test.py` and
`python3 scripts/ios_workflow_test.py` for signing regressions.

Install the verified IPA through `devicectl` or the existing supported OTA
helper. CI completion is not confirmation that the phone installed the update.
