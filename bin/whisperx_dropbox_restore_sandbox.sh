#!/usr/bin/env bash
# v0.001
set -euo pipefail

SCRIPT_VERSION="0.001"
TRANSFER_DIRECTORY="${WHISPERX_TRANSFER_DIRECTORY:-/mnt/data}"
DROPBOX_ROOT="${WHISPERX_DROPBOX_ROOT:-/home_wbraswell/school/utd/whisperx}"
INPUT_NAME="${1:-2026-04-22_14-01-00.mp4}"
SPEAKER_COUNT="${2:-3}"
DROPBOX_HELPER="$TRANSFER_DIRECTORY/whisperx_dropbox_checkpoint_sync.pl"
INSTALLER="$TRANSFER_DIRECTORY/install_whisperx_transfer_bundle_and_transcribe.sh"
DROPBOX_CREDENTIALS_FILE="${WHISPERX_DROPBOX_CREDENTIALS_FILE:-}"
TOKEN_CACHE_FILE="${WHISPERX_DROPBOX_TOKEN_CACHE_FILE:-$TRANSFER_DIRECTORY/.whisperx-dropbox-token-cache.json}"

if [ ! -f "$DROPBOX_HELPER" ]; then
    echo "ERROR: Bootstrap helper is missing: $DROPBOX_HELPER" >&2
    echo "Download whisperx_dropbox_checkpoint_sync.pl from the WhisperX Dropbox folder first." >&2
    exit 1
fi

if [ -z "${DROPBOX_ACCESS_TOKEN:-}" ] &&
   { [ -z "${DROPBOX_APP_KEY:-}" ] || [ -z "${DROPBOX_APP_SECRET:-}" ] || [ -z "${DROPBOX_REFRESH_TOKEN:-}" ]; } &&
   { [ -z "$DROPBOX_CREDENTIALS_FILE" ] || [ ! -f "$DROPBOX_CREDENTIALS_FILE" ]; }; then
    echo "ERROR: Dropbox credentials are unavailable." >&2
    echo "Set WHISPERX_DROPBOX_CREDENTIALS_FILE or Dropbox credential environment variables." >&2
    exit 1
fi

BOOTSTRAP_ARGUMENTS=(
    bootstrap-download
    --dropbox-root "$DROPBOX_ROOT"
    --local-directory "$TRANSFER_DIRECTORY"
    --input-name "$INPUT_NAME"
    --token-cache-file "$TOKEN_CACHE_FILE"
    --http-timeout 1800
)
if [ -n "$DROPBOX_CREDENTIALS_FILE" ]; then
    BOOTSTRAP_ARGUMENTS+=(--credentials-file "$DROPBOX_CREDENTIALS_FILE")
fi

echo "WhisperX sandbox restore version: $SCRIPT_VERSION"
echo "WhisperX Dropbox root: $DROPBOX_ROOT"
echo "WhisperX transfer directory: $TRANSFER_DIRECTORY"
echo "WhisperX input recording: $INPUT_NAME"

perl "$DROPBOX_HELPER" "${BOOTSTRAP_ARGUMENTS[@]}"

if [ ! -x "$INSTALLER" ]; then
    chmod a+x "$INSTALLER"
fi

exec "$INSTALLER" "$TRANSFER_DIRECTORY/$INPUT_NAME" "$SPEAKER_COUNT"
