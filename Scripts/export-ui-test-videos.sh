#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
RESULT_BUNDLE=${1:-"$REPOSITORY_ROOT/Artifacts/TestStepHUDDemo.xcresult"}
OUTPUT_DIRECTORY=${2:-"$REPOSITORY_ROOT/Artifacts/TestStepHUDDemo-attachments"}

if [ ! -d "$RESULT_BUNDLE" ]; then
    echo "Result bundle not found: $RESULT_BUNDLE" >&2
    exit 1
fi

if [ -e "$OUTPUT_DIRECTORY" ]; then
    OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY}-$(date +%Y%m%d-%H%M%S)"
fi

xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$OUTPUT_DIRECTORY"

echo "Exported screen recordings:"
find "$OUTPUT_DIRECTORY" -type f -name '*.mp4' -print
