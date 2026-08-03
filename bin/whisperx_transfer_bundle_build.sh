#!/usr/bin/env bash
# v0.003
set -euo pipefail

SCRIPT_VERSION="0.003"
BUILD_MODE="${1:-all}"
BUILD_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RUNTIME_BUNDLE_NAME="whisperx_transfer_bundle_$BUILD_TIMESTAMP"
SOURCE_ARCHIVE_NAME="whisperX-fork_$BUILD_TIMESTAMP.tar.gz"
BUILD_SET_MANIFEST_NAME="whisperx_build_set_$BUILD_TIMESTAMP.manifest.txt"
BUILD_ROOT="$HOME/whisperx_transfer_build_$BUILD_TIMESTAMP"
RUNTIME_BUNDLE_DIRECTORY="$BUILD_ROOT/$RUNTIME_BUNDLE_NAME"
SOURCE_DIRECTORY="$HOME/repos_github/whisperX-fork"
WORKING_PYTHON="$HOME/.venv/bin/python"
CORRECTOR_FILE="${WHISPERX_CORRECTOR_FILE:-$HOME/Downloads/whisperx_correct_transcript.pl}"
CORRECTIONS_TEMPLATE_FILE="${WHISPERX_CORRECTIONS_TEMPLATE_FILE:-$HOME/Downloads/whisperx_corrections.template.json}"
UV_BINARY="$HOME/.local/bin/uv"
BUILD_ENVIRONMENT="$BUILD_ROOT/build-python313"
VERIFY_ENVIRONMENT="$BUILD_ROOT/verify-python313"
PARTS_PREFIX="$HOME/$RUNTIME_BUNDLE_NAME.tar.gz.part-"
PARTS_MANIFEST="$HOME/$RUNTIME_BUNDLE_NAME.parts.sha256"
ARCHIVE_MANIFEST="$HOME/$RUNTIME_BUNDLE_NAME.tar.gz.sha256"
SOURCE_ARCHIVE="$HOME/$SOURCE_ARCHIVE_NAME"
SOURCE_MANIFEST="$HOME/$SOURCE_ARCHIVE_NAME.sha256"
BUILD_SET_MANIFEST="$HOME/$BUILD_SET_MANIFEST_NAME"
PYTORCH_CPU_INDEX="https://download.pytorch.org/whl/cpu"

case "$BUILD_MODE" in
    all | dependencies | source)
        ;;
    *)
        echo "Usage: $0 [all|dependencies|source]" >&2
        exit 1
        ;;
esac

command -v date
command -v git
command -v sha256sum
command -v tar

test -d "$SOURCE_DIRECTORY"
test -f "$SOURCE_DIRECTORY/pyproject.toml"

rm -rf "$BUILD_ROOT"
rm -f "$BUILD_SET_MANIFEST"
mkdir -p "$BUILD_ROOT"

build_source_archive() {
    local source_parent
    local source_name

    source_parent="$(dirname -- "$SOURCE_DIRECTORY")"
    source_name="$(basename -- "$SOURCE_DIRECTORY")"

    rm -f "$SOURCE_ARCHIVE"
    rm -f "$SOURCE_MANIFEST"

    tar \
        --exclude="$source_name/.venv" \
        --exclude="$source_name/.pytest_cache" \
        --exclude="$source_name/.ruff_cache" \
        --exclude="$source_name/build" \
        --exclude="$source_name/dist" \
        --exclude='*/__pycache__' \
        --exclude='*.pyc' \
        -czf "$SOURCE_ARCHIVE" \
        -C "$source_parent" \
        "$source_name"

    (
        cd "$HOME"
        sha256sum "$SOURCE_ARCHIVE_NAME" > "$SOURCE_ARCHIVE_NAME.sha256"
    )

    {
        echo "source_archive=$SOURCE_ARCHIVE_NAME"
        echo "source_manifest=$SOURCE_ARCHIVE_NAME.sha256"
        echo "source_commit=$(git -C "$SOURCE_DIRECTORY" rev-parse HEAD)"
        echo "source_status_begin"
        git -C "$SOURCE_DIRECTORY" status --short
        echo "source_status_end"
    } >> "$BUILD_SET_MANIFEST"

    echo "Created independently replaceable WhisperX fork archive:"
    ls -lh "$SOURCE_ARCHIVE" "$SOURCE_MANIFEST"
}

