android:
	flutter build aar --dart-define-from-file=./env.json
clean:
	flutter clean
ios:
	mkdir -p build/ios
	flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios
ios-prod:
	flutter clean
	flutter pub get
	cd .ios && pod deintegrate
	sed -i '' "s/platform :ios, '.*'/platform :ios, '13.0'/" ./.ios/Podfile
	cd .ios && pod install
	mkdir -p build/ios
	flutter build ios-framework --dart-define-from-file=./env.json --output=build/ios --release --no-profile --debug
	dart run scripts/prepare_ios.dart
	@# cd build/ios && tar -Jcvf ReclaimXCFrameworks.tar.xz ReclaimXCFrameworks # SLOW
	cd build/ios && tar -zcvf ReclaimXCFrameworks.tar.gz ReclaimXCFrameworks # FAST
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner watch --delete-conflicting-outputs
