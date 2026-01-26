.PHONY: android, ios

android:
	./scripts/build_android.sh;
ios:
	./scripts/build_ios.sh;
gen_schema:
	dart run pigeon --input pigeon/schema.dart
gen_dart:
	dart run build_runner build --delete-conflicting-outputs
fmt:
	dart format .;
generate:
	make gen_schema;
	make gen_dart;
	make fmt;
local_repo:
	# For local testing of remote repo for iOS and Android
	python3 -m http.server -d ./dist/
build:
	(source .env.secret && ./scripts/build.sh;)
dev:
	flutter run
