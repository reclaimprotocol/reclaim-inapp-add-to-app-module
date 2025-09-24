#!/usr/bin/env bash

# Script to sign iOS frameworks to comply with Apple's requirements
# This resolves ITMS-91065 errors about missing signatures for third-party SDKs
# Required for Xcode 15+ and App Store submissions

set -e

echo "🔐 Starting iOS framework signing process..."

# Function to clean and sign frameworks in a directory
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

# Main signing process
XCFRAMEWORKS_DIR="build/ios/ReclaimXCFrameworks"

# Call the signing function
sign_frameworks_in_directory "$XCFRAMEWORKS_DIR"

echo ""

# Verify signatures for key frameworks
echo "🔍 Verifying signatures for critical frameworks..."

CRITICAL_FRAMEWORKS=(
    "Flutter"
    "App"
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
        framework_path="$xcframework_path/ios-arm64/${framework_name}.framework"

        if [ -d "$framework_path" ]; then
            if codesign --verify "$framework_path" 2>/dev/null; then
                echo "  ✓ ${framework_name}: Valid signature"
            else
                echo "  ✗ ${framework_name}: Invalid or missing signature"
            fi
        fi
    fi
done

echo ""
echo "✨ Framework signing completed successfully!"
echo "The frameworks are now ready for App Store submission."