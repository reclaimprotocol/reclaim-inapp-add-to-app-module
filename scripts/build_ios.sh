#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

DIST_IOS=./dist/ios/$VERSION

(cd .ios && pod deintegrate;)
sed -i '' "s/platform :ios, '.*'/platform :ios, '14.0'/" ./.ios/Podfile;
(cd .ios && pod install)
mkdir -p build/ios
mkdir -p debug/ios/
flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --no-profile --debug; # --split-debug-info=debug/ios/v$VERSION
dart run scripts/prepare_ios.dart
# Sign all frameworks to comply with Apple's requirements (ITMS-91065)
bash scripts/sign_ios_frameworks.sh
(cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks) # FAST
rm -rf $DIST_IOS
mkdir -p $DIST_IOS
mv build/ios/ReclaimXCFrameworks.tar.gz $DIST_IOS
