#!/bin/bash
# Copyright © 2014, 2015, 2016, 2017, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

VERSION=0.124_000

if [[ $4 =~ ^NO_HELP$ ]] || [[ $5 =~ ^NO_HELP$ ]]
then
    echo
else
    echo "This program uses 'grep -Plr' for searching and 'perl -e "... s/FIND/REPLACE/gxms ..."' for replacement."
    echo "Please see the Perl documentation for more info:  https://perldoc.perl.org/perlre.html"
    echo "[[[ USAGE EXAMPLES ]]]"
    echo "1. Replace All Occurrences Of 'FOO' With 'BAR'"
    echo "$ find_replace_recurse.sh 'FOO' 'BAR' ./"
    echo "2. Replace All Occurrences Of '[ ANYTHING GOES HERE 123 #@$ ]' With '< ANYTHING GOES HERE 123 #@$ >'"
    echo "$ find_replace_recurse.sh '\[(.*)\]' '<\$1>' ./"
    echo 'NOTE: all regular expressions are greedy by default, beware of using (.*) when one line contains multiple matches'
    echo "3. Replace All Occurrences Of \"FOO\" With \"'FOO'\" (In Other Words, Wrap FOO In Single Quotes)"
    echo "$ find_replace_recurse.sh 'FOO' \"'FOO'\" ./"
    echo "[[[ CHARACTER ESCAPE RULES ]]]"
    echo "   REFERENCE OF ALL CHARACTERS,  any text,               any quotes: SPACE \" ' \` ~ ! @ # $ % ^ & * ( ) [ ] { } < > | \\ / - _ + = : ; ? , ."
    echo "           UNUSABLE CHARACTERS, find text,            single quotes:         '"
    echo "             NORMAL CHARACTERS, find text,            single quotes:       \"   \` ~ !       %   &         ] { } < >       - _   = : ;   ,"
    echo "  BACKSLASH-ESCAPED CHARACTERS, find text,            single quotes: SPACE           @ # $   ^   * ( ) [           | \\ /     +       ?   ."
    echo "             NORMAL CHARACTERS, find text,            double quotes:         '   ~ ! @     %   &         ] { } < >       - _   = : ;   ,"
    echo "  BACKSLASH-ESCAPED CHARACTERS, find text,            double quotes: SPACE \"   \`       #     ^   * ( ) [           |   /     +       ?   ."
    echo "2-BACKSLASH-ESCAPED CHARACTERS, find text,            double quotes:                     $"
    echo "3-BACKSLASH-ESCAPED CHARACTERS, find text,            double quotes:                                                 \\"
    echo "           UNUSABLE CHARACTERS, replace text,         single quotes:         '"
    echo "             NORMAL CHARACTERS, replace text,         single quotes: SPACE \"   \` ~ !   #   % ^ & * ( ) [ ] { } < > |     - _ + = : ; ? , ."
    echo "  BACKSLASH-ESCAPED CHARACTERS, replace text,         single quotes:                 @   $                           \\ /"
    echo "             NORMAL CHARACTERS, replace text,         double quotes: SPACE   '   ~ ! @ #   % ^ & * ( ) [ ] { } < > |     - _ + = : ; ? , ."
    echo "  BACKSLASH-ESCAPED CHARACTERS, replace text,         double quotes:       \"   \`                                       /"
    echo "2-BACKSLASH-ESCAPED CHARACTERS, replace text,         double quotes:                     $"
    echo "3-BACKSLASH-ESCAPED CHARACTERS, replace text,         double quotes:                                                 \\"
    echo
fi

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

# wrongly edits binary files, will corrupt .git/index files, database files, etc
#    find $3 -type f -readable -writable -exec sed -i "s/$1/$2/g" {} \;

# does not support multi-line search or replace
#    sed -ri -e "s/$1/$2/g" $(grep -Elr --binary-files=without-match "$1" "$3")

# does not support multi-line replace
#    perl -pi -e "s/$1/$2/gxms" $(grep -Pzlr --binary-files=without-match "$1" "$3")

# does not support multiple replacements per file
#    perl -e "foreach \$arg (@ARGV) { next if not -f \$arg; print \"opening \$arg...\\n\"; (open my \$FH, \"<\", \$arg) or die \$!; my \$s = q{}; while (<\$FH>) { \$s .= \$_; } \$s =~ s/$1/$2/gxms; (close \$FH) or die \$!; (open \$FH, \">\", \$arg) or die \$!; print {\$FH} \$s; (close \$FH) or die \$!; }" $(grep -Pzlr --binary-files=without-match "$1" "$3" | sort)

# wrongly matches binary files
#    perl -e "foreach \$arg (@ARGV) { next if not -f \$arg; print \"    opening \$arg ... \"; (open my \$FH, \"<\", \$arg) or die \$!; my \$s = q{}; while (<\$FH>) { \$s .= \$_; } print \"replacing\"; while (\$s =~ s/$1/$2/gxms) { print \".\"; } print \"\\n\"; (close \$FH) or die \$!; (open \$FH, \">\", \$arg) or die \$!; print {\$FH} \$s; (close \$FH) or die \$!; }" $(grep -Pzlr --binary-files=without-match "$1" "$3" | sort)

# does support multi-line search & replace, multiple replacements per file
    perl -e "foreach \$arg (@ARGV) { next if not -f \$arg; print \"    opening \$arg ... \"; (open my \$FH, \"<\", \$arg) or die \$!; my \$s = q{}; while (<\$FH>) { \$s .= \$_; } print \"replacing\"; while (\$s =~ s/$1/$2/gxms) { print \".\"; } print \"\\n\"; (close \$FH) or die \$!; (open \$FH, \">\", \$arg) or die \$!; print {\$FH} \$s; (close \$FH) or die \$!; }" $(grep -Plr --binary-files=without-match "$1" "$3" | sort)
# original Perl one-liner code, without additional backslashes:
#perl -e 'foreach $arg (@ARGV) { next if not -f $arg; print "    opening $arg ... "; (open my $FH, "<", $arg) or die $!; my $s = q{}; while (<$FH>) { $s .= $_; } print "replacing"; while ($s =~ s/$1/$2/gxms) { print "."; } print "\n"; (close $FH) or die $!; (open $FH, ">", $arg) or die $!; print {$FH} $s; (close $FH) or die $!; }' ./*

    echo 'DONE!'
fi
