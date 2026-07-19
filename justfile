# Apple app — standard verbs (see global CLAUDE.md)

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

# build + install the Mac app to /Applications (multiplatform targets only;
# local Apple Development signing — no Ad Hoc profile, no yearly expiry)
mac: gen
    xcodebuild -project {{app}}.xcodeproj -scheme {{app}} \
      -destination "platform=macOS" \
      -configuration Release -allowProvisioningUpdates build
    APP=$(ls -td ~/Library/Developer/Xcode/DerivedData/{{app}}-*/Build/Products/Release/{{app}}.app | head -1) && \
      rm -rf /Applications/{{app}}.app && ditto "$APP" /Applications/{{app}}.app
    @echo "installed /Applications/{{app}}.app"

# collect last 5m of device logs into ./logs/ (requires sudo; app must be a DEBUG install)
logs:
    mkdir -p logs
    sudo log collect --device-udid {{device_id}} --last 5m --output ./logs/{{app}}.logarchive
    log show ./logs/{{app}}.logarchive \
      --predicate 'process == "{{app}}"' \
      --style compact > ./logs/{{app}}-logs.txt
    @echo "wrote logs/{{app}}-logs.txt"
