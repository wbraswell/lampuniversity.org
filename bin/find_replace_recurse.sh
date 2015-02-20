#!/bin/bash
# Copyright © 2014, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

echo EXAMPLES:
echo replace all occurrences of 'FOO' with 'BAR'
echo $ find_replace_recurse.sh 'FOO' 'BAR' ./
echo replace all occurrences of '[ ANYTHING GOES HERE 123 #@$ ]' with '< ANYTHING GOES HERE 123 #@$ >'
echo $ find_replace_recurse.sh '\[(.*)\]' '\<\1\>' ./
echo BACKSLASH-ESCAPED CHARACTERS: \& \[ \] \< \> \{ \} \|
echo

echo "ABOUT TO RECURSIVELY FIND AND REPLACE"
echo "find text: $1"
echo "replace text: $2"
echo "directory: $3"

read -p "Are you sure? " -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    sed -ri -e "s/$1/$2/g" $(grep -Elr --binary-files=without-match "$1" "$3")

    # wrongly edits binary files, will corrupt .git/index files, database files, etc
#    find $3 -type f -readable -writable -exec sed -i "s/$1/$2/g" {} \;
fi
