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
installs the app with `devicectl`. The provisioning profile's expiration is
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
just deploy
```

Signing material and enrollment are user-managed state. Do not commit them or
add provider-specific credential retrieval to the app repository.

macOS app? Use the `macos-app` template. TestFlight or App Store app? Use the
`appstore-app` template.
