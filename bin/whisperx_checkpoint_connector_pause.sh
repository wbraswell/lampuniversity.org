#!/usr/bin/env bash
# v0.003
set -euo pipefail

SCRIPT_VERSION="0.003"
MAX_DELTA_TEXT_BYTES="${WHISPERX_CONNECTOR_MAX_DELTA_TEXT_BYTES:-24000}"

HEARTBEAT_SECONDS="${WHISPERX_CONNECTOR_HEARTBEAT_SECONDS:-30}"
ACK_TIMEOUT_SECONDS="${WHISPERX_CONNECTOR_ACK_TIMEOUT_SECONDS:-0}"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <checkpoint-json-path>" >&2
    exit 1
fi

for required_command in awk basename cp date dirname grep jq mkdir mv readlink sha256sum tr wc; do
    if ! command -v "$required_command" >/dev/null 2>&1; then
        echo "ERROR: Required command is unavailable: $required_command" >&2
        exit 1
    fi
done
if [ "$1" = "--preflight" ]; then
    echo "WhisperX connector checkpoint hook preflight: PASS (v$SCRIPT_VERSION)"
    exit 0
fi

CHECKPOINT_PATH="$(readlink -f -- "$1")"
if [ ! -f "$CHECKPOINT_PATH" ]; then
    echo "ERROR: Connector checkpoint hook received a missing file: $CHECKPOINT_PATH" >&2
    exit 1
fi

CHECKPOINT_STAGE="$(jq -r '.stage // empty' "$CHECKPOINT_PATH")"
if [ "$CHECKPOINT_STAGE" != "transcription-partial" ]; then
    printf 'WhisperX connector checkpoint: stage %s remains local; completed transcription chunks are already protected by connector deltas.\n' "${CHECKPOINT_STAGE:-unknown}"
    exit 0
fi

CHECKPOINT_DIRECTORY="$(dirname -- "$CHECKPOINT_PATH")"
CONNECTOR_DIRECTORY="${WHISPERX_CONNECTOR_DIRECTORY:-$CHECKPOINT_DIRECTORY/connector-handoff}"
OUTBOX_DIRECTORY="$CONNECTOR_DIRECTORY/outbox"
ACK_DIRECTORY="$CONNECTOR_DIRECTORY/ack"
COMPLETED_DIRECTORY="$CONNECTOR_DIRECTORY/completed"
PENDING_FILE="$CONNECTOR_DIRECTORY/pending.env"
JOB_ID="${WHISPERX_CONNECTOR_JOB_ID:-$(basename -- "$CHECKPOINT_DIRECTORY")}"
JOB_ID="$(printf '%s' "$JOB_ID" | tr -c 'A-Za-z0-9._-' '_')"
JOB_ID="${JOB_ID##_}"
JOB_ID="${JOB_ID%%_}"
if [ -z "$JOB_ID" ]; then
    JOB_ID="whisperx-job"
fi

mkdir -p "$OUTBOX_DIRECTORY" "$ACK_DIRECTORY" "$COMPLETED_DIRECTORY"

if [ -f "$PENDING_FILE" ]; then
    echo "ERROR: A connector checkpoint is already pending: $PENDING_FILE" >&2
    exit 1
fi

COMPLETED_SEGMENT_COUNT="$(jq -r '.result.segments | length' "$CHECKPOINT_PATH")"
if ! [[ "$COMPLETED_SEGMENT_COUNT" =~ ^[1-9][0-9]*$ ]]; then
    echo "ERROR: Partial transcription checkpoint has no completed segments: $CHECKPOINT_PATH" >&2
    exit 1
fi

SEGMENT_NUMBER="$(printf '%06d' "$COMPLETED_SEGMENT_COUNT")"
REMOTE_NAME="transcription-partial-$SEGMENT_NUMBER.json"
REMOTE_PATH="/home_wbraswell/school/utd/whisperx/jobs/$JOB_ID/checkpoints/$REMOTE_NAME"
SNAPSHOT_PATH="$OUTBOX_DIRECTORY/$REMOTE_NAME"
ACK_PATH="$ACK_DIRECTORY/transcription-partial-$SEGMENT_NUMBER.ok"
COMPLETED_PENDING_FILE="$COMPLETED_DIRECTORY/transcription-partial-$SEGMENT_NUMBER.env"
TEMP_SNAPSHOT_PATH="$SNAPSHOT_PATH.tmp.$$"
TEMP_PENDING_FILE="$PENDING_FILE.tmp.$$"

