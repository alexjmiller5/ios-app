# iOS app — standard verbs (see global AGENTS.md)

app := "CHANGEME"
# Alex's iPhone; override with IOS_DEVICE_ID for another device
device_id := env_var_or_default("IOS_DEVICE_ID", "00008140-000839E42111801C")
team_id := "467A4PRB8F"

# regenerate the xcodeproj from project.yml (run after editing project.yml or adding files)
gen:
    xcodegen generate

# open in Xcode for the normal edit/run loop
dev: gen
    open {{app}}.xcodeproj

# unit tests on a simulator (no signing)
test: gen
    xcodebuild -project {{app}}.xcodeproj -scheme {{app}} \
      -destination "platform=iOS Simulator,name=iPhone 17" \
      CODE_SIGNING_ALLOWED=NO test

# simulator smoke build (no signing) — CI-able correctness check
check: gen
    xcodebuild -project {{app}}.xcodeproj -scheme {{app}} \
      -destination "generic/platform=iOS Simulator" \
      CODE_SIGNING_ALLOWED=NO build

# DEBUG build + install to device: automatic signing, 7-day validity, readable logs
build: gen
    xcodebuild -project {{app}}.xcodeproj -scheme {{app}} \
      -destination "platform=iOS,id={{device_id}}" \
      -configuration Debug -allowProvisioningUpdates build
    APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/{{app}}-*/Build/Products/Debug-iphoneos/{{app}}.app | head -1) && \
      xcrun devicectl device install app --device {{device_id}} "$APP"

# STABLE build + install: Ad Hoc distribution, 1-year validity, no logs.
# Wildcard profile covers any com.alexmiller.* app with NO entitlements;
# apps needing entitlements (push, wallet, app groups…) get their own
# explicit profile — see CLAUDE.md, then override profile here.
profile := env_var_or_default("IOS_PROFILE", "Alexander Wildcard Ad Hoc")

deploy: gen
    xcodebuild -project {{app}}.xcodeproj -scheme {{app}} \
      -destination "platform=iOS,id={{device_id}}" \
      -configuration Release \
      CODE_SIGN_STYLE="Manual" \
      CODE_SIGN_IDENTITY="Apple Distribution" \
      PROVISIONING_PROFILE_SPECIFIER="{{profile}}" \
      DEVELOPMENT_TEAM={{team_id}} \
      clean build
    APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/{{app}}-*/Build/Products/Release-iphoneos/{{app}}.app | head -1) && \
      xcrun devicectl device install app --device {{device_id}} "$APP"

# Pull signing material from the 1P `Apple Signing` vault into the login
# keychain + profile dirs. 1P is the only durable home for certs — the local
# keychain is a disposable cache; run signing-cleanup when done building.
# MUST run from Alex's own terminal (desktop-authed op): the claude-code
# service account cannot see the Apple Signing vault.
signing-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    op read "op://Apple Signing/Apple Distribution Cert/p12_base64" | base64 -d > "$tmp/dist.p12"
    security import "$tmp/dist.p12" -k ~/Library/Keychains/login.keychain-db \
      -P "$(op read "op://Apple Signing/Apple Distribution Cert/password")" \
      -T /usr/bin/codesign -T /usr/bin/security
    rm "$tmp/dist.p12"
    op read "op://Apple Signing/Wildcard Ad Hoc Profile/mobileprovision_base64" | base64 -d > "$tmp/profile.mobileprovision"
    uuid=$(security cms -D -i "$tmp/profile.mobileprovision" | plutil -extract UUID raw -o - -)
    mkdir -p "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
             "$HOME/Library/MobileDevice/Provisioning Profiles"
    cp "$tmp/profile.mobileprovision" "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/$uuid.mobileprovision"
    cp "$tmp/profile.mobileprovision" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
    echo "imported Apple Distribution identity + wildcard profile ($uuid)"

# Remove what signing-setup installed — keychain stays empty between build
# sessions; 1P remains the single durable copy.
signing-cleanup:
    #!/usr/bin/env bash
    set -euo pipefail
    hash=$(security find-identity -v -p codesigning | awk '/Apple Distribution/ {print $2; exit}') || true
    if [ -n "${hash:-}" ]; then
      security delete-identity -Z "$hash" ~/Library/Keychains/login.keychain-db
      echo "deleted Apple Distribution identity $hash"
    else
      echo "no Apple Distribution identity in the keychain"
    fi
    for dir in "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
               "$HOME/Library/MobileDevice/Provisioning Profiles"; do
      for f in "$dir"/*.mobileprovision; do
        [ -e "$f" ] || continue
        name=$(security cms -D -i "$f" 2>/dev/null | plutil -extract Name raw -o - - || true)
        if [ "$name" = "{{profile}}" ]; then rm "$f"; echo "removed $f"; fi
      done
    done

# collect last 5m of device logs into ./logs/ (requires sudo; app must be a DEBUG install)
logs:
    mkdir -p logs
    sudo log collect --device-udid {{device_id}} --last 5m --output ./logs/{{app}}.logarchive
    log show ./logs/{{app}}.logarchive \
      --predicate 'process == "{{app}}"' \
      --style compact > ./logs/{{app}}-logs.txt
    @echo "wrote logs/{{app}}-logs.txt"
