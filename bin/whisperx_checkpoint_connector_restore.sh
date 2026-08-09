#!/usr/bin/env bash
# v0.001
set -euo pipefail

SCRIPT_VERSION="0.001"
for required_command in awk basename dirname find jq mkdir mv readlink sha256sum sort wc; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "ERROR: Required command is unavailable: $required_command" >&2
        exit 1
    fi
done

if [ "$#" -eq 1 ] && [ "$1" = "--preflight" ]; then
    echo "WhisperX connector restore helper preflight: PASS (v$SCRIPT_VERSION)"
    exit 0
fi

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-audio-or-video> <checkpoint-directory> <restored-delta-directory>" >&2
    exit 1
fi

INPUT_FILE="$(readlink -f -- "$1")"
CHECKPOINT_DIRECTORY="$2"
DELTA_DIRECTORY="$3"

if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input recording is missing: $INPUT_FILE" >&2
    exit 1
fi
if [ ! -d "$DELTA_DIRECTORY" ]; then
    echo "ERROR: Restored connector delta directory is missing: $DELTA_DIRECTORY" >&2
    exit 1
fi

mapfile -t DELTA_FILES < <(find "$DELTA_DIRECTORY" -maxdepth 1 -type f -name 'transcription-partial-[0-9][0-9][0-9][0-9][0-9][0-9].json' -printf '%p\n' | LC_ALL=C sort)
if [ "${#DELTA_FILES[@]}" -eq 0 ]; then
    echo "ERROR: No connector transcription delta files were found in $DELTA_DIRECTORY" >&2
    exit 1
fi

EXPECTED_AUDIO_NAME="$(basename -- "$INPUT_FILE")"
EXPECTED_AUDIO_SIZE="$(wc -c < "$INPUT_FILE")"
EXPECTED_AUDIO_SHA256="$(sha256sum "$INPUT_FILE" | awk '{print $1}')"
REFERENCE_SOURCE_VERSION=""
REFERENCE_LANGUAGE=""
EXPECTED_COUNT=1

for delta_file in "${DELTA_FILES[@]}"; do
    if ! jq -e '.format == "whisperx-connector-transcription-delta-v1" and (.completed_segment_count | type == "number") and (.segment | type == "object")' "$delta_file" >/dev/null; then
        echo "ERROR: Invalid connector delta: $delta_file" >&2
        exit 1
    fi

    DELTA_COUNT="$(jq -r '.completed_segment_count' "$delta_file")"
    DELTA_AUDIO_NAME="$(jq -r '.audio_name' "$delta_file")"
    DELTA_AUDIO_SIZE="$(jq -r '.audio_size' "$delta_file")"
    DELTA_AUDIO_SHA256="$(jq -r '.audio_sha256' "$delta_file")"
    DELTA_SOURCE_VERSION="$(jq -r '.source_version' "$delta_file")"
    DELTA_LANGUAGE="$(jq -r '.language' "$delta_file")"

    if [ "$DELTA_COUNT" -ne "$EXPECTED_COUNT" ]; then
        echo "ERROR: Connector delta sequence is not contiguous; expected segment $EXPECTED_COUNT but found $DELTA_COUNT in $delta_file" >&2
        exit 1
    fi
    if [ "$DELTA_AUDIO_NAME" != "$EXPECTED_AUDIO_NAME" ] || [ "$DELTA_AUDIO_SIZE" != "$EXPECTED_AUDIO_SIZE" ] || [ "$DELTA_AUDIO_SHA256" != "$EXPECTED_AUDIO_SHA256" ]; then
        echo "ERROR: Connector delta does not match the staged input recording: $delta_file" >&2
        exit 1
    fi

    if [ -z "$REFERENCE_SOURCE_VERSION" ]; then
        REFERENCE_SOURCE_VERSION="$DELTA_SOURCE_VERSION"
        REFERENCE_LANGUAGE="$DELTA_LANGUAGE"
    elif [ "$DELTA_SOURCE_VERSION" != "$REFERENCE_SOURCE_VERSION" ] || [ "$DELTA_LANGUAGE" != "$REFERENCE_LANGUAGE" ]; then
        echo "ERROR: Connector delta source version or language changed within one checkpoint sequence: $delta_file" >&2
        exit 1
    fi

    EXPECTED_COUNT=$((EXPECTED_COUNT + 1))
done

mkdir -p "$CHECKPOINT_DIRECTORY"
INPUT_STEM="$(basename -- "$INPUT_FILE")"
INPUT_STEM="${INPUT_STEM%.*}"
DESTINATION="$CHECKPOINT_DIRECTORY/$INPUT_STEM.whisperx-transcription-partial.json"
TEMP_DESTINATION="$DESTINATION.tmp.$$"

jq -s '{
    format: "whisperx-stage-checkpoint-v2",
    stage: "transcription-partial",
    audio_name: .[0].audio_name,
    audio_size: .[0].audio_size,
    audio_sha256: .[0].audio_sha256,
    source_version: .[0].source_version,
    result: {
        segments: map(.segment),
        language: .[0].language
    }
}' "${DELTA_FILES[@]}" > "$TEMP_DESTINATION"
printf '\n' >> "$TEMP_DESTINATION"

if ! jq -e '.format == "whisperx-stage-checkpoint-v2" and .stage == "transcription-partial" and (.result.segments | length) > 0' "$TEMP_DESTINATION" >/dev/null; then
    echo "ERROR: Reconstructed WhisperX partial checkpoint is invalid: $TEMP_DESTINATION" >&2
    exit 1
fi

mv -f -- "$TEMP_DESTINATION" "$DESTINATION"
printf 'WhisperX connector restore version: %s\n' "$SCRIPT_VERSION"
printf 'WhisperX connector restore: reconstructed %d transcription segment(s).\n' "${#DELTA_FILES[@]}"
printf 'WhisperX connector restore checkpoint: %s\n' "$DESTINATION"
