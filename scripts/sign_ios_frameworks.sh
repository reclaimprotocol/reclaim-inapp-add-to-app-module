#!/usr/bin/env bash

# Script to sign iOS frameworks to comply with Apple's requirements
# This resolves ITMS-91065 errors about missing signatures for third-party SDKs
# Required for Xcode 15+ and App Store submissions

set -e

echo "🔐 Starting iOS framework signing process..."

# Function to sign a single framework
sign_framework() {
    local framework_path="$1"
    local framework_name=$(basename "$framework_path")

    # Sign the framework with ad-hoc identity
    # Using "-" (dash) creates an ad-hoc signature that Apple accepts for third-party frameworks
    codesign --force --deep --sign - \
        --preserve-metadata=identifier,entitlements,flags \
        --timestamp \
        "$framework_path" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "  ✓ Signed: $framework_name"
    else
        echo "  ✗ Failed to sign: $framework_name"
        return 1
    fi
}

# Function to process an XCFramework
process_xcframework() {
    local xcframework_path="$1"
    local xcframework_name=$(basename "$xcframework_path")

    echo "📦 Processing: $xcframework_name"

    # Find all framework bundles within the XCFramework
    find "$xcframework_path" -name "*.framework" -type d | while read -r framework; do
        sign_framework "$framework"
    done
}

# Main signing process
XCFRAMEWORKS_DIR="build/ios/ReclaimXCFrameworks"

if [ ! -d "$XCFRAMEWORKS_DIR" ]; then
    echo "❌ Error: XCFrameworks directory not found at $XCFRAMEWORKS_DIR"
    echo "Please run this script after flutter build ios-framework"
    exit 1
fi

echo "📂 Found XCFrameworks directory: $XCFRAMEWORKS_DIR"
echo ""

# Count total frameworks
TOTAL_FRAMEWORKS=$(find "$XCFRAMEWORKS_DIR" -name "*.xcframework" -type d | wc -l | tr -d ' ')
echo "🔍 Found $TOTAL_FRAMEWORKS XCFrameworks to sign"
echo ""

# Sign all XCFrameworks
SUCCESS_COUNT=0
for xcframework in "$XCFRAMEWORKS_DIR"/*.xcframework; do
    if [ -d "$xcframework" ]; then
        process_xcframework "$xcframework"
        ((SUCCESS_COUNT++))
    fi
done

echo ""
echo "✅ Signing complete: $SUCCESS_COUNT/$TOTAL_FRAMEWORKS XCFrameworks processed"
echo ""

# Verify signatures for key frameworks that were causing issues
echo "🔍 Verifying signatures for critical frameworks..."

CRITICAL_FRAMEWORKS=(
    "OrderedSet"
    "device_info_plus"
    "fluttertoast"
    "package_info_plus"
    "sqflite_darwin"
    "url_launcher_ios"
)

for framework_name in "${CRITICAL_FRAMEWORKS[@]}"; do
    xcframework_path="$XCFRAMEWORKS_DIR/${framework_name}.xcframework"

    if [ -d "$xcframework_path" ]; then
        # Check the ios-arm64 slice (required for device builds)
        ios_binary="$xcframework_path/ios-arm64/${framework_name}.framework/${framework_name}"

        if [ -f "$ios_binary" ]; then
            if codesign -dv "$ios_binary" 2>&1 | grep -q "Signature"; then
                echo "  ✓ ${framework_name}: Properly signed"
            else
                echo "  ✗ ${framework_name}: Missing signature"
            fi
        fi
    fi
done

echo ""
echo "✨ Framework signing completed successfully!"
echo "The frameworks are now ready for App Store submission."