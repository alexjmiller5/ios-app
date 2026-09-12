# iOS app standard verbs (see global AGENTS.md)

app := "CHANGEME"
derived_data := env_var_or_default("IOS_DERIVED_DATA", env_var("HOME") + "/Library/Developer/Xcode/DerivedData/" + app)
test_destination := env_var_or_default("IOS_TEST_DESTINATION", "platform=iOS Simulator,name=iPhone 17")

# Regenerate the xcodeproj from project.yml.
gen:
    XCODEGEN="$(realpath "$(command -v xcodegen)")"; "$XCODEGEN" generate --spec "project.yml"

# Open Xcode for the normal edit and run loop.
dev: gen
    open "{{app}}.xcodeproj"

# Run simulator tests with local ad hoc signing so Security.framework Keychain works.
test: gen
    xcodebuild -project "{{app}}.xcodeproj" -scheme "{{app}}" \
      -derivedDataPath "{{derived_data}}" \
      -destination "{{test_destination}}" \
      CODE_SIGN_IDENTITY=- \
      CODE_SIGNING_ALLOWED=YES \
      CODE_SIGNING_REQUIRED=YES \
      test

# Build for the simulator without developer credentials.
check: gen
    xcodebuild -project "{{app}}.xcodeproj" -scheme "{{app}}" \
      -derivedDataPath "{{derived_data}}" \
      -destination "generic/platform=iOS Simulator" \
      CODE_SIGNING_ALLOWED=NO \
      build

# Build Debug with Xcode-managed development signing and install on an enrolled device.
build: gen
    #!/usr/bin/env bash
    set -euo pipefail
    : "${IOS_DEVICE_ID:?Set IOS_DEVICE_ID to an enrolled device identifier}"
    : "${IOS_DEVELOPMENT_TEAM:?Set IOS_DEVELOPMENT_TEAM to the Apple team ID}"
    derived_data="{{derived_data}}"
    xcodebuild -project "{{app}}.xcodeproj" -scheme "{{app}}" \
      -derivedDataPath "$derived_data" \
      -destination "platform=iOS,id=$IOS_DEVICE_ID" \
      -configuration Debug \
      CODE_SIGN_STYLE=Automatic \
      DEVELOPMENT_TEAM="$IOS_DEVELOPMENT_TEAM" \
      -allowProvisioningUpdates \
      build
    xcrun devicectl device install app --device "$IOS_DEVICE_ID" \
      "$derived_data/Build/Products/Debug-iphoneos/{{app}}.app"

# Build Release with an installed Ad Hoc profile and install on an enrolled device.
deploy: gen
    #!/usr/bin/env bash
    set -euo pipefail
    : "${IOS_DEVICE_ID:?Set IOS_DEVICE_ID to an enrolled device identifier}"
    : "${IOS_DEVELOPMENT_TEAM:?Set IOS_DEVELOPMENT_TEAM to the Apple team ID}"
    : "${IOS_PROFILE:?Set IOS_PROFILE to the installed Ad Hoc profile name}"
    derived_data="{{derived_data}}"
    xcodebuild -project "{{app}}.xcodeproj" -scheme "{{app}}" \
      -derivedDataPath "$derived_data" \
      -destination "platform=iOS,id=$IOS_DEVICE_ID" \
      -configuration Release \
      CODE_SIGN_STYLE=Manual \
      CODE_SIGN_IDENTITY="Apple Distribution" \
      PROVISIONING_PROFILE_SPECIFIER="$IOS_PROFILE" \
      DEVELOPMENT_TEAM="$IOS_DEVELOPMENT_TEAM" \
      clean build
    xcrun devicectl device install app --device "$IOS_DEVICE_ID" \
      "$derived_data/Build/Products/Release-iphoneos/{{app}}.app"

# Collect five minutes of logs from an enrolled device.
logs:
    #!/usr/bin/env bash
    set -euo pipefail
    : "${IOS_DEVICE_ID:?Set IOS_DEVICE_ID to an enrolled device identifier}"
    mkdir -p "logs"
    sudo log collect --device-udid "$IOS_DEVICE_ID" --last 5m \
      --output "logs/{{app}}.logarchive"
    log show "logs/{{app}}.logarchive" \
      --predicate 'process == "{{app}}"' \
      --style compact > "logs/{{app}}-logs.txt"
    echo "wrote logs/{{app}}-logs.txt"
