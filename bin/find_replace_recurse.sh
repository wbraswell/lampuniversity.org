#!/bin/bash
# Copyright © 2014, 2015, 2016, 2017, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

VERSION=0.027_100

echo "This program currently uses grep for searching and sed for replacement."
echo "[[[ USAGE EXAMPLES ]]]"
echo "1. Replace All Occurrences Of 'FOO' With 'BAR'"
echo "$ find_replace_recurse.sh 'FOO' 'BAR' ./"
echo "2. Replace All Occurrences Of '[ ANYTHING GOES HERE 123 #@$ ]' With '< ANYTHING GOES HERE 123 #@$ >'"
echo "$ find_replace_recurse.sh '\[(.*)\]' '<\1>' ./"
echo 'NOTE: all regular expressions are currently greedy, beware of using (.*) when one line contains multiple matches'
echo "3. Replace All Occurrences Of \"FOO\" With \"'FOO'\" (In Other Words, Wrap FOO In Single Quotes)"
echo "$ find_replace_recurse.sh 'FOO' \"'FOO'\" ./"
echo "[[[ CHARACTER ESCAPE RULES ]]]"
echo '    BACKSLASH-ESCAPED CHARACTERS, find text,            single quotes:     @   $ % & * ( ) [ ] { }     | \ /'
echo 'NON-BACKSLASH-ESCAPED CHARACTERS, find text,            single quotes: "     #                     < >'
echo '    BACKSLASH-ESCAPED CHARACTERS, find text,            double quotes:               *                   \ / '
echo "NON-BACKSLASH-ESCAPED CHARACTERS, find text,            double quotes: '                           < >"
echo "             UNUSABLE CHARACTERS, find text,            double quotes:         $"
echo '    BACKSLASH-ESCAPED CHARACTERS, replace text,         single quotes:     @ #   % & *                   \ /'
echo '    BACKSLASH-ESCAPED CHARACTERS, replace text matches, single quotes: 1 2 3 ...'
echo 'NON-BACKSLASH-ESCAPED CHARACTERS, replace text,         single quotes: " `     $       ( ) [ ] { } < >'
echo "    BACKSLASH-ESCAPED CHARACTERS, replace text,         double quotes: ' \` @ # $ % & *                   \\ /"
echo

echo "ABOUT TO RECURSIVELY FIND AND REPLACE"
echo "find text:    '$1'"
echo "replace text: '$2'"
echo "directory:    $3"

if [[ $4 =~ ^YES$ ]]
then
    echo "Skipping prompt, I hope you're sure!"
    PASS=1;
else
    read -p "Are you sure? " -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        PASS=1;
    else
        PASS=0;
    fi
fi

if [ "$PASS" -eq 1 ]
then
    echo 'Recursively finding and replacing...'
    sed -ri -e "s/$1/$2/g" $(grep -Elr --binary-files=without-match "$1" "$3")

    # wrongly edits binary files, will corrupt .git/index files, database files, etc
#    find $3 -type f -readable -writable -exec sed -i "s/$1/$2/g" {} \;

    echo 'DONE!'
fi
