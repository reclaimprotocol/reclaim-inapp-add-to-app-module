#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

DIST_IOS=./dist/ios/$VERSION

(cd .ios && pod deintegrate && rm -rf Podfile.lock && rm -rf ./Pods/);
sed -i '' "s/platform :ios, '.*'/platform :ios, '14.0'/" ./.ios/Podfile;

(cd .ios && pod install)
mkdir -p build/ios
mkdir -p debug/ios/
flutter build ios-framework --output=build/ios --release --no-profile --debug; # --split-debug-info=debug/ios/v$VERSION

# Function to clean and sign frameworks (same as in sign_ios_frameworks.sh)
sign_frameworks_in_directory() {
    local frameworks_dir="$1"

    if [ ! -d "$frameworks_dir" ]; then
        echo "❌ Error: Directory not found at $frameworks_dir"
        return 1
    fi

    echo "📂 Processing frameworks in: $frameworks_dir"

    # Step 3: Sign all frameworks properly
    echo "✍️  Signing frameworks..."

    FRAMEWORK_PATTERN="$frameworks_dir/*.xcframework"

    APPLE_DEVELOPMENT_SIGNING_IDENTITY="$(security find-identity -v -p codesigning | grep "Apple Development:" | head -n 1 | awk '{print $2}')"
    if [ -z "$APPLE_DEVELOPMENT_SIGNING_IDENTITY" ]; then
        echo "Error: No Apple Development signing identity found in the keychain. To check available, try running: security find-identity -v -p codesigning | grep \"Apple Development:\""
        exit 1
    fi

    for framework_path in $FRAMEWORK_PATTERN; do
        echo "📦 Processing: $framework_path";
        local framework_name="$(basename "$framework_path")"
        codesign --timestamp -v -f --sign "$APPLE_DEVELOPMENT_SIGNING_IDENTITY" "$framework_path";
        echo $(codesign -dv "$framework_path");
        echo $(codesign -vv "$framework_path");
        echo "  ✓ Signed: $framework_name";
    done

    return 0
}

dart run scripts/prepare_ios.dart

ONLY_RELEASE_TARGETS=true

FRAMEWORK_PATTERN=""
if [ "$ONLY_RELEASE_TARGETS" != "true" ]; then
    FRAMEWORK_PATTERN="build/ios/ReclaimXCFrameworks/**/*.framework"
else
    FRAMEWORK_PATTERN="build/ios/ReclaimXCFrameworks/*.framework"
fi

echo "Converting any binary frameworks to xcframework"

for framework_path in $FRAMEWORK_PATTERN; do
    echo "Trying to make XCframework for $framework_path"
    if [ -d "$framework_path" ]; then
        framework_name=$(grep -oE -m 1 '<string>[^<]*\.framework</string>' $framework_path/Info.plist | sed -E 's/<string>(.*)\.framework<\/string>/\1/')
        
        # echo "Splitting fat into thin binaries"
        # framework_path_dir="$(dirname $framework_path)"
        # device_framework_path="$framework_path_dir/$framework_name-device.framework"
        # simulator_framework_path="$framework_path_dir/$framework_name-simulator.framework"
        # cp -r $framework_path $device_framework_path
        # cp -r $framework_path $simulator_framework_path

        # lipo $device_framework_path -thin arm64 -output $device_framework_path
        # lipo $simulator_framework_path -thin arm64 -output $simulator_framework_path

        # xcodebuild -create-xcframework \
        #     -framework $device_framework_path \
        #     -framework $simulator_framework_path \
        #     -output "${framework_path%.framework}.xcframework"

        echo "📦 Creating xcframework for $framework_path"

        xcodebuild -create-xcframework -framework "$framework_path" -output "${framework_path%.framework}.xcframework";
        rm -rf $framework_path
    fi
done

sign_frameworks_in_directory "build/ios/ReclaimXCFrameworks"

(cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks) # FAST
rm -rf $DIST_IOS
mkdir -p $DIST_IOS
mv build/ios/ReclaimXCFrameworks.tar.gz $DIST_IOS
