#!/usr/bin/bash
# Copyright © 2025, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# create tarball from directory containing git repository
VERSION='0.002_000'

# check if an argument was provided;
# the "$#" variable holds the number of command-line arguments
if [ "$#" -eq 0 ]; then
    echo "Error: No argument was provided." >&2
    echo "Usage: $0 <directory_name>" >&2
    exit 1
fi

# store the sanitized argument in a new variable, removing any trailing slash
DIRNAME="${1%/}"

# check if the sanitized argument is a valid directory;
# the "-d" flag tests if a path exists and is a directory
if [ ! -d "$DIRNAME" ]; then
    echo "Error: '$1' is not a valid directory in the current working directory." >&2
    exit 1
fi

echo "Received input argument: $1"
echo "Processed directory name: $DIRNAME"

# create a unique archive name using a long date/time serialization string
STAMP="$(date +%Y%m%d_%H%M%S)"
ARCHIVE="${DIRNAME}__${STAMP}.tar.gz"

echo "Removing existing archive (if any): $ARCHIVE"
rm -f "$ARCHIVE"

echo "Changing into directory: $DIRNAME"
cd "$DIRNAME"

echo "Running inline_clean.sh"
inline_clean.sh

echo "Returning to previous directory"
cd ..

echo "Creating new archive: $ARCHIVE"
tar -czvf "$ARCHIVE" --exclude=.git "$DIRNAME"

echo
echo "Done creating new archive: $ARCHIVE"
