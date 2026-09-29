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

Signing material and enrollment are user-managed state. Do not commit them or
add provider-specific credential retrieval to the app repository.

macOS app? Use the `macos-app` template. TestFlight or App Store app? Use the
`appstore-app` template.
