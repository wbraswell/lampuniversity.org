#!/usr/bin/env bash
# v0.013
set -euo pipefail

WRAPPER_VERSION="0.013"
PREPARE_ONLY="${WHISPERX_PREPARE_ONLY:-0}"
CONNECTOR_CHECKPOINT_REQUIRED="${WHISPERX_CONNECTOR_CHECKPOINT_REQUIRED:-1}"

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

# normalize all local job paths before starting the run log
INPUT_FILE="$(readlink -f -- "$INPUT_FILE")"
OUTPUT_DIRECTORY="$(dirname -- "$INPUT_FILE")"
INPUT_BASENAME="$(basename -- "$INPUT_FILE")"
INPUT_STEM="${INPUT_BASENAME%.*}"
CHECKPOINT_DIRECTORY="${WHISPERX_CHECKPOINT_DIRECTORY:-$OUTPUT_DIRECTORY/whisperx_checkpoints/$INPUT_STEM}"
RUN_LOG="${WHISPERX_RUN_LOG:-$OUTPUT_DIRECTORY/$INPUT_STEM.out}"
CONNECTOR_DIRECTORY="${WHISPERX_CONNECTOR_DIRECTORY:-$CHECKPOINT_DIRECTORY/connector-handoff}"
CONNECTOR_JOB_ID="${WHISPERX_CONNECTOR_JOB_ID:-$INPUT_STEM}"
CONNECTOR_HOOK="$(command -v whisperx_checkpoint_connector_pause.sh || true)"
WHISPERX_PID=""

mkdir -p "$CHECKPOINT_DIRECTORY" "$CONNECTOR_DIRECTORY"
exec > >(tee -a "$RUN_LOG") 2>&1

# verify that the installed WhisperX source contains all required upgrades
WHISPERX_EXECUTABLE="$(command -v whisperx)"
WHISPERX_ENVIRONMENT_ROOT="$(dirname -- "$(dirname -- "$WHISPERX_EXECUTABLE")")"
WHISPERX_SOURCE_DIRECTORIES=(
    "$WHISPERX_ENVIRONMENT_ROOT"/lib/python*/site-packages/whisperx
)

if [ "${#WHISPERX_SOURCE_DIRECTORIES[@]}" -ne 1 ] || [ ! -d "${WHISPERX_SOURCE_DIRECTORIES[0]}" ]; then
    echo "ERROR: Unable to locate the installed WhisperX source directory." >&2
    exit 1
fi

WHISPERX_SOURCE_DIRECTORY="${WHISPERX_SOURCE_DIRECTORIES[0]}"
if ! grep -q 'WHISPERX_STAGE_PROGRESS_V1' "$WHISPERX_SOURCE_DIRECTORY/transcribe.py" ||
   ! grep -q 'WHISPERX_VAD_STAGE_PROGRESS_V1' "$WHISPERX_SOURCE_DIRECTORY/asr.py" ||
   ! grep -q 'WHISPERX_PYANNOTE_VAD_PROGRESS_V1' "$WHISPERX_SOURCE_DIRECTORY/vads/pyannote.py" ||
   ! grep -q 'whisperx-stage-checkpoint-v2' "$WHISPERX_SOURCE_DIRECTORY/transcribe.py" ||
   ! grep -q 'WHISPERX_CHECKPOINT_HOOK' "$WHISPERX_SOURCE_DIRECTORY/transcribe.py"; then
    echo "ERROR: Installed WhisperX source does not contain the required fail-safe upgrades." >&2
    echo "WhisperX source directory: $WHISPERX_SOURCE_DIRECTORY" >&2
    exit 1
fi

WHISPERX_INSTALLED_VERSION="$(
    "$WHISPERX_ENVIRONMENT_ROOT/bin/python" -m pip show whisperx 2>/dev/null \
        | awk '/^Version: / { print $2; exit }'
)"
WHISPERX_INSTALLED_VERSION="${WHISPERX_INSTALLED_VERSION:-unknown}"
WHISPERX_SOURCE_ID="${WHISPERX_SOURCE_VERSION:-$WHISPERX_INSTALLED_VERSION}"

# require the Hugging Face token from the environment only
if [ -z "${HF_TOKEN:-}" ]; then
    echo "ERROR: HF_TOKEN is not set in the environment." >&2
    exit 1
fi

# require the connector checkpoint handoff helper unless explicitly disabled
if [ "$CONNECTOR_CHECKPOINT_REQUIRED" = "1" ] && [ -z "$CONNECTOR_HOOK" ]; then
    echo "ERROR: Connector checkpoint handoff is required but whisperx_checkpoint_connector_pause.sh was not found in PATH." >&2
    exit 1
fi

if [ "$CONNECTOR_CHECKPOINT_REQUIRED" = "1" ]; then
    "$CONNECTOR_HOOK" --preflight
fi

if [ -f "$CONNECTOR_DIRECTORY/pending.env" ]; then
    echo "ERROR: An unacknowledged connector checkpoint is already pending:" >&2
    cat "$CONNECTOR_DIRECTORY/pending.env" >&2
    echo "Upload and ACK that checkpoint, or explicitly resolve it before starting another WhisperX process." >&2
    exit 1
