android:
	flutter clean
	flutter pub get
	flutter build aar --dart-define-from-file=./env.json
	mv build/host/outputs/repo ./dist/android
clean:
	flutter clean
ios:
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
	mkdir -p ./dist/ios;
	mv build/ios/ReclaimXCFrameworks.tar.gz ./dist/ios/ReclaimXCFrameworks.tar.gz
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner watch --delete-conflicting-outputs
