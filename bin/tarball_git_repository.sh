#!/usr/bin/bash

# check if an argument was provided;
# the "$#" variable holds the number of command-line arguments
if [ "$#" -eq 0 ]; then
    echo "Error: No argument was provided." >&2
    echo "Usage: $0 <directory_name>" >&2
    exit 1
fi

# store the sanitized argument in a new variable, removing any trailing slash
DIRNAME="${1%/}"

# Check if the sanitized argument is a valid directory
# check if the sanitized argument is a valid directory;
# the "-d" flag tests if a path exists and is a directory
if [ ! -d "$DIRNAME" ]; then
    echo "Error: '$1' is not a valid directory in the current working directory." >&2
    exit 1
fi

echo "Received input argument: $1"
echo "Processed directory name: $DIRNAME"

echo "Removing existing archive: $DIRNAME.tar.gz"
rm "$DIRNAME.tar.gz"

echo "Changing into directory: $DIRNAME"
cd "$DIRNAME"

echo "Running inline_clean.sh"
inline_clean.sh

echo "Returning to previous directory"
cd ..

echo "Creating new archive: $DIRNAME.tar.gz"
tar -czvf "$DIRNAME.tar.gz" --exclude=.git "$DIRNAME"

echo
echo "Done creating new archive: $DIRNAME.tar.gz"
