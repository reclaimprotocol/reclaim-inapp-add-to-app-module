#!/usr/bin/env bash

set -ex;

git clone https://$PACKAGE_CLONE_USER:$PACkAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-ios-sdk.git;

cd reclaim-inapp-android-sdk;

# also copy changelog.md

echo $VERSION > Sources/ReclaimInAppSdk/Resources/ReclaimInAppSdk.version;

sed -i '' "s/RECLAIM_SDK_VERSION=\".*\"/RECLAIM_SDK_VERSION=\"$VERSION\"/" ./Scripts/download_frameworks.sh;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./Devel/podspec.prod;
sed -i '' "s/s.version           = '.*'/s.version           = '$VERSION'/" ./ReclaimInAppSdk.podspec;

./Scripts/prepare.sh

# Upload Build/$VERSION to S3 bucket

cat Devel/Package.swift.prod > Package.swift
cat Devel/podspec.prod > ReclaimInAppSdk.podspec

# COMMIT, TAG, PUSH

pod trunk push ReclaimInAppSdk.podspec --allow-warnings
