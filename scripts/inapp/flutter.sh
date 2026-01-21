#!/usr/bin/env bash

set -ex;

export VERSION=$(grep '^version:' pubspec.yaml | sed -e 's/version: //')

mkdir -p inapp-sdks;

cd inapp-sdks;

export WORK_DIR="$(pwd)";

export RN_CLONE_DIR="$WORK_DIR/build/flutter-sdk";

if [[ -z "$PACKAGE_CLONE_USER" ]]; then
    git clone git@github.com:reclaimprotocol/reclaim-inapp-flutter-sdk.git $RN_CLONE_DIR;
else
    git clone https://$PACKAGE_CLONE_USER:$PACKAGE_CLONE_PASSWD@github.com/reclaimprotocol/reclaim-inapp-flutter-sdk.git $RN_CLONE_DIR;
fi

cd $RN_CLONE_DIR;

DEFAULT_CHANGELOG="## $VERSION

* Updates inapp module dependency to $VERSION
"

EFFECTIVE_CHANGELOG="${NEXT_CHANGELOG:-$DEFAULT_CHANGELOG}"

# copy current changelog.md
cat CHANGELOG.md > temp;
# enter new changes
echo "$EFFECTIVE_CHANGELOG" > CHANGELOG.md
# append old changelog
cat temp >> CHANGELOG.md;
# remove copy
rm temp;

sed -i '' "s/SDK_MODULE_VERSION=.*/SDK_MODULE_VERSION=$VERSION/" ./setup.sh;
# Remove version sources from Reclaim dependencies inside ./internal
# Update inapp sdk version of dependency in pubspec.yaml
