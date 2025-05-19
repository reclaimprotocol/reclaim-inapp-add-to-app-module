#!/usr/bin/env bash

set -ex;

export WORK_DIR="$(pwd)";

export ANDROID_CLONE_DIR="$WORK_DIR/build/android-sdk";

if [[ -z "$PACKAGE_CLONE_USER" ]]; then
    git clone git@github.com:reclaimprotocol/reclaim-inapp-android-sdk.git $ANDROID_CLONE_DIR;
else
    git clone https://$PACKAGE_CLONE_USER:$PACkAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-android-sdk.git $ANDROID_CLONE_DIR;
fi

cd $ANDROID_CLONE_DIR;

cat CHANGELOG.md > temp;
# also copy changelog.md
echo "## $VERSION

* Updates inapp module dependency to $VERSION
" > CHANGELOG.md
cat temp >> CHANGELOG.md;
rm temp;

echo $VERSION > version;

sed -i '' "s/reclaim_verifier_module = \".*\"/reclaim_verifier_module = \"$VERSION\"/" ./gradle/libs.versions.toml;
sed -i '' "s/implementation \"org.reclaimprotocol:inapp_sdk:.*\"/implementation \"org.reclaimprotocol:inapp_sdk:$VERSION\"/" ./README.md;
sed -i '' "s/implementation \"org.reclaimprotocol:inapp_sdk:.*\"/implementation \"org.reclaimprotocol:inapp_sdk:$VERSION\"/" ./example/app/build.gradle;
sed -i '' "s/..\/dist\/library\/.*\/repo/..\/dist\/library\/$VERSION\/repo/" ./example/settings.gradle;

make build;

# test & upload to S3 bucket
echo "test & upload everything under $ANDROID_CLONE_DIR/dist/library/$VERSION/repo to S3 bucket"

# COMMIT, TAG, PUSH

cd $WORK_DIR;