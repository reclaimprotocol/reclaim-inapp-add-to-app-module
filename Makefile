VERSION := $(shell grep '^version:' pubspec.yaml | sed -e 's/version: //')
DIST_ANDROID := ./dist/android/$(VERSION)
DIST_IOS := ./dist/ios/$(VERSION)
# DELETE .DS_Store file from all release

android:
	flutter clean
	flutter pub get
	flutter build aar --dart-define-from-file=./env.json
	rm -rf $(DIST_ANDROID)
	mkdir -p $(DIST_ANDROID)
	mv build/host/outputs/repo/ $(DIST_ANDROID)/repo
clean:
	rm -rf $(DIST_ANDROID)
	rm -rf $(DIST_IOS)
	flutter clean
ios:
	flutter clean
	flutter pub get
	cd .ios && pod deintegrate
	sed -i '' "s/platform :ios, '.*'/platform :ios, '13.0'/" ./.ios/Podfile
	cd .ios && pod install
	mkdir -p build/ios
	@# flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --profile --debug
	flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --no-profile --debug
	dart run scripts/prepare_ios.dart
	@# cd build/ios && tar -Jcvf ReclaimXCFrameworks.tar.xz ReclaimXCFrameworks # SLOW
	cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks # FAST
	rm -rf $(DIST_IOS)
	mkdir -p $(DIST_IOS)
	mv build/ios/ReclaimXCFrameworks.tar.gz $(DIST_IOS)
	@# mv build/ios/ReclaimXCFrameworks $(DIST_IOS)
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner watch --delete-conflicting-outputs
local_repo:
	# For local testing of remote repo for iOS and Android
	python3 -m http.server -d ./dist/
