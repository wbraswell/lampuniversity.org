#!/usr/bin/bash
# Copyright © 2025, 2026, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# create tarball from directory containing git repository
VERSION='0.009'

# check if an argument was provided;
# the "$#" variable holds the number of command-line arguments
if [ "$#" -eq 0 ]; then
    echo "Error: No argument was provided." >&2
    echo "Usage: $0 <directory_name> [--full-git] [--output-dir=DIR] [--quiet] [tar arguments ...]" >&2
    exit 1
fi

# store the sanitized argument in a new variable, removing any trailing slash
if [ "$1" = "--full-git" ] || [ "$1" = "--quiet" ] || [ "$1" = "--output-dir" ] || [[ "$1" == --output-dir=* ]]; then
    echo "Error: The directory name must be the first argument." >&2
    exit 1
fi
DIRNAME="${1%/}"
shift
FULL_GIT=false
OUTPUT_DIR=""
QUIET=false
OUTPUT_DIR_SEEN=false
while [ "$#" -gt 0 ]; do
    case "$1" in
        --full-git)
            if [ "$FULL_GIT" = true ] || [ "$OUTPUT_DIR_SEEN" = true ]; then
                echo "Error: --full-git must precede --output-dir=DIR and must not be repeated." >&2
                exit 1
            fi
            FULL_GIT=true
            shift
            ;;
        --output-dir=*)
            if [ "$OUTPUT_DIR_SEEN" = true ]; then
                echo "Error: --output-dir=DIR must not be repeated." >&2
                exit 1
            fi
            OUTPUT_DIR_SEEN=true
            OUTPUT_DIR="${1#--output-dir=}"
            shift
            if [ -z "$OUTPUT_DIR" ] || [ ! -d "$OUTPUT_DIR" ]; then
                echo "Error: The --output-dir path must name an existing directory." >&2
                exit 1
            fi
            OUTPUT_DIR="$(cd -- "$OUTPUT_DIR" && pwd)" || exit 1
            ;;
        --quiet)
            if [ "$QUIET" = true ]; then
                echo "Error: --quiet must not be repeated." >&2
                exit 1
            fi
            QUIET=true
            shift
            ;;
        *)
            break
            ;;
    esac
done
EXTRA_TAR_ARGS=("$@")
for ARG in "${EXTRA_TAR_ARGS[@]}"; do
    if [ "$ARG" = "--full-git" ] || [ "$ARG" = "--quiet" ] || [ "$ARG" = "--output-dir" ] || [[ "$ARG" == --output-dir=* ]]; then
        echo "Error: --full-git, --output-dir=DIR, and --quiet must precede any tar arguments." >&2
        exit 1
    fi
done

# preserve standard output for the single quiet-mode summary
if [ "$QUIET" = true ]; then
    exec 3>&1 1>/dev/null
fi

# check if the sanitized argument is a valid directory;
# the "-d" flag tests if a path exists and is a directory
if [ ! -d "$DIRNAME" ]; then
    echo "Error: '$DIRNAME' is not a valid directory in the current working directory." >&2
    exit 1
fi
ORIGINAL_DIR="$PWD"
REPO_PATH="$(cd -- "$DIRNAME" && pwd -P)" || exit 1
REPO_PARENT="$(dirname -- "$REPO_PATH")"
REPO_NAME="$(basename -- "$REPO_PATH")"

echo "Received input argument: $DIRNAME"
echo "Processed directory name: $DIRNAME"
if [ "${#EXTRA_TAR_ARGS[@]}" -gt 0 ]; then
    echo "Extra tar arguments: ${EXTRA_TAR_ARGS[*]}"
fi

# create a unique archive name using a long date/time serialization string
STAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE_NAME_SUFFIX=""
if [ "$FULL_GIT" = true ]; then
    ARCHIVE_NAME_SUFFIX="_FULL_GIT"
fi
ARCHIVE="${REPO_PARENT}/${REPO_NAME}${ARCHIVE_NAME_SUFFIX}__${STAMP}.tar.gz"
if [ -n "$OUTPUT_DIR" ]; then
    ARCHIVE="${OUTPUT_DIR}/${REPO_NAME}${ARCHIVE_NAME_SUFFIX}__${STAMP}.tar.gz"
fi

echo "Removing existing archive (if any): $ARCHIVE"
rm -f "$ARCHIVE" || exit 1

echo "Changing into directory: $DIRNAME"
cd "$DIRNAME" || exit 1

echo "Running inline_clean.sh"
inline_clean.sh || exit 1

echo "Returning to previous directory"
cd -- "$ORIGINAL_DIR" || exit 1

echo "Creating new archive: $ARCHIVE"
if [ "$FULL_GIT" = true ]; then
    tar -czvf "$ARCHIVE" "${EXTRA_TAR_ARGS[@]}" -C "$REPO_PARENT" "$REPO_NAME"
else
    tar -czvf "$ARCHIVE" --exclude=.git "${EXTRA_TAR_ARGS[@]}" -C "$REPO_PARENT" "$REPO_NAME"
fi
TAR_STATUS=$?
if [ "$TAR_STATUS" -ne 0 ]; then
    echo "Error: tar failed with exit status $TAR_STATUS; archive was not created successfully: $ARCHIVE" >&2
    rm -f "$ARCHIVE"
    exit "$TAR_STATUS"
fi

if [ "$QUIET" = true ]; then
    FILE_COUNT="$(set -o pipefail; tar -tzf "$ARCHIVE" | awk '!/\/$/ { count++ } END { print count + 0 }')"
    COUNT_STATUS=$?
    if [ "$COUNT_STATUS" -ne 0 ]; then
        echo "Error: could not count archived files: $ARCHIVE" >&2
        exit "$COUNT_STATUS"
    fi
    printf '%s files added to tarball %s\n' "$FILE_COUNT" "$ARCHIVE" >&3
else
    echo
    echo "Done creating new archive: $ARCHIVE"
fi
