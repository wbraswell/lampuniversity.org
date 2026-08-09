#!/usr/bin/env bash
# v0.006
set -euo pipefail

SCRIPT_VERSION="0.006"
TRANSFER_DIRECTORY="${WHISPERX_TRANSFER_DIRECTORY:-/mnt/data}"
INPUT_NAME="${1:-2026-04-22_14-01-00.mp4}"
SPEAKER_COUNT="${2:-3}"
PREPARE_ONLY="${WHISPERX_PREPARE_ONLY:-0}"
INSTALLER="$TRANSFER_DIRECTORY/whisperx_transfer_bundle_install_and_transcribe.sh"
WRAPPER="$TRANSFER_DIRECTORY/whisperx_transcribe_accents.sh"
CONNECTOR_HOOK="$TRANSFER_DIRECTORY/whisperx_checkpoint_connector_pause.sh"
CONNECTOR_RESTORE="$TRANSFER_DIRECTORY/whisperx_checkpoint_connector_restore.sh"
INPUT_FILE="$TRANSFER_DIRECTORY/$INPUT_NAME"

for required_file in "$INSTALLER" "$WRAPPER" "$CONNECTOR_HOOK" "$CONNECTOR_RESTORE" "$INPUT_FILE"; do
    if [ ! -f "$required_file" ]; then
        echo "ERROR: Required sandbox-staged file is missing: $required_file" >&2
        echo "The ChatGPT tool layer must stage runtime/source/control/input files before this launcher can run." >&2
        exit 1
    fi
done

chmod a+x "$INSTALLER" "$WRAPPER" "$CONNECTOR_HOOK" "$CONNECTOR_RESTORE"

"$CONNECTOR_HOOK" --preflight
"$CONNECTOR_RESTORE" --preflight

echo "WhisperX sandbox restore launcher version: $SCRIPT_VERSION"
echo "WhisperX transfer directory: $TRANSFER_DIRECTORY"
echo "WhisperX input recording: $INPUT_NAME"
echo "WhisperX checkpoint transport: ChatGPT Dropbox connector handoff"
echo "WhisperX sandbox networking: not used"
if [ "$PREPARE_ONLY" = "1" ]; then
    echo "WhisperX restore mode: preparation-only"
else
    echo "WhisperX restore mode: install and transcribe"
fi

exec "$INSTALLER" "$INPUT_FILE" "$SPEAKER_COUNT"
