#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')
DIST_ANDROID=./dist/android/$VERSION
DIST_IOS=./dist/ios/$VERSION

flutter clean
flutter pub get
dart run rive_native:setup --verbose --clean --platform android,ios;

ANDROID_DISTRIBUTION_FILES="$DIST_ANDROID/repo"
IOS_DISTRIBUTION_FILES="$DIST_IOS"

./scripts/build_android.sh

./scripts/build_ios.sh

echo "Android distribution ready in $ANDROID_DISTRIBUTION_FILES"
echo "iOS distribution ready in $IOS_DISTRIBUTION_FILES"

set +x
while true; do
    read -r -p "Please upload the files in $ANDROID_DISTRIBUTION_FILES for to the android repository. Have you uploaded them? (y/n): " yn
    case $yn in
        [Yy]* ) echo "Confirmed. Exiting."; break;;
        [Nn]* ) echo "Please upload the files before continuing.";;
        * ) echo "Please answer yes or no.";;
    esac
done
set -x


set +x
while true; do
    read -r -p "Please upload the files in $IOS_DISTRIBUTION_FILES to the ios repository. Have you uploaded them? (y/n): " yn
    case $yn in
        [Yy]* ) echo "Confirmed. Exiting."; break;;
        [Nn]* ) echo "Please upload the files before continuing.";;
        * ) echo "Please answer yes or no.";;
    esac
done
set -x

./scripts/inapp/inapp.sh
