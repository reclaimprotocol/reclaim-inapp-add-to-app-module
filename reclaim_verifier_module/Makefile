android:
	flutter build aar
clean:
	flutter clean
ios:
	mkdir -p build/ios
	flutter build ios-framework --output=build/ios
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner watch --delete-conflicting-outputs
