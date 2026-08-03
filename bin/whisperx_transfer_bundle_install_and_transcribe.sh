#!/usr/bin/env bash
# v0.004
set -euo pipefail

SCRIPT_VERSION="0.004"
PARTS_DIRECTORY="${WHISPERX_TRANSFER_DIRECTORY:-/mnt/data}"
INSTALL_ROOT="$PARTS_DIRECTORY/whisperx-full"
EXTRACT_ROOT="$INSTALL_ROOT/extracted"
RUNTIME_DIRECTORY="$INSTALL_ROOT/runtime"
SOURCE_EXTRACT_ROOT="$INSTALL_ROOT/source-extracted"
BIN_DIRECTORY="$INSTALL_ROOT/bin"
INPUT_FILE="${1:-$PARTS_DIRECTORY/2026-04-22_14-01-00.mp4}"
SPEAKER_COUNT="${2:-3}"
DROPBOX_ROOT="${WHISPERX_DROPBOX_ROOT:-/home_wbraswell/school/utd/whisperx}"

command -v awk
command -v basename
command -v cat
command -v find
command -v head
command -v sha256sum
command -v sort
command -v tar
command -v tail

select_latest_file() {
    local pattern="$1"
    find "$PARTS_DIRECTORY" -maxdepth 1 -type f -name "$pattern" -printf '%f\n' \
        | LC_ALL=C sort \
        | tail -n 1
}

PARTS_MANIFEST_NAME="${WHISPERX_RUNTIME_PARTS_MANIFEST:-}"
if [ -z "$PARTS_MANIFEST_NAME" ]; then
    PARTS_MANIFEST_NAME="$(select_latest_file 'whisperx_transfer_bundle_*.parts.sha256')"
fi
if [ -z "$PARTS_MANIFEST_NAME" ]; then
    echo "ERROR: No WhisperX dependency parts manifest was found in $PARTS_DIRECTORY." >&2
    exit 1
fi
PARTS_MANIFEST="$PARTS_DIRECTORY/$(basename -- "$PARTS_MANIFEST_NAME")"
RUNTIME_BUNDLE_NAME="$(basename -- "$PARTS_MANIFEST" .parts.sha256)"
ARCHIVE_MANIFEST="$PARTS_DIRECTORY/$RUNTIME_BUNDLE_NAME.tar.gz.sha256"
ARCHIVE="$PARTS_DIRECTORY/$RUNTIME_BUNDLE_NAME.tar.gz"
RUNTIME_BUNDLE_DIRECTORY="$EXTRACT_ROOT/$RUNTIME_BUNDLE_NAME"

SOURCE_MANIFEST_NAME="${WHISPERX_SOURCE_MANIFEST:-}"
if [ -z "$SOURCE_MANIFEST_NAME" ]; then
    SOURCE_MANIFEST_NAME="$(select_latest_file 'whisperX-fork_*.tar.gz.sha256')"
fi
if [ -z "$SOURCE_MANIFEST_NAME" ]; then
    echo "ERROR: No WhisperX fork source manifest was found in $PARTS_DIRECTORY." >&2
    exit 1
fi
SOURCE_MANIFEST="$PARTS_DIRECTORY/$(basename -- "$SOURCE_MANIFEST_NAME")"
SOURCE_ARCHIVE="$PARTS_DIRECTORY/$(basename -- "$SOURCE_MANIFEST" .sha256)"

WRAPPER_SOURCE="$PARTS_DIRECTORY/whisperx_transcribe_accents.sh"
DROPBOX_HELPER_SOURCE="$PARTS_DIRECTORY/whisperx_dropbox_checkpoint_sync.pl"

test -f "$PARTS_MANIFEST"
test -f "$ARCHIVE_MANIFEST"
test -f "$SOURCE_MANIFEST"
test -f "$SOURCE_ARCHIVE"
test -f "$WRAPPER_SOURCE"
test -f "$DROPBOX_HELPER_SOURCE"

EXPECTED_SOURCE_SHA256="$(awk '{print $1; exit}' "$SOURCE_MANIFEST")"
ACTUAL_SOURCE_SHA256="$(sha256sum "$SOURCE_ARCHIVE" | awk '{print $1}')"
test "$ACTUAL_SOURCE_SHA256" = "$EXPECTED_SOURCE_SHA256"
echo "$(basename -- "$SOURCE_ARCHIVE"): OK"