fi

if [ "$CONNECTOR_CHECKPOINT_REQUIRED" = "1" ]; then
    export WHISPERX_CONNECTOR_DIRECTORY="$CONNECTOR_DIRECTORY"
    export WHISPERX_CONNECTOR_JOB_ID="$CONNECTOR_JOB_ID"
    export WHISPERX_CHECKPOINT_HOOK="$CONNECTOR_HOOK"
else
    unset WHISPERX_CHECKPOINT_HOOK || true
fi

# build the CPU-only WhisperX command with automatic resume enabled
WHISPERX_COMMAND=(
    whisperx
    "$INPUT_FILE"
    --model large-v3-turbo
    --language en
    --diarize
    --device cpu
    --compute_type int8
    --threads 4
    --batch_size 1
    --output_dir "$OUTPUT_DIRECTORY"
    --output_format all
    --verbose True
    --print_progress True
    --log-level info
    --hf_token "$HF_TOKEN"
    --checkpoint_dir "$CHECKPOINT_DIRECTORY"
    --resume_from auto
)

# constrain diarization only when the exact speaker count is known
if [ -n "$SPEAKER_COUNT" ]; then
    WHISPERX_COMMAND+=(
        --min_speakers "$SPEAKER_COUNT"
        --max_speakers "$SPEAKER_COUNT"
    )
fi

echo "WhisperX wrapper version: $WRAPPER_VERSION"
echo "WhisperX installed version: $WHISPERX_INSTALLED_VERSION"
echo "WhisperX source ID: $WHISPERX_SOURCE_ID"
echo "WhisperX input: $INPUT_FILE"
echo "WhisperX output directory: $OUTPUT_DIRECTORY"
echo "WhisperX checkpoint directory: $CHECKPOINT_DIRECTORY"
echo "WhisperX run log: $RUN_LOG"
echo "WhisperX model: large-v3-turbo"
echo "WhisperX device: CPU, int8, 4 threads, batch size 1"
echo "WhisperX resume mode: automatic"
echo "WhisperX checkpoint identity: audio size plus SHA-256, independent of path and timestamp"
echo "WhisperX checkpoint retention: partial and completed-stage checkpoints are preserved"
echo "WhisperX source upgrade: verified in $WHISPERX_SOURCE_DIRECTORY"
if [ "$CONNECTOR_CHECKPOINT_REQUIRED" = "1" ]; then
    echo "WhisperX checkpoint transport: ChatGPT Dropbox connector handoff"
    echo "WhisperX connector job ID: $CONNECTOR_JOB_ID"
    echo "WhisperX connector handoff directory: $CONNECTOR_DIRECTORY"
    echo "WhisperX checkpoint behavior: pause after each completed transcription chunk until connector delta upload ACK"
else
    echo "WhisperX connector checkpoint handoff: disabled by explicit configuration"
fi
if [ -n "$SPEAKER_COUNT" ]; then
    echo "WhisperX exact speaker count: $SPEAKER_COUNT"
else
    echo "WhisperX speaker count: automatic detection"
fi

if [ "$PREPARE_ONLY" = "1" ]; then
    echo "WhisperX status: preparation-only validation completed; transcription was not started."
    exit 0
fi

echo "WhisperX status: starting model load and transcription pipeline now..."

whisperx_cleanup() {
    if [ -n "$WHISPERX_PID" ] && kill -0 "$WHISPERX_PID" 2>/dev/null; then
        kill "$WHISPERX_PID" 2>/dev/null || true
    fi
}
trap whisperx_cleanup EXIT INT TERM

# force immediate output flushing
PYTHONUNBUFFERED=1 HF_HUB_DISABLE_PROGRESS_BARS=0 "${WHISPERX_COMMAND[@]}" &
WHISPERX_PID=$!
WHISPERX_START_SECONDS=$SECONDS

while kill -0 "$WHISPERX_PID" 2>/dev/null; do
    sleep 15
    if kill -0 "$WHISPERX_PID" 2>/dev/null; then
        WHISPERX_ELAPSED_SECONDS=$((SECONDS - WHISPERX_START_SECONDS))
        printf 'WhisperX heartbeat: still running, elapsed %d minute(s) %d second(s).\n' \
            $((WHISPERX_ELAPSED_SECONDS / 60)) \
            $((WHISPERX_ELAPSED_SECONDS % 60))
        if [ -f "$CONNECTOR_DIRECTORY/pending.env" ]; then
            PENDING_REMOTE_PATH="$(awk -F= '$1 == "remote_path" { sub(/^[^=]*=/, ""); print; exit }' "$CONNECTOR_DIRECTORY/pending.env")"
            printf 'WhisperX heartbeat: waiting for connector checkpoint ACK: %s\n' "$PENDING_REMOTE_PATH"
        fi
    fi
done

set +e
wait "$WHISPERX_PID"
WHISPERX_EXIT_STATUS=$?
set -e

if [ "$WHISPERX_EXIT_STATUS" -eq 0 ]; then
    echo "WhisperX status: completed successfully."
else
    echo "ERROR: WhisperX exited with status $WHISPERX_EXIT_STATUS." >&2
    exit "$WHISPERX_EXIT_STATUS"
fi
