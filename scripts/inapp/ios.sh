#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

mkdir -p inapp-sdks;

cd inapp-sdks;

export WORK_DIR="$(pwd)";

export IOS_CLONE_DIR="$WORK_DIR/build/ios-sdk";

if [[ -z "$PACKAGE_CLONE_USER" ]]; then
    git clone git@github.com:reclaimprotocol/reclaim-inapp-ios-sdk.git $IOS_CLONE_DIR;
else
    git clone https://$PACKAGE_CLONE_USER:$PACKAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-ios-sdk.git $IOS_CLONE_DIR;
fi

cd $IOS_CLONE_DIR;

DEFAULT_CHANGELOG="## $VERSION

* Updates inapp module dependency to $VERSION
"

EFFECTIVE_CHANGELOG="${NEXT_CHANGELOG:-$DEFAULT_CHANGELOG}"

# copy current changelog.md
cat CHANGELOG.md > temp;
# enter new changes
echo "$EFFECTIVE_CHANGELOG" > CHANGELOG.md
# append old changelog
cat temp >> CHANGELOG.md;
# remove copy
rm temp;

echo $VERSION > Sources/ReclaimInAppSdk/Resources/InAppSdk.version;

sed -i '' "s/RECLAIM_SDK_VERSION=\".*\"/RECLAIM_SDK_VERSION=\"$VERSION\"/" ./Scripts/download_frameworks.sh;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./Devel/podspec.prod;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./ReclaimInAppSdk.podspec;
sed -i '' "s/pod 'ReclaimInAppSdk', :git => 'https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git', :tag => '.*'/pod 'ReclaimInAppSdk', :git => 'https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git', :tag => '$VERSION'/" ./README.md;
sed -i '' "s/.package(url: \"https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git\", from: \".*\")/.package(url: \"https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git\", from: \"$VERSION\")/" ./README.md;
sed -i '' "s/Currently the latest version is \`.*\`/Currently the latest version is \`$VERSION\`/" ./README.md;
sed -i '' "s/pod 'ReclaimInAppSdk', :git => 'https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git', :tag => '.*'/pod 'ReclaimInAppSdk', :git => 'https:\/\/github.com\/reclaimprotocol\/reclaim-inapp-ios-sdk.git', :tag => '$VERSION'/" ./Examples/SwiftUIWithPodExample/Podfile;
sed -i '' "s/pod 'ReclaimInAppSdk', '~> .*'/pod 'ReclaimInAppSdk', '~> $VERSION'/" ./Examples/SwiftUIWithPodExample/Podfile;

echo "
RECLAIM_APP_ID = ${RECLAIM_CONSUMER_APP_ID}
RECLAIM_APP_SECRET = ${RECLAIM_CONSUMER_APP_SECRET}
RECLAIM_PROVIDER_ID = example

" > Examples/SwiftUIWithPodExample/BaseConfig.xcconfig;

cp Examples/SwiftUIWithPodExample/BaseConfig.xcconfig Examples/SwiftUIExample/BaseConfig.xcconfig;

./Scripts/prepare.sh

# Function to clean and sign frameworks (same as in sign_ios_frameworks.sh)
sign_frameworks_in_directory() {
    local frameworks_dir="$1"

    if [ ! -d "$frameworks_dir" ]; then
        echo "❌ Error: Directory not found at $frameworks_dir"
        return 1
    fi

    echo "📂 Processing frameworks in: $frameworks_dir"

    # Step 1: Remove any invalid XCFramework-level signatures
    echo "🧹 Removing invalid signatures..."
    find "$frameworks_dir" -maxdepth 2 -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true

    # Step 2: Remove existing framework signatures (they become invalid when moved/repackaged)
    find "$frameworks_dir" -name "*.framework" -type d | while read -r framework; do
        rm -rf "$framework/_CodeSignature" 2>/dev/null || true
    done

    # Step 3: Sign all frameworks properly
    echo "✍️  Signing frameworks..."
    local signed_count=0
    local failed_count=0

    find "$frameworks_dir" -name "*.xcframework" -type d | while read -r xcframework; do
        local xcframework_name=$(basename "$xcframework")
        echo "📦 Processing: $xcframework_name"

        # Sign each framework within the XCFramework
        find "$xcframework" -name "*.framework" -type d | while read -r framework; do
            local framework_name=$(basename "$framework")

            # Use --deep to sign embedded content and --force to replace any existing signature
            # Use --timestamp=none to avoid timestamp server issues during build
            if codesign --force --deep --sign - \
                --preserve-metadata=identifier,entitlements,flags \
                --timestamp=none \
                "$framework" 2>/dev/null; then
                echo "  ✓ Signed: $framework_name"
                ((signed_count++))
            else
                echo "  ✗ Failed to sign: $framework_name"
                ((failed_count++))
            fi
        done
    done

    return 0
}

# Sign frameworks after they're extracted and before zipping
echo "🔐 Signing frameworks before packaging..."
sign_frameworks_in_directory "Build/Cache/ReclaimXCFrameworks"
echo "✅ Framework signing completed"

echo "Upload $IOS_CLONE_DIR/Build/$VERSION to S3 bucket, make sure $VERSION/ directory exists, and $VERSION/ should have the files and not $VERSION/"

cat Devel/Package.swift.prod > Package.swift
cat Devel/podspec.prod > ReclaimInAppSdk.podspec

# COMMIT, TAG, PUSH

echo "Test, then 'git tag -a $VERSION -m $VERSION; git push; git push --tags', and then finally run the following to deploy to Cocoapods (will be available for use in ~1 hour):"
echo "pod trunk push ReclaimInAppSdk.podspec --allow-warnings"

cd $WORK_DIR;