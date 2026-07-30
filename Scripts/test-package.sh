#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_PATH="$REPOSITORY_ROOT/Examples/TestStepHUDDemo/TestStepHUDDemo.xcodeproj"
RESULT_BUNDLE=${RESULT_BUNDLE:-"$REPOSITORY_ROOT/Artifacts/TestStepHUDProtocolTests.xcresult"}

if [ -z "${DESTINATION:-}" ]; then
    SIMULATOR_ID=$(xcrun simctl list devices available | awk '
        /\(Booted\)/ {
            for (fieldIndex = 1; fieldIndex <= NF; fieldIndex++) {
                if ($fieldIndex ~ /^\([0-9A-Fa-f-]{36}\)$/) {
                    gsub(/[()]/, "", $fieldIndex)
                    print $fieldIndex
                    exit
                }
            }
        }
    ')
    if [ -z "$SIMULATOR_ID" ]; then
        SIMULATOR_ID=$(xcrun simctl list devices available | awk '
            /iPhone/ && /\(Shutdown\)/ {
                for (fieldIndex = 1; fieldIndex <= NF; fieldIndex++) {
                    if ($fieldIndex ~ /^\([0-9A-Fa-f-]{36}\)$/) {
                        gsub(/[()]/, "", $fieldIndex)
                        print $fieldIndex
                        exit
                    }
                }
            }
        ')
    fi
    if [ -z "$SIMULATOR_ID" ]; then
        echo "No available iPhone Simulator was found." >&2
        exit 1
    fi
    DESTINATION="platform=iOS Simulator,id=$SIMULATOR_ID"
fi

if [ -e "$RESULT_BUNDLE" ]; then
    BACKUP_PATH="${RESULT_BUNDLE%.xcresult}-previous-$(date +%Y%m%d-%H%M%S).xcresult"
    mv "$RESULT_BUNDLE" "$BACKUP_PATH"
fi

XCODEBUILD_ARGUMENTS=(
    test
    -project "$PROJECT_PATH"
    -scheme TestStepHUDDemo
    -configuration Debug
    -destination "$DESTINATION"
    -derivedDataPath "$REPOSITORY_ROOT/DerivedData"
    -only-testing:TestStepHUDProtocolTests
    -parallel-testing-enabled NO
    -resultBundlePath "$RESULT_BUNDLE"
)

if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild "${XCODEBUILD_ARGUMENTS[@]}" | xcbeautify
else
    xcodebuild "${XCODEBUILD_ARGUMENTS[@]}"
fi
