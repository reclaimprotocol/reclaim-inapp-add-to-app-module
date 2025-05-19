#!/usr/bin/env bash

set -ex;

export WORK_DIR="$(pwd)";

export IOS_CLONE_DIR="$WORK_DIR/build/ios-sdk";

git clone https://$PACKAGE_CLONE_USER:$PACkAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-ios-sdk.git $IOS_CLONE_DIR;

cd $IOS_CLONE_DIR;

# also copy changelog.md
echo "
## $VERSION

* Updates inapp module dependency to $VERSION

" > CHANGELOG.md

echo $VERSION > Sources/ReclaimInAppSdk/Resources/ReclaimInAppSdk.version;

sed -i '' "s/RECLAIM_SDK_VERSION=\".*\"/RECLAIM_SDK_VERSION=\"$VERSION\"/" ./Scripts/download_frameworks.sh;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./Devel/podspec.prod;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./ReclaimInAppSdk.podspec;

./Scripts/prepare.sh

echo "Upload $IOS_CLONE_DIR/Build/$VERSION to S3 bucket, make sure $VERSION/ directory exists, and $VERSION/ should have the files and not $VERSION/"

cat Devel/Package.swift.prod > Package.swift
cat Devel/podspec.prod > ReclaimInAppSdk.podspec

# COMMIT, TAG, PUSH

echo "Test, then 'git tag -a $VERSION -m $VERSION; git push; git push --tags', and then finally run the following to deploy to Cocoapods (will be available for use in ~1 hour):"
echo "pod trunk push ReclaimInAppSdk.podspec --allow-warnings"

cd $WORK_DIR;