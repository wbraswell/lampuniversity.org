#!/usr/bin/env bash
# v0.003
set -euo pipefail

# source the shared non-Perl environment setup from PATH
NONPERL_PATH_SCRIPT="$(command -v source_this_to_export_nonperl_paths.sh || true)"
if [ -z "$NONPERL_PATH_SCRIPT" ]; then
    echo "ERROR: source_this_to_export_nonperl_paths.sh was not found in PATH." >&2
    exit 1
fi

# shellcheck source=/dev/null
source "$NONPERL_PATH_SCRIPT"

# validate arguments
if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 <path-to-video-or-audio> [exact-number-of-speakers]" >&2
    exit 1
fi

INPUT_FILE="$1"
SPEAKER_COUNT="${2:-}"

# validate the input file
if [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Input file does not exist: $INPUT_FILE" >&2
    exit 1
fi

# validate the optional exact speaker count
if [ -n "$SPEAKER_COUNT" ]; then
    case "$SPEAKER_COUNT" in
        *[!0-9]* | 0)
            echo "ERROR: Speaker count must be a positive integer." >&2
            exit 1
            ;;
    esac
fi

# verify that WhisperX is available from the activated environment
if ! command -v whisperx >/dev/null 2>&1; then
    echo "ERROR: whisperx was not found after sourcing $NONPERL_PATH_SCRIPT." >&2
    exit 1
fi

# require the Hugging Face token from the environment only
if [ -z "${HF_TOKEN:-}" ]; then
    echo "ERROR: HF_TOKEN is not set in the environment." >&2
    exit 1
fi

# save output files beside the source recording
INPUT_FILE="$(readlink -f -- "$INPUT_FILE")"
OUTPUT_DIRECTORY="$(dirname -- "$INPUT_FILE")"

# build the CPU-only WhisperX command
WHISPERX_COMMAND=(
    whisperx
    "$INPUT_FILE"
    --model large-v3-turbo
    --language en
    --diarize
    --device cpu
    --compute_type float32
    --threads 8
    --output_dir "$OUTPUT_DIRECTORY"
    --output_format all
    --hf_token "$HF_TOKEN"
)

# constrain diarization only when the exact speaker count is known
if [ -n "$SPEAKER_COUNT" ]; then
    WHISPERX_COMMAND+=(
        --min_speakers "$SPEAKER_COUNT"
        --max_speakers "$SPEAKER_COUNT"
    )
fi

echo "WhisperX input: $INPUT_FILE"
echo "WhisperX output directory: $OUTPUT_DIRECTORY"
echo "WhisperX model: large-v3-turbo"
echo "WhisperX device: CPU, float32, 8 threads"
if [ -n "$SPEAKER_COUNT" ]; then
    echo "WhisperX exact speaker count: $SPEAKER_COUNT"
else
    echo "WhisperX speaker count: automatic detection"
fi

"${WHISPERX_COMMAND[@]}"
