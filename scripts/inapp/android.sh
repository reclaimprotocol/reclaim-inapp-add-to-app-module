#!/usr/bin/env bash

set -ex;

export WORK_DIR="$(pwd)";

export ANDROID_CLONE_DIR="$WORK_DIR/build/android-sdk";

git clone https://$PACKAGE_CLONE_USER:$PACkAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-android-sdk.git $ANDROID_CLONE_DIR;

cd $ANDROID_CLONE_DIR;

# also copy changelog.md
echo "
## $VERSION

* Updates inapp module dependency to $VERSION

" > CHANGELOG.md

echo $VERSION > version;

sed -i '' "s/reclaim_verifier_module = \".*\"/reclaim_verifier_module = \"$VERSION\"/" ./gradle/libs.versions.toml;

make build;

# test & upload to S3 bucket
echo "test & upload everything under $ANDROID_CLONE_DIR/dist/library/$VERSION/repo to S3 bucket"

# COMMIT, TAG, PUSH

cd $WORK_DIR;