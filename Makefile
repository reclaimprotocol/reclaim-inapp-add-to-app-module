VERSION := $(shell grep '^version:' pubspec.yaml | sed -e 's/version: //')
DIST_ANDROID := ./dist/android/$(VERSION)
DIST_IOS := ./dist/ios/$(VERSION)
# DELETE .DS_Store file from all release

android:
	flutter clean
	flutter pub get
	mkdir -p debug/android/
	flutter build aar --dart-define-from-file=./env.json --build-number=$(VERSION); # --split-debug-info=debug/android/v$(VERSION)
	rm -rf $(DIST_ANDROID)
	mkdir -p $(DIST_ANDROID)
	mv build/host/outputs/repo/ $(DIST_ANDROID)/repo
	echo "Upload everything under $(DIST_ANDROID)/repo in android/repo of S3 bucket"
clean:
	rm -rf $(DIST_ANDROID)
	rm -rf $(DIST_IOS)
	flutter clean
ios:
	flutter clean
	flutter pub get
	cd .ios && pod deintegrate
	sed -i '' "s/platform :ios, '.*'/platform :ios, '14.0'/" ./.ios/Podfile
	cd .ios && pod install
	mkdir -p build/ios
	mkdir -p debug/ios/
	@# flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --profile --debug
	flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --no-profile --debug; # --split-debug-info=debug/ios/v$(VERSION)
	dart run scripts/prepare_ios.dart
	@# cd build/ios && tar -Jcvf ReclaimXCFrameworks.tar.xz ReclaimXCFrameworks # SLOW
	cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks # FAST
	rm -rf $(DIST_IOS)
	mkdir -p $(DIST_IOS)
	mv build/ios/ReclaimXCFrameworks.tar.gz $(DIST_IOS)
	echo "Upload $(DIST_IOS)/ReclaimXCFrameworks.tar.gz in ios/$(VERSION) of S3 bucket"
	@# mv build/ios/ReclaimXCFrameworks $(DIST_IOS)
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner build --delete-conflicting-outputs
generate:
	make gen_schema;
	make gen_dart;
	dart format .;
local_repo:
	# For local testing of remote repo for iOS and Android
	python3 -m http.server -d ./dist/
build:
	(source .env.secret && ./scripts/build.sh;)
clean:
	rm -rf dist/
	rm -rf inapp-sdks/
	flutter clean;
