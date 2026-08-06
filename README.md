# CHANGEME

One-sentence description of the app.

## Develop

```bash
brew install xcodegen   # once per machine
just dev                # generate xcodeproj + open Xcode
just test               # unit tests (simulator, no signing)
just check              # simulator build, no signing (CI gate)
just build              # DEBUG install to device (7-day signing, logs readable)
just deploy             # STABLE install to device (1-year Ad Hoc signing)
just signing-setup      # pull cert + profile from 1Password into the keychain
just signing-cleanup    # remove them again (keychain is only a cache)
```

`just build` (DEBUG) needs Xcode signed into the Apple ID (Xcode → Settings
→ Accounts) and a valid Apple Development certificate. `just deploy` signs
manually with the Apple Distribution certificate — run `just signing-setup`
first (from a desktop-authed `op` terminal) if the keychain is empty; the
durable copies live in the 1Password `Apple Signing` vault.

macOS app? Use the `macos-app` template. TestFlight / App Store? Use
`appstore-app`.

## Stable installs (1-year signing)

`just deploy` builds Release with an Ad Hoc distribution profile so the app
survives on-device for a year without a computer. By default it uses the
team-wide wildcard profile **"Alexander Wildcard Ad Hoc"** (`com.alexmiller.*`)
— installed on demand by `just signing-setup`, no per-app setup.

### Only for apps that need entitlements

Push notifications, Apple Wallet, App Groups, HealthKit, iCloud, Sign in
with Apple, etc. are not covered by a wildcard App ID. Such apps need
one-time manual setup (Apple offers no API for this):

1. [developer.apple.com](https://developer.apple.com/account) → Identifiers →
   `+` → **explicit** App ID `com.alexmiller.<app>` → enable the needed
   capabilities.
2. Profiles → `+` → **Ad Hoc** → select that App ID, the Apple Distribution
   certificate, and the device → name it `<App> Ad Hoc Provisioning Profile`
   → download.
3. Copy the `.mobileprovision` into
   `~/Library/Developer/Xcode/UserData/Provisioning Profiles/` (Xcode 16+)
   and `~/Library/MobileDevice/Provisioning Profiles/` (named `<UUID>.mobileprovision`).
4. Point the build at it: edit the justfile `profile` var, or
   `IOS_PROFILE="<App> Ad Hoc Provisioning Profile" just deploy`.

### Regenerating the wildcard (when it expires)

Same flow, but the App ID is the existing wildcard `com.alexmiller.*` and the
profile name stays `Alexander Wildcard Ad Hoc`. Update the
`Wildcard Ad Hoc Profile` item in the 1Password `Apple Signing` vault
(`mobileprovision_base64` field) and re-run `just signing-setup`.
