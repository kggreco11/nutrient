#!/bin/sh
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
TASK_BINARY=$(mktemp -u /tmp/nutrient-model-checks.XXXXXX)
TASK_SEED=$(mktemp /tmp/nutrient-test-seed.XXXXXX)
cp "$TASK_ROOT/ios/App/App/NativeSeed.json" "$TASK_SEED"
trap 'rm -f "$TASK_BINARY" "$TASK_SEED"' EXIT
TASK_SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
xcrun --sdk iphonesimulator swiftc -parse-as-library -sdk "$TASK_SDK" -target arm64-apple-ios17.0-simulator "$TASK_ROOT/ios/App/App/NativeModels.swift" "$TASK_ROOT/ios/App/App/NativeBackend.swift" "$TASK_ROOT/tests/NativeModelChecks.swift" -o "$TASK_BINARY"
xcrun simctl spawn booted "$TASK_BINARY" "$TASK_SEED"
