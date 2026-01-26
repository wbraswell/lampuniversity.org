#!/usr/bin/env bash
# Copyright © 2025, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
VERSION='0.001_000'

# copy_perl_with_version.sh
#
# Given one or more Perl source files, extract the first $VERSION assignment
# (either:  our $VERSION = ...;   or:  $VERSION = ...; )
# and copy each file into /tmp using the filename pattern:
#
#     /tmp/<Basename>__v<version-token><original-extension>
#
# Examples:
#   lib/Perl/Class.pm  (our $VERSION = 0.001_000;)  -> /tmp/Class__v0.001_000.pm
#   bin/foo.pl         ($VERSION = 1.2;)            -> /tmp/foo__v1.2.pl
#
# Notes:
# - The output is ALWAYS directly under /tmp (no subdirectories).
# - This script does NOT modify the file contents; it only copies and renames.
# - It errors out if it can't find a $VERSION assignment.

set -euo pipefail

die() {
    echo "ERROR: $*" >&2
    exit 1
}

if [[ $# -lt 1 ]]; then
    die "Usage: $0 <perl-file> [more-perl-files ...]"
fi

OUT_DIR="/tmp"

for src in "$@"; do
    [[ -f "$src" ]] || die "Not a file: $src"

    # Basename only; ignore any directories (lib/Perl/, etc.)
    base="$(basename -- "$src")"

    # Split basename into "name" + "extension" (keeps last extension only).
    # Examples:
    #   Class.pm -> name=Class ext=.pm
    #   foo.pl   -> name=foo   ext=.pl
    #   README   -> name=README ext=""
    name="$base"
    ext=""
    if [[ "$base" == *.* ]]; then
        ext=".${base##*.}"
        name="${base%$ext}"
    fi

    # Extract the first $VERSION assignment line and pull out the version token.
    #
    # Accepts:
    #   our $VERSION = 0.001_000;
    #   $VERSION = 0.001_000;
    #   our $VERSION = '0.001_000';
    #   $VERSION = "0.001_000";
    #
    # Captures version tokens like: 0.001_000, 1.2, v5.38.0, 0.153_000, etc.
    version="$(
        perl -ne '
            if (m/^\s*(?:our\s+)?\$VERSION\s*=\s*([qQ]?[qw]?|)(["'\'']?)([0-9v._]+)\2\s*;/) {
                print $3;
                exit 0;
            }
        ' "$src"
    )"

    [[ -n "$version" ]] || die "Could not find a \$VERSION assignment in: $src"

    # Build destination path: /tmp/<name>__v<version><ext>
    dest="${OUT_DIR}/${name}__v${version}${ext}"

    # Copy preserving mode/timestamps when possible.
    cp -a -- "$src" "$dest"

    echo "Copied: $src -> $dest"
done