PART_FILES=()
while read -r EXPECTED_PART_SHA256 MANIFEST_PART_PATH; do
    PART_FILE="$PARTS_DIRECTORY/$(basename -- "$MANIFEST_PART_PATH")"
    test -f "$PART_FILE"
    ACTUAL_PART_SHA256="$(sha256sum "$PART_FILE" | awk '{print $1}')"
    test "$ACTUAL_PART_SHA256" = "$EXPECTED_PART_SHA256"
    echo "$(basename -- "$PART_FILE"): OK"
    PART_FILES+=("$PART_FILE")
done < "$PARTS_MANIFEST"

test "${#PART_FILES[@]}" -gt 0

rm -f "$ARCHIVE"
cat "${PART_FILES[@]}" > "$ARCHIVE"

EXPECTED_ARCHIVE_SHA256="$(awk '{print $1; exit}' "$ARCHIVE_MANIFEST")"
ACTUAL_ARCHIVE_SHA256="$(sha256sum "$ARCHIVE" | awk '{print $1}')"
test "$ACTUAL_ARCHIVE_SHA256" = "$EXPECTED_ARCHIVE_SHA256"
echo "$(basename -- "$ARCHIVE"): OK"

rm -rf "$INSTALL_ROOT"
mkdir -p "$EXTRACT_ROOT"
mkdir -p "$SOURCE_EXTRACT_ROOT"
mkdir -p "$BIN_DIRECTORY"

tar -xzf "$ARCHIVE" -C "$EXTRACT_ROOT"
test -d "$RUNTIME_BUNDLE_DIRECTORY"

(
    cd "$RUNTIME_BUNDLE_DIRECTORY"
    sha256sum -c wheelhouse.sha256
    sha256sum -c install-inputs.sha256
)

BUNDLED_PYTHON="$RUNTIME_BUNDLE_DIRECTORY/python-runtime/bin/python3.13"
test -x "$BUNDLED_PYTHON"
"$BUNDLED_PYTHON" --version

"$BUNDLED_PYTHON" -m venv --copies "$RUNTIME_DIRECTORY"

"$RUNTIME_DIRECTORY/bin/python" -m pip install \
    --no-index \
    --find-links "$RUNTIME_BUNDLE_DIRECTORY/wheelhouse" \
    --requirement "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt"

SOURCE_ARCHIVE_LIST="$INSTALL_ROOT/source-archive-list.txt"
tar -tzf "$SOURCE_ARCHIVE" > "$SOURCE_ARCHIVE_LIST"
SOURCE_TOP_LEVEL="$(head -n 1 "$SOURCE_ARCHIVE_LIST" | cut -d/ -f1)"
if [ -z "$SOURCE_TOP_LEVEL" ]; then
    echo "ERROR: Unable to determine the source archive top-level directory." >&2
    exit 1
fi

tar -xzf "$SOURCE_ARCHIVE" -C "$SOURCE_EXTRACT_ROOT"
SOURCE_DIRECTORY="$SOURCE_EXTRACT_ROOT/$SOURCE_TOP_LEVEL"
test -f "$SOURCE_DIRECTORY/pyproject.toml"

"$RUNTIME_DIRECTORY/bin/python" -m pip install \
    --no-deps \
    --no-build-isolation \
    "$SOURCE_DIRECTORY"

"$RUNTIME_DIRECTORY/bin/python" -m pip check

"$RUNTIME_DIRECTORY/bin/python" -c 'import av; print("av", av.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import ctranslate2; print("ctranslate2", ctranslate2.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import faster_whisper; print("faster_whisper", faster_whisper.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import onnxruntime; print("onnxruntime", onnxruntime.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import torch; print("torch", torch.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import torchaudio; print("torchaudio", torchaudio.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import transformers; print("transformers", transformers.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'import pyannote.audio; print("pyannote.audio", pyannote.audio.__version__)'
"$RUNTIME_DIRECTORY/bin/python" -c 'from importlib.metadata import version; print("whisperx", version("whisperx"))'