build_dependency_bundle() {
    command -v curl
    command -v readlink
    command -v split
    command -v xargs
    test -x "$WORKING_PYTHON"

    rm -f "${PARTS_PREFIX}"*
    rm -f "$PARTS_MANIFEST"
    rm -f "$ARCHIVE_MANIFEST"

    mkdir -p "$RUNTIME_BUNDLE_DIRECTORY/cache"
    mkdir -p "$RUNTIME_BUNDLE_DIRECTORY/wheelhouse"
    mkdir -p "$RUNTIME_BUNDLE_DIRECTORY/optional-tools"

    curl -LsSf https://astral.sh/uv/install.sh -o "$BUILD_ROOT/uv-install.sh"
    sh "$BUILD_ROOT/uv-install.sh"

    "$UV_BINARY" python install 3.13
    MANAGED_PYTHON="$("$UV_BINARY" python find 3.13)"
    MANAGED_PYTHON_PREFIX="$(dirname "$(dirname "$(readlink -f "$MANAGED_PYTHON")")")"

    cp -a "$MANAGED_PYTHON_PREFIX" "$RUNTIME_BUNDLE_DIRECTORY/python-runtime"

    "$UV_BINARY" venv --python "$MANAGED_PYTHON" --seed "$BUILD_ENVIRONMENT"
    BUILD_PYTHON="$BUILD_ENVIRONMENT/bin/python"

    "$BUILD_PYTHON" -m pip install --upgrade pip setuptools wheel
    "$BUILD_PYTHON" -m pip install \
        --index-url "$PYTORCH_CPU_INDEX" \
        torch==2.8.0 \
        torchaudio==2.8.0 \
        torchvision==0.23.0
    "$BUILD_PYTHON" -m pip install "$SOURCE_DIRECTORY"
    "$BUILD_PYTHON" -m pip check

    "$BUILD_PYTHON" -c 'import av; print("av", av.__version__)'
    "$BUILD_PYTHON" -c 'import ctranslate2; print("ctranslate2", ctranslate2.__version__)'
    "$BUILD_PYTHON" -c 'import faster_whisper; print("faster_whisper", faster_whisper.__version__)'
    "$BUILD_PYTHON" -c 'import onnxruntime; print("onnxruntime", onnxruntime.__version__)'
    "$BUILD_PYTHON" -c 'import torch; print("torch", torch.__version__)'
    "$BUILD_PYTHON" -c 'import torchaudio; print("torchaudio", torchaudio.__version__)'
    "$BUILD_PYTHON" -c 'import transformers; print("transformers", transformers.__version__)'
    "$BUILD_PYTHON" -c 'import pyannote.audio; print("pyannote.audio", pyannote.audio.__version__)'
    "$BUILD_ENVIRONMENT/bin/whisperx" --help

    "$WORKING_PYTHON" -m pip freeze --all \
        > "$RUNTIME_BUNDLE_DIRECTORY/xubuntu-working-environment.freeze.txt"
    "$BUILD_PYTHON" -m pip freeze --all \
        > "$RUNTIME_BUNDLE_DIRECTORY/python313-complete-environment.freeze.txt"
    grep -viE '^whisperx([[:space:]]*@|==)' \
        "$RUNTIME_BUNDLE_DIRECTORY/python313-complete-environment.freeze.txt" \
        > "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt"
    LC_ALL=C sort -fu \
        "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt" \
        -o "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt"

    "$BUILD_PYTHON" -m pip wheel \
        --wheel-dir "$RUNTIME_BUNDLE_DIRECTORY/wheelhouse" \
        --extra-index-url "$PYTORCH_CPU_INDEX" \
        --requirement "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt"

    "$RUNTIME_BUNDLE_DIRECTORY/python-runtime/bin/python3.13" \
        -m venv --copies "$VERIFY_ENVIRONMENT"
    VERIFY_PYTHON="$VERIFY_ENVIRONMENT/bin/python"

    "$VERIFY_PYTHON" -m pip install \
        --no-index \
        --find-links "$RUNTIME_BUNDLE_DIRECTORY/wheelhouse" \
        --requirement "$RUNTIME_BUNDLE_DIRECTORY/runtime-requirements.txt"
    "$VERIFY_PYTHON" -m pip install \
        --no-deps \
        --no-build-isolation \
        "$SOURCE_DIRECTORY"
    "$VERIFY_PYTHON" -m pip check
    "$VERIFY_PYTHON" -c 'from importlib.metadata import version; print("whisperx", version("whisperx"))'
    "$VERIFY_ENVIRONMENT/bin/whisperx" --help

    (
        cd "$RUNTIME_BUNDLE_DIRECTORY"
        find wheelhouse -type f -print0 \
            | LC_ALL=C sort -z \
            | xargs -0 sha256sum \
            > wheelhouse.sha256
        sha256sum runtime-requirements.txt > install-inputs.sha256
    )

    if [ -f "$CORRECTOR_FILE" ]; then
        cp -a "$CORRECTOR_FILE" "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/"
    fi

    if [ -f "$CORRECTIONS_TEMPLATE_FILE" ]; then
        cp -a "$CORRECTIONS_TEMPLATE_FILE" "$RUNTIME_BUNDLE_DIRECTORY/optional-tools/"
    fi

    if [ -d "$HOME/.cache/huggingface" ]; then
        cp -a "$HOME/.cache/huggingface" "$RUNTIME_BUNDLE_DIRECTORY/cache/"
    fi

    if [ -d "$HOME/.cache/torch" ]; then
        cp -a "$HOME/.cache/torch" "$RUNTIME_BUNDLE_DIRECTORY/cache/"
    fi

    if [ -d "$HOME/.cache/whisper" ]; then
        cp -a "$HOME/.cache/whisper" "$RUNTIME_BUNDLE_DIRECTORY/cache/"
    fi

    if [ -d "$HOME/.cache/whisperx" ]; then
        cp -a "$HOME/.cache/whisperx" "$RUNTIME_BUNDLE_DIRECTORY/cache/"
    fi

    if [ -d "$HOME/nltk_data" ]; then
        cp -a "$HOME/nltk_data" "$RUNTIME_BUNDLE_DIRECTORY/cache/"
    fi

    find "$RUNTIME_BUNDLE_DIRECTORY/cache" -type f -printf '%P\t%s\n' \
        | LC_ALL=C sort \
        > "$RUNTIME_BUNDLE_DIRECTORY/cache-files.txt"

    printf '%s\n' "$MANAGED_PYTHON" \
        > "$RUNTIME_BUNDLE_DIRECTORY/python-build-source.txt"
    "$RUNTIME_BUNDLE_DIRECTORY/python-runtime/bin/python3.13" --version \
        > "$RUNTIME_BUNDLE_DIRECTORY/python-runtime-version.txt"

    printf '%s\n' \
        "Bundler version: $SCRIPT_VERSION" \
        "Build timestamp: $BUILD_TIMESTAMP" \
        "Dependency source used for resolution only: $SOURCE_DIRECTORY" \
        "WhisperX source is intentionally packaged separately." \
        "Python runtime: $MANAGED_PYTHON_PREFIX" \
        "PyTorch index: $PYTORCH_CPU_INDEX" \
        "Archive part size: 450 MiB" \
        > "$RUNTIME_BUNDLE_DIRECTORY/build-summary.txt"

    tar -czf - -C "$BUILD_ROOT" "$RUNTIME_BUNDLE_NAME" \
        | split -b 450M -d -a 3 - "$PARTS_PREFIX"

    (
        cd "$HOME"
        sha256sum "$(basename "$PARTS_PREFIX")"* \
            > "$(basename "$PARTS_MANIFEST")"
        cat "$(basename "$PARTS_PREFIX")"* \
            | sha256sum \
            | sed "s|  -$|  $RUNTIME_BUNDLE_NAME.tar.gz|" \
            > "$(basename "$ARCHIVE_MANIFEST")"
    )

    {
        echo "runtime_bundle=$RUNTIME_BUNDLE_NAME.tar.gz"
        echo "runtime_parts_manifest=$RUNTIME_BUNDLE_NAME.parts.sha256"
        echo "runtime_archive_manifest=$RUNTIME_BUNDLE_NAME.tar.gz.sha256"
    } >> "$BUILD_SET_MANIFEST"

    echo "Created timestamped dependency bundle:"
    ls -lh "${PARTS_PREFIX}"*
    ls -lh "$PARTS_MANIFEST" "$ARCHIVE_MANIFEST"
    du -sh "$RUNTIME_BUNDLE_DIRECTORY"
}

{
    echo "format=whisperx-build-set-v1"
    echo "bundler_version=$SCRIPT_VERSION"
    echo "build_timestamp=$BUILD_TIMESTAMP"
    echo "build_mode=$BUILD_MODE"
} > "$BUILD_SET_MANIFEST"

if [ "$BUILD_MODE" = "all" ] || [ "$BUILD_MODE" = "source" ]; then
    build_source_archive
fi

if [ "$BUILD_MODE" = "all" ] || [ "$BUILD_MODE" = "dependencies" ]; then
    build_dependency_bundle
fi

echo "Build-set manifest:"
ls -lh "$BUILD_SET_MANIFEST"
cat "$BUILD_SET_MANIFEST"
