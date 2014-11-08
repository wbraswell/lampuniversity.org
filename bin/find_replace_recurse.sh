#!/bin/bash
# Copyright © 2014, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

echo "ABOUT TO RECURSIVELY FIND AND REPLACE"
echo "directory: $1"
echo "find text: $2"
echo "replace text: $3"

read -p "Are you sure? " -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    sed -ri -e "s/$2/$3/g" $(grep -Elr --binary-files=without-match "$2" "$1")

    # wrongly edits binary files, will corrupt .git/index files, database files, etc
#    find $1 -type f -readable -writable -exec sed -i "s/$2/$3/g" {} \;
fi
