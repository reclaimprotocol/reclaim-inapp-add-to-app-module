#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

rm -rf inapp-sdks;

mkdir -p inapp-sdks;

cd inapp-sdks;

# Upload everything under dist/android/$VERSION/repo to S3 bucket
./../scripts/inapp/android.sh;

# Upload everything under dist/ios/ to S3 bucket
./../scripts/inapp/ios.sh;
