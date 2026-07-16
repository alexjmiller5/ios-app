# CHANGEME

One-sentence description of the app.

## Develop

```bash
brew install xcodegen   # once per machine
just dev                # generate xcodeproj + open Xcode
just check              # simulator build, no signing (CI gate)
just build              # DEBUG install to device (7-day signing, logs readable)
```

## Stable installs (1-year signing)

`just deploy` builds Release with an Ad Hoc distribution profile so the app
survives on-device for a year without a computer. One-time manual setup per
app (Apple offers no API for this):

1. [developer.apple.com](https://developer.apple.com/account) → Identifiers →
   `+` → App ID `com.alexmiller.<app>`.
2. Profiles → `+` → **Ad Hoc** → select the App ID, the distribution
   certificate, and the device → name it exactly
   `<App> Ad Hoc Provisioning Profile` → download.
3. Double-click the `.mobileprovision` (or copy into
   `~/Library/MobileDevice/Provisioning Profiles/`).

Then `just deploy`.
