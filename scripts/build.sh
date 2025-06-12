#!/usr/bin/env bash

set -ex;

VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')
DIST_ANDROID=./dist/android/$VERSION
DIST_IOS=./dist/ios/$VERSION

flutter clean
flutter pub get

mkdir -p debug/android/
flutter build aar --dart-define-from-file=./env.json --build-number=$VERSION; # --split-debug-info=debug/android/v$VERSION
rm -rf $DIST_ANDROID
mkdir -p $DIST_ANDROID
mv build/host/outputs/repo/ $DIST_ANDROID/repo

(cd .ios && pod deintegrate;)
sed -i '' "s/platform :ios, '.*'/platform :ios, '13.0'/" ./.ios/Podfile;
(cd .ios && pod install)
mkdir -p build/ios
mkdir -p debug/ios/
flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --no-profile --debug; # --split-debug-info=debug/ios/v$VERSION
dart run scripts/prepare_ios.dart
(cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks) # FAST
rm -rf $DIST_IOS
mkdir -p $DIST_IOS
mv build/ios/ReclaimXCFrameworks.tar.gz $DIST_IOS
