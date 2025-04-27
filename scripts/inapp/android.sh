#!/usr/bin/env bash

set -ex;

git clone https://$PACKAGE_CLONE_USER:$PACkAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-android-sdk.git;

cd reclaim-inapp-android-sdk;

# also copy changelog.md

echo $VERSION > version;

sed -i '' "s/reclaim_verifier_module = \".*\"/reclaim_verifier_module = \"$VERSION\"/" ./gradle/libs.versions.toml;

make build;

# upload to S3 bucket

# upload everything under dist/library/$VERSION/repo to S3 bucket

# COMMIT, TAG, PUSH