jq -c '{
    format: "whisperx-connector-transcription-delta-v1",
    audio_name: .audio_name,
    audio_size: .audio_size,
    audio_sha256: .audio_sha256,
    source_version: .source_version,
    language: .result.language,
    completed_segment_count: (.result.segments | length),
    segment: .result.segments[-1]
}' "$CHECKPOINT_PATH" > "$TEMP_SNAPSHOT_PATH"
printf '\n' >> "$TEMP_SNAPSHOT_PATH"
mv -f -- "$TEMP_SNAPSHOT_PATH" "$SNAPSHOT_PATH"

if ! jq -e '.format == "whisperx-connector-transcription-delta-v1" and (.completed_segment_count | type == "number") and (.segment | type == "object")' "$SNAPSHOT_PATH" >/dev/null; then
    echo "ERROR: Generated connector delta is invalid: $SNAPSHOT_PATH" >&2
    exit 1
fi

SNAPSHOT_SIZE="$(wc -c < "$SNAPSHOT_PATH")"
if [ "$SNAPSHOT_SIZE" -gt "$MAX_DELTA_TEXT_BYTES" ]; then
    echo "ERROR: Connector delta is $SNAPSHOT_SIZE bytes, exceeding safe inline connector limit $MAX_DELTA_TEXT_BYTES bytes: $SNAPSHOT_PATH" >&2
    exit 1
fi
SNAPSHOT_SHA256="$(sha256sum "$SNAPSHOT_PATH" | awk '{print $1}')"
EVENT_TIMESTAMP="$(date -u +%Y%m%d_%H%M%S_%N)"

{
    printf 'format=%s\n' 'whisperx-connector-pending-v1'
    printf 'hook_version=%s\n' "$SCRIPT_VERSION"
    printf 'event_id=%s\n' "$EVENT_TIMESTAMP"
    printf 'job_id=%s\n' "$JOB_ID"
    printf 'checkpoint_stage=%s\n' "$CHECKPOINT_STAGE"
    printf 'completed_segment_count=%s\n' "$COMPLETED_SEGMENT_COUNT"
    printf 'checkpoint_path=%s\n' "$CHECKPOINT_PATH"
    printf 'snapshot_path=%s\n' "$SNAPSHOT_PATH"
    printf 'snapshot_size=%s\n' "$SNAPSHOT_SIZE"
    printf 'snapshot_sha256=%s\n' "$SNAPSHOT_SHA256"
    printf 'remote_path=%s\n' "$REMOTE_PATH"
    printf 'ack_path=%s\n' "$ACK_PATH"
    printf 'created_utc=%s\n' "$EVENT_TIMESTAMP"
} > "$TEMP_PENDING_FILE"
mv -f -- "$TEMP_PENDING_FILE" "$PENDING_FILE"

printf 'WhisperX connector checkpoint pending: %s\n' "$REMOTE_PATH"
printf 'WhisperX connector delta snapshot: %s (%s bytes)\n' "$SNAPSHOT_PATH" "$SNAPSHOT_SIZE"
printf 'WhisperX connector checkpoint waiting for ACK: %s\n' "$ACK_PATH"

WAIT_START_SECONDS="$SECONDS"
while [ ! -f "$ACK_PATH" ]; do
    sleep "$HEARTBEAT_SECONDS"
    WAITED_SECONDS=$((SECONDS - WAIT_START_SECONDS))
    printf 'WhisperX connector checkpoint still waiting for ACK, elapsed %d second(s): %s\n' "$WAITED_SECONDS" "$REMOTE_PATH"
    if [ "$ACK_TIMEOUT_SECONDS" -gt 0 ] && [ "$WAITED_SECONDS" -ge "$ACK_TIMEOUT_SECONDS" ]; then
        echo "ERROR: Timed out waiting for connector checkpoint ACK: $ACK_PATH" >&2
        exit 1
    fi
done

if ! grep -Fxq "status=uploaded" "$ACK_PATH" || ! grep -Fxq "remote_path=$REMOTE_PATH" "$ACK_PATH" || ! grep -Fxq "completed_segment_count=$COMPLETED_SEGMENT_COUNT" "$ACK_PATH" || ! grep -Fxq "remote_size=$SNAPSHOT_SIZE" "$ACK_PATH"; then
    echo "ERROR: Connector checkpoint ACK is invalid: $ACK_PATH" >&2
    exit 1
fi

mv -f -- "$PENDING_FILE" "$COMPLETED_PENDING_FILE"
printf 'WhisperX connector checkpoint ACK received: %s\n' "$REMOTE_PATH"
