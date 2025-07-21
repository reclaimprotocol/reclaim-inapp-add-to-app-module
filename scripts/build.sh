#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')
DIST_ANDROID=./dist/android/$VERSION
DIST_IOS=./dist/ios/$VERSION

flutter clean
flutter pub get

LATEST_CHANGELOG_LINES=$(awk '/^##/{c++; next} c==1' CHANGELOG.md)

export NEXT_CHANGELOG="
## $VERSION
$LATEST_CHANGELOG_LINES
"

./scripts/build_android.sh

./scripts/build_ios.sh
