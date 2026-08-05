#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROJECT_PATH="$REPOSITORY_ROOT/Examples/TestStepHUDDemo/TestStepHUDDemo.xcodeproj"
RESULT_BUNDLE=${RESULT_BUNDLE:-"$REPOSITORY_ROOT/Artifacts/TestStepHUDDemoRecording.xcresult"}
MP4_PATH="$REPOSITORY_ROOT/Docs/Assets/teststephud-demo.mp4"
WEBP_PATH="$REPOSITORY_ROOT/Docs/Assets/teststephud-demo.webp"

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required to build the README demo assets." >&2
    exit 1
fi

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
    -parallel-testing-enabled NO
    -only-testing:TestStepHUDDemoUITests/TestStepHUDDemoUITests/testRecordedCheckoutFlowShowsReadableSteps
    -resultBundlePath "$RESULT_BUNDLE"
    'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) TESTSTEPHUD_DEMO_FAILURE'
)

set +e
if command -v xcbeautify >/dev/null 2>&1; then
    xcodebuild "${XCODEBUILD_ARGUMENTS[@]}" | xcbeautify
    XCODEBUILD_STATUS=${PIPESTATUS[0]}
else
    xcodebuild "${XCODEBUILD_ARGUMENTS[@]}"
    XCODEBUILD_STATUS=$?
fi
set -e

if [ "$XCODEBUILD_STATUS" -eq 0 ]; then
    echo "The recording test unexpectedly passed." >&2
    exit 1
fi
if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "The recording result bundle was not created." >&2
    exit 1
fi

SUMMARY_JSON=$(xcrun xcresulttool get test-results summary \
    --path "$RESULT_BUNDLE" \
    --compact)
FAILED_TESTS=$(printf '%s' "$SUMMARY_JSON" | \
    plutil -extract failedTests raw -o - -- -)
FAILURE_TEXT=$(printf '%s' "$SUMMARY_JSON" | \
    plutil -extract testFailures.0.failureText raw -o - -- -)

if [ "$FAILED_TESTS" != "1" ] || \
    [[ "$FAILURE_TEXT" != *'Order confirmed'* ]] || \
    [[ "$FAILURE_TEXT" != *'Payment complete'* ]]; then
    echo "The recording did not contain the expected demo assertion." >&2
    echo "$FAILURE_TEXT" >&2
    exit 1
fi

EXPORT_DIRECTORY=$(mktemp -d "${TMPDIR:-/tmp}/teststephud-demo.XXXXXX")
trap 'rm -rf "$EXPORT_DIRECTORY"' EXIT
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$EXPORT_DIRECTORY" \
    >/dev/null

SOURCE_VIDEO=$(find "$EXPORT_DIRECTORY" -type f -name '*.mp4' -print -quit)
if [ -z "$SOURCE_VIDEO" ]; then
    echo "The recording result did not contain an MP4 attachment." >&2
    exit 1
fi

# Xcode stops its system recording as soon as the issue is registered. Hold
# the final, real failure-card frame so the reason remains readable in README.
ffmpeg -y -hide_banner -loglevel error \
    -ss 0.8 \
    -i "$SOURCE_VIDEO" \
    -vf "tpad=stop_mode=clone:stop_duration=3.2,scale=720:-2:flags=lanczos" \
    -an \
    -c:v libx264 \
    -preset slow \
    -crf 25 \
    -pix_fmt yuv420p \
    -movflags +faststart \
    "$MP4_PATH"

ffmpeg -y -hide_banner -loglevel error \
    -i "$MP4_PATH" \
    -vf "fps=8,scale=360:-2:flags=lanczos" \
    -loop 0 \
    -c:v libwebp_anim \
    -lossless 0 \
    -q:v 62 \
    -compression_level 6 \
    "$WEBP_PATH"

echo "Updated demo assets:"
echo "$MP4_PATH"
echo "$WEBP_PATH"
