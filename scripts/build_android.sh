#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

DIST_ANDROID=./dist/android/$VERSION

mkdir -p debug/android/

KOTLIN_VERSION="2.0.21"

COMPILE_SDK="36"

## Downgrade the Kotlin version in your settings.gradle to the lowest Kotlin version we intend to support.
sed -i '' "s/id \"org\.jetbrains\.kotlin\.android\" version \".*\"/id \"org\.jetbrains\.kotlin\.android\" version \"$KOTLIN_VERSION\"/" ./.android/settings.gradle;

## Pin compileSdk for every project that produces a published AAR.
##
## This MUST stay at 36. compileSdk is baked into each AAR as minCompileSdk, and consumers fail
## checkReleaseAarMetadata unless they compile against at least that level. Compiling against 37
## requires AGP 9.1.1+, which no stable React Native release ships - so a 37 here makes the whole
## distribution uninstallable for RN hosts.
##
## Keeping 36 requires the Dart-side plugin pins in reclaim_inapp_sdk's pubspec.yaml
## (flutter_secure_storage <11, permission_handler <13); their newer majors build at 37 and the
## Flutter Gradle plugin refuses a plugin whose compileSdk exceeds the project's.
##
## :flutter is the project that fails checkDebugAarMetadata, so Flutter/build.gradle must be
## patched too - not just app/build.gradle.
sed -i '' "s/^\( *\)compileSdk = .*/\1compileSdk = $COMPILE_SDK/" \
    ./.android/build.gradle \
    ./.android/app/build.gradle \
    ./.android/Flutter/build.gradle;

# Force kotlin compiler version
# Use python for robust multi-line string replacement
python3 - <<EOF
import sys
import os

file_path = "./.android/build.gradle"

# The exact block you want to find
search_text = """allprojects {
    repositories {
        google()
        mavenCentral()
    }
}"""

# The block you want to replace it with
replace_text = """allprojects {
    repositories {
        google()
        mavenCentral()
    }

    configurations.all {
        resolutionStrategy {
            // Force the standard library to match your compiler version
            force "org.jetbrains.kotlin:kotlin-stdlib:$KOTLIN_VERSION"
            force "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$KOTLIN_VERSION"
            force "org.jetbrains.kotlin:kotlin-stdlib-jdk8:$KOTLIN_VERSION"
        }
    }
}"""

try:
    with open(file_path, 'r') as f:
        content = f.read()

    # Check if the replacement is already there to prevent duplication
    if "force \"org.jetbrains.kotlin:kotlin-stdlib:$KOTLIN_VERSION\"" in content:
        print(f"Skipping {file_path}: Fix already applied.")
        sys.exit(0)

    # Perform the replacement
    if search_text in content:
        new_content = content.replace(search_text, replace_text)
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Success: Patched {file_path}")
    else:
        print(f"Warning: Could not find the exact 'allprojects' block in {file_path}.")
        print("Ensure the indentation (spaces) matches exactly.")
        sys.exit(1)

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)
EOF

## Publish a dependency constraint that lifts Cronet to 143.7445.0.
##
## cronet_http pulls play-services-cronet:18.1.1, whose POM pulls org.chromium.net:cronet-api:141.7340.3.
## In 141 Cronet split cronet-shared out of cronet-api, but BOTH AARs ship a stub manifest declaring
## package="org.chromium.net". AGP derives a library's namespace from that attribute, so consumers hit
## ENFORCE_UNIQUE_PACKAGE_NAME and :app:processDebugMainManifest fails with
## "Namespace 'org.chromium.net' is used in multiple modules and/or libraries".
##
## Cronet fixed this in 143.7445.0 - namespaces are now org.chromium.net.cronet_api and .cronet_shared -
## but no play-services-cronet release points at 143 yet, so we constrain it here. Constraints declared
## on :flutter are published into flutter_{debug,profile,release} Gradle module metadata, so every
## consumer (React Native, Capacitor, native Android) picks up 143 without having to set
## android.uniquePackageNames=false, which AGP 10.0 stops honouring anyway.
##
## Revisit when play-services-cronet ships a release resolving to cronet-api >= 143.7445.0.
CRONET_VERSION="143.7445.0"

if grep -q "org.chromium.net:cronet-api" ./.android/Flutter/build.gradle; then
    echo "Skipping cronet constraint: already applied."
else
    cat >> ./.android/Flutter/build.gradle <<CRONET_EOF

dependencies {
    constraints {
        api("org.chromium.net:cronet-api:$CRONET_VERSION") {
            because "cronet-api/cronet-shared 141.x both declare namespace org.chromium.net, breaking AGP manifest merging"
        }
        api("org.chromium.net:cronet-shared:$CRONET_VERSION") {
            because "keep cronet-shared in lockstep with cronet-api"
        }
    }
}
CRONET_EOF
    echo "Success: appended cronet constraint to ./.android/Flutter/build.gradle"
fi

flutter build aar --build-number=$VERSION; # --split-debug-info=debug/android/v$VERSION
rm -rf $DIST_ANDROID
mkdir -p $DIST_ANDROID
mv build/host/outputs/repo/ $DIST_ANDROID/repo

## Fail the build if any published AAR demands a compileSdk higher than COMPILE_SDK.
## Consumers run checkReleaseAarMetadata against this value, so a single AAR over the line
## breaks every host app that can't compile that high (see the COMPILE_SDK note above).
set +x
violations=""
while IFS= read -r aar; do
    found=$(unzip -p "$aar" META-INF/com/android/build/gradle/aar-metadata.properties 2>/dev/null \
        | sed -n 's/^minCompileSdk=//p')
    if [ -n "$found" ] && [ "$found" -gt "$COMPILE_SDK" ]; then
        violations="$violations\n  $found  $aar"
    fi
done <<< "$(find $DIST_ANDROID/repo -name '*.aar')"

if [ -n "$violations" ]; then
    echo "ERROR: AARs declare minCompileSdk above $COMPILE_SDK:" >&2
    printf "$violations\n" >&2
    echo "" >&2
    echo "Pin the offending plugin to a version that builds at compileSdk <= $COMPILE_SDK" >&2
    echo "in reclaim_inapp_sdk's pubspec.yaml, then rebuild." >&2
    exit 1
fi
echo "OK: all AARs in $DIST_ANDROID/repo declare minCompileSdk <= $COMPILE_SDK"
set -x