cp "$WRAPPER_SOURCE" "$BIN_DIRECTORY/whisperx_transcribe_accents.sh"
cp "$DROPBOX_HELPER_SOURCE" "$BIN_DIRECTORY/whisperx_dropbox_checkpoint_sync.pl"
chmod a+x "$BIN_DIRECTORY/whisperx_transcribe_accents.sh"
chmod a+x "$BIN_DIRECTORY/whisperx_dropbox_checkpoint_sync.pl"

if [ -f "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/whisperx_correct_transcript.pl" ]; then
    cp "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/whisperx_correct_transcript.pl" \
        "$BIN_DIRECTORY/whisperx_correct_transcript.pl"
    chmod a+x "$BIN_DIRECTORY/whisperx_correct_transcript.pl"
fi

if [ -f "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/whisperx_corrections.template.json" ]; then
    cp "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/whisperx_corrections.template.json" \
        "$BIN_DIRECTORY/whisperx_corrections.template.json"
fi

cat > "$BIN_DIRECTORY/source_this_to_export_nonperl_paths.sh" <<ENVIRONMENT
#!/usr/bin/env bash
# v0.002
export PATH="$RUNTIME_DIRECTORY/bin:$BIN_DIRECTORY:\$PATH"
export XDG_CACHE_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache"
export HF_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface"
export HUGGINGFACE_HUB_CACHE="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface/hub"
export TRANSFORMERS_CACHE="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface/hub"
export TORCH_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache/torch"
export NLTK_DATA="$RUNTIME_BUNDLE_DIRECTORY/cache/nltk_data"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
ENVIRONMENT
chmod a+x "$BIN_DIRECTORY/source_this_to_export_nonperl_paths.sh"

export PATH="$RUNTIME_DIRECTORY/bin:$BIN_DIRECTORY:$PATH"
export XDG_CACHE_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache"
export HF_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface"
export HUGGINGFACE_HUB_CACHE="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface/hub"
export TRANSFORMERS_CACHE="$RUNTIME_BUNDLE_DIRECTORY/cache/huggingface/hub"
export TORCH_HOME="$RUNTIME_BUNDLE_DIRECTORY/cache/torch"
export NLTK_DATA="$RUNTIME_BUNDLE_DIRECTORY/cache/nltk_data"
export HF_HUB_OFFLINE=1
export TRANSFORMERS_OFFLINE=1
export HF_TOKEN="${HF_TOKEN:-offline-cache-only}"
export WHISPERX_DROPBOX_ROOT="$DROPBOX_ROOT"
export WHISPERX_SOURCE_VERSION="$(basename -- "$SOURCE_ARCHIVE")"

# Restore the recording from the configured Dropbox root when it is absent locally.
if [ ! -f "$INPUT_FILE" ]; then
    if [ -z "${WHISPERX_DROPBOX_CREDENTIALS_FILE:-}" ] &&
       [ -z "${DROPBOX_ACCESS_TOKEN:-}" ] &&
       { [ -z "${DROPBOX_APP_KEY:-}" ] || [ -z "${DROPBOX_APP_SECRET:-}" ] || [ -z "${DROPBOX_REFRESH_TOKEN:-}" ]; }; then
        echo "ERROR: Input file is missing and Dropbox credentials are unavailable: $INPUT_FILE" >&2
        exit 1
    fi
    DOWNLOAD_ARGUMENTS=(
        download-file
        --dropbox-path "$DROPBOX_ROOT/$(basename -- "$INPUT_FILE")"
        --local-path "$INPUT_FILE"
        --dropbox-root "$DROPBOX_ROOT"
    )
    if [ -n "${WHISPERX_DROPBOX_CREDENTIALS_FILE:-}" ]; then
        DOWNLOAD_ARGUMENTS+=(--credentials-file "$WHISPERX_DROPBOX_CREDENTIALS_FILE")
    fi
    perl "$BIN_DIRECTORY/whisperx_dropbox_checkpoint_sync.pl" "${DOWNLOAD_ARGUMENTS[@]}"
fi

echo "WhisperX installer version: $SCRIPT_VERSION"
echo "WhisperX dependency bundle: $RUNTIME_BUNDLE_NAME"
echo "WhisperX source archive: $(basename -- "$SOURCE_ARCHIVE")"

whisperx --help

"$BIN_DIRECTORY/whisperx_transcribe_accents.sh" \
    "$INPUT_FILE" \
    "$SPEAKER_COUNT"
