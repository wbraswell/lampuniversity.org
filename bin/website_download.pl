#!/usr/bin/env perl

# Website Downloader
# A simple application to download all the internal files linked from a specific website URL.

# START HERE: test suite, basic documentation, publish to CPAN
# START HERE: test suite, basic documentation, publish to CPAN
# START HERE: test suite, basic documentation, publish to CPAN

# [[[ HEADER ]]]
use RPerl;
use strict;
use warnings;
our $VERSION = 0.110_000;

# enable special characters in this code, specifically 
use utf8;

# enable accented characters in print output
binmode STDOUT, ':encoding(UTF-8)'; 
binmode STDERR, ':encoding(UTF-8)'; 

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls) # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(ProhibitConstantPragma ProhibitMagicNumbers)  # USER DEFAULT 3: allow constants

# [[[ INCLUDES ]]]
use File::Path qw( make_path );
use File::Spec::Functions;
use HTTP::Tiny;
use URI::Encode qw(uri_encode);

# [[[ CONSTANTS ]]]
my string $google_translate_url = 'https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=';
use constant SEPARATOR => (('<' x 20) . ('=' x 40) . ('>' x 20) . "\n");
use constant INDEX_DEFAULT => my string $TYPED_INDEX_DEFAULT = 'index.htm';
# any file suffix NOT in this list will be treated like a directory and receive the INDEX_DEFAULT file name above;
# NEED FIX: how to handle other uncommon file suffixes???
my @url_suffixes = qw( .htm .html .shtml .phtml .wml .pl .cgi .php .php3 .pcgi .asp .css .js
                       .jpg .jpeg .png .gif .webp .bmp .tiff .tif
                       .mpg .mpeg .mp4 .avi .mov .qt .ram 
                       .mp3 .wav .mid .midi 
                       .txt .rtf .pdf .doc .xls .ppt .odt .ods .odp
                       .zip .tar .gz .tar.gz .tgz .rar 
                       .exe 
                    );

# [[[ SUBROUTINES ]]]

sub url_check_split {
    { my string_arrayref $RETURN_TYPE };
    ( my string $url_input, my string $url_input_master_base ) = @ARG;

    my string $url_input_base = q{};
    my string $url_input_dir  = q{};
    my string $url_input_file = q{};

    if (not defined $url_input) { die 'ERROR: URL not defined, dying'; }

    # if no master base provided, assume this is the master
    if ($url_input_master_base eq q{}) {

        my @url_input_split = split /\//, $url_input;
        my integer $url_input_split_count = scalar @url_input_split;
        if ($url_input_split_count < 3) {
            die 'ERROR: URL incomplete, dying';
        }
        if ($url_input_split[0] !~ m/^http[s]?:$/) {
            die 'ERROR: URL does not start with http(s), dying';
        }
        if ($url_input_split[1] ne '') {
            die 'ERROR: URL does not start with http://, dying';
        }
        if ($url_input_split_count > 3) {
            $url_input_file = url_check_suffix(\@url_input_split);
        }

        $url_input_base = join '/', @url_input_split;
    }
    # master base is provided, quicker checks
    else {
        if ((substr $url_input, 0, (length $url_input_master_base)) ne $url_input_master_base) {
            die 'ERROR: URL does not start with master URL base' . q{'} . $url_input_master_base . q{'} . ', dying';
        }

        $url_input_base = $url_input_master_base;  # automatically set base as master base
        substr $url_input, 0, (length $url_input_master_base), q{};  # strip leading master base
        # strip leading forward slash '/', if present
        if ((substr $url_input, 0, 1) eq '/') {
            substr $url_input, 0, 1, q{};
        }

        # split w/out master base present
        my @url_input_split = split /\//, $url_input;

        $url_input_file = url_check_suffix(\@url_input_split);
        $url_input_dir = join '/', @url_input_split;
    }

#    print {*STDERR} 'have $url_input_base = ', $url_input_base, "\n";
#    print {*STDERR} 'have $url_input_dir  = ', $url_input_dir, "\n";
#    print {*STDERR} 'have $url_input_file = ', $url_input_file, "\n";

    return [$url_input_base, $url_input_dir, $url_input_file];
}


sub url_check_suffix {
    { my string $RETURN_TYPE };
    ( my string_arrayref $url_input_split ) = @ARG;

    my string $url_input_split_last = $url_input_split->[-1];
    my string $url_input_file = q{};

    # assume last segment of URL contains at least one dot '.' if it is a file name
    if ($url_input_split_last =~ m/\./) {
        # check all valid URL suffixes
        foreach my string $url_suffix (@url_suffixes) {
            # if URL matches a valid suffix, then the URL contains a file name and it should be popped
            if ($url_input_split_last =~ m/$url_suffix$/) {
                $url_input_file = pop @{$url_input_split};  # DEV NOTE: modifies original array!
            }
        }
    }

    # either no dot '.' in last part of URL, or not a recognized URL suffix, assume it is a directory not a file name
    if ($url_input_file eq q{}) {
        # assume default file name instead of calling $ht->get() repeatedly to find real file name
        $url_input_file = INDEX_DEFAULT();
    }

    return $url_input_file;
}


sub website_download {
    { my void $RETURN_TYPE };
    ( my string_hashref $urls, my string $url_master_base ) = @ARG;

    my $ht = HTTP::Tiny->new;
    my integer $urls_found_count = scalar keys %{$urls};  # initialize to number of user-defined URLs

    # continue looping until all user-defined URLs and found URLs have been processed
    while ($urls_found_count) {
        print "\n\n", (SEPARATOR() x 3), "\n\n";

        # reset before each outer iteration, counts new URLs found during this outer iteration,
        # if greater than zero will require another outer iteration;
        # use this instead of recursion in order to pool all URLs together and avoid duplicate URL processing
        $urls_found_count = 0;

        foreach my string $url (sort keys %{$urls}) {
            print "\n", (SEPARATOR() x 1), "\n";

            # skip URL if already downloaded
            if ($urls->{$url}->[0]) {
                print 'Skipping URL, Already Downloaded: ', $url, "\n";
                next;
            }

            print 'Download URL: ', $url, "\n";
            my $response = $ht->get($url);

            if (not $response->{success}) {
                print 'Download URL Failed:';
                if ((exists $response->{status}) and (defined $response->{status})) { print ' ', $response->{status}; }
                if ((exists $response->{reasons}) and (defined $response->{reasons})) { print ' ', $response->{reasons}; }
                print "\n";
                next;
            }

            # mark URL as downloaded
            $urls->{$url}->[0] = 1;

            print 'Downloaded URL Length: ', length $response->{content}, "\n";

            print {*STDERR} '[[[ BEFORE TRANSLATION LOOP ]]]', "\n";
            my string $html_output = q{};
            my integer $i = 0;
            my string $html_generator = q{};
            my string $language_master = q{};
            my string $language_current = q{};
            my boolean $in_paragraph = 0;
            my boolean $in_heading = 0;
            my string $plain_text_paragraph_heading = q{};
            my string $plain_text_translated = q{};
            my string $html_output_paragraph_heading_open = q{};
            my string $html_output_paragraph_heading_content = q{};
            my string $html_output_paragraph_heading_close = q{};
            my string_hashref $html_output_span_style_font_open  = { span => q{}, style => q{}, font => q{} };
            my string_hashref $html_output_span_style_font_close = { span => q{}, style => q{}, font => q{} };
            my string_hashref $html_output_bold_italic_open  = { b => q{}, i => q{} };
            my string_hashref $html_output_bold_italic_close = { b => q{}, i => q{} };

            # </font></h1>
#            while ($response->{content} =~ m/(<.*?>)([^<]+)/gxmsi) {  # wrong, captures multiple HTML tags in a row
            while ($response->{content} =~ m/(<.*?>)([^<]+)?/gxmsi) {  # do not require HTML tag to be followed by non-tag
                print {*STDERR} 'have $i = ', $i, "\n";
#                print {*STDERR} 'have $1 = ', $1, "\n";
#                print {*STDERR} 'have $2 = ', $2, "\n\n";
                my string $html_tag = $1;
                my string $plain_text = q{};
                if (defined $2) {
                    $plain_text = $2;
                }
                print {*STDERR} 'have $html_tag = ', $html_tag, "\n";
                print {*STDERR} 'have $plain_text before = ', $plain_text, "\n";

                # replace 'RIGHT SINGLE QUOTATION MARK' w/ apostrophe '’', different translation from French
                $plain_text =~ s//’/g;
                $plain_text =~ s/&nbsp;/ /g;  # replace '&nbsp;' w/ blank space
                $plain_text =~ s/\R/ /g;  # replace newline w/ blank space, different translation from French
                $plain_text =~ s/^\s+|\s+$//g;  # strip leading and trailing whitespace

                print {*STDERR} 'have $plain_text after = ', $plain_text, "\n";

                # detect HTML generator
                # EXAMPLE: <meta name="GENERATOR" content="Microsoft FrontPage 4.0">
                if ($html_tag =~ m/^<\s*meta\s+name\s*=\s*"GENERATOR"\s+content\s*=\s*"(.+?)"\s*>$/) {
                    $html_generator = $1;
                    print {*STDERR} 'have $html_generator = ', $html_generator, "\n";
                }

                # detect language
                # EXAMPLE: <meta http-equiv="Content-Language" content="fr">
                elsif ($html_tag =~ m/^<\s*meta\s+http-equiv\s*=\s*"Content-Language"\s+content\s*=\s*"(\w+)"\s*>$/) {
                    $language_master = $1;
                    print {*STDERR} 'have $language_master = ', $language_master, "\n";
                }
                elsif ($html_tag =~ m/^<\s*span\s+lang\s*=\s*"(\w+)"/) {
                    $language_current = $1;
                    print {*STDERR} 'have $language_current = ', $language_current, "\n";
                }

                # fix M$ FrontPage formatting errors:
                # within each <p> paragraph and <h?> heading, combine multiple span/style/font tags into single formatting
                # and extend to entire paragraph or heading;
                # italic and bold tags can be trusted and used to separate translation strings;
                # translate entire paragraph or heading at once

                if ($html_generator =~ m/FrontPage/) {

                    # ASSUMPTION: paragraphs should not be nested within headings, and vice versa;
                    # therefore, append $html_output_span_style_font_close and trigger closing on either close paragraph or close heading;

                    # paragraphs can not be nested within other paragraphs
                    # "The P element represents a paragraph. It cannot contain block-level elements (including P itself)."
                    # http://www.w3.org/TR/html401/struct/text.html#h-9.3.1
                    if ($html_tag =~ m/^<\s*p/) {
                        $in_paragraph = 1;
                        $html_output_paragraph_heading_open .= $html_tag;
                        $plain_text_paragraph_heading .= $plain_text;
                        $plain_text = q{};
                    }
                    elsif ($html_tag =~ m/^<\s*\/p/) {
                        $in_paragraph = 0;
                        $html_output_paragraph_heading_close .= $html_tag;
                        $plain_text = $plain_text_paragraph_heading;
                        $plain_text_paragraph_heading = q{};
                    }
                    # ASSUMPTION: headings should not be nested within other headings
                    elsif ($html_tag =~ m/^<\s*h\d/) {
                        $in_heading = 1;
                        $html_output_paragraph_heading_open .= $html_tag;
                        $plain_text_paragraph_heading .= $plain_text;
                        $plain_text = q{};
                    }
                    elsif ($html_tag =~ m/^<\s*\/h\d/) {
                        $in_heading = 0;
                        $html_output_paragraph_heading_close .= $html_tag;
                        $plain_text = $plain_text_paragraph_heading;
                        $plain_text_paragraph_heading = q{};
                    }
                    elsif ($in_paragraph or $in_heading) {
                        # detect spans, styles, fonts; they can't be trusted and must be combined
                        if (($html_tag =~ m/^<\s*(span)/) or
                            ($html_tag =~ m/^<\s*(style)/) or
                            ($html_tag =~ m/^<\s*(font)/)) {
                            # only save first span tag, discard any following
                            if ($html_output_span_style_font_open->{$1} eq q{}) {
                                print {*STDERR} 'Tag is first <', $1, '>, saving', "\n";
                                $html_output_span_style_font_open->{$1} = $html_tag;
                            }
                            else {
                                print {*STDERR} 'Tag is NOT first <', $1, '>, skipping', "\n";
                            }
                        }
                        elsif (($html_tag =~ m/^<\s*\/(span)/) or
                               ($html_tag =~ m/^<\s*\/(style)/) or
                               ($html_tag =~ m/^<\s*\/(font)/)) {
                            if ($html_output_span_style_font_close->{$1} eq q{}) {
                                print {*STDERR} 'Tag is first </', $1, '>, saving', "\n";
                                $html_output_span_style_font_close->{$1} = $html_tag;
                            }
                            else {
                                print {*STDERR} 'Tag is NOT first </', $1, '>, skipping', "\n";
                            }
                        }

                        # detect bolds and italics; they can be trusted and used to separate translation strings
                        elsif (($html_tag =~ m/^<\s*(b)\s*>/) or
                               ($html_tag =~ m/^<\s*(i)\s*>/)) {
                            if ($html_output_bold_italic_open->{$1} eq q{}) {
                                print {*STDERR} 'Tag is first <', $1, '>, saving', "\n";
                                $html_output_bold_italic_open->{$1} = $html_tag;
                            }
                            else {
                                print {*STDERR} 'Tag is NOT first <', $1, '>, skipping', "\n";
                            }
                        }
                        elsif (($html_tag =~ m/^<\s*\/(b)\s*>/) or
                               ($html_tag =~ m/^<\s*\/(i)\s*>/)) {


# FIRST START HERE: fix problem of close </i> not triggering translation
# FIRST START HERE: fix problem of close </i> not triggering translation
# FIRST START HERE: fix problem of close </i> not triggering translation


                            if ($html_output_bold_italic_close->{$1} eq q{}) {
                                print {*STDERR} 'Tag is first </', $1, '>, saving', "\n";
                                $html_output_bold_italic_close->{$1} = $html_tag;
                            }
                            else {
                                print {*STDERR} 'Tag is NOT first </', $1, '>, skipping', "\n";
                            }

                            $plain_text = $plain_text_paragraph_heading;
                            $plain_text_paragraph_heading = q{};
                        }
                        else {
                            print {*STDERR} 'Tag is NOT span or style or font or b or i, saving', "\n";
                            $html_output_paragraph_heading_content .= $html_tag;
                        }

                        # concatenate all plain text inside paragraph or heading, regardless of spans or no spans
                        $plain_text_paragraph_heading .= $plain_text;
                        $plain_text = q{};

                    }       # END ($in_paragraph or $in_heading)
                    else {  # NOT ($in_paragraph or $in_heading)
                        $html_output .= $html_tag . "\n";
                    }
                }       # END M$ FrontPage
                else {  # NOT M$ FrontPage
                    $html_output .= $html_tag . "\n";
                }

                print {*STDERR} 'after FrontPage correction, have $plain_text =                   ', $plain_text, "\n";
                print {*STDERR} 'after FrontPage correction, have $plain_text_paragraph_heading = ', $plain_text_paragraph_heading, "\n";

                # translate text if not empty or blank whitespace
                if ($plain_text !~ m/^\s*$/) {

                    my string $google_translate_url_full = $google_translate_url . uri_encode($plain_text);

                    print 'Translate URL: ', $google_translate_url_full, "\n";

                    my $response_translate = $ht->get($google_translate_url_full);

                    if (not $response_translate->{success}) {
                        print 'Translate URL Failed:';
                        if ((exists $response_translate->{status}) and (defined $response_translate->{status}))
                            { print ' ', $response_translate->{status}; }
                        if ((exists $response_translate->{reasons}) and (defined $response_translate->{reasons})) 
                            { print ' ', $response_translate->{reasons}; }
                        print "\n";
                        die 'ERROR: Unable to translate, dying';
                    }

                    print 'have $response_translate->{content} = ', "\n", $response_translate->{content}, "\n";

=pod EXAMPLE
[[["hello french","bonjour francais",null,null,3,null,null,null,[[["XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",""]
]
]
]
]
,null,"fr",null,null,null,null,null,[["fr"]
,null,[X.XXXXXXX]
,["fr"]
]
]
=cut

# START HERE: parse multi-part translation JSON
# START HERE: parse multi-part translation JSON
# START HERE: parse multi-part translation JSON

=pod MULTI_EXAMPLE
[[["TV. ","TV.",null,null,2]
,[": Brother, are you a",":FrÃ¨re, Ãªtes-vous",null,null,3,null,null,null,[[["XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",""]
]
]
]
]
,null,"fr",null,null,null,null,null,[["fr"]
,null,[X.X]
,["fr"]
]
]
=cut

                    if ($response_translate->{content} =~ m/^\[\[\["(.*?)","/) {
                        if (defined $1) {
                            $plain_text_translated = $1;
                        }
                        else {
                            die 'ERROR: Undefined translation from JSON output, dying';
                        }
                    }
                    else {
                        die 'ERROR: Could not parse translated JSON output, dying';
                    }

                    print {*STDERR} 'have $plain_text_translated = ', "\n", $plain_text_translated, "\n";
                }



                # if close of bold or italic, assemble output
                if ($html_output_bold_italic_close->{b} ne q{}) {
                    $html_output_paragraph_heading_content .= 
                        $html_output_bold_italic_open->{b} .
                        $plain_text_translated .
                        $html_output_bold_italic_close->{b};

                        $html_output_bold_italic_open->{b} = q{};
                        $plain_text_translated = q{};
                        $html_output_bold_italic_close->{b} = q{};
                }
                # NEED REMOVE DUPLICATE CODE
                elsif ($html_output_bold_italic_close->{i} ne q{}) {
                    $html_output_paragraph_heading_content .=
                        $html_output_bold_italic_open->{i} .
                        $plain_text_translated .
                        $html_output_bold_italic_close->{i};

                        $html_output_bold_italic_open->{i} = q{};
                        $plain_text_translated = q{};
                        $html_output_bold_italic_close->{i} = q{};
                }

                # if close of paragraph or heading, assemble output
                elsif ($html_output_paragraph_heading_close ne q{}) {
                    $html_output .= 
                        $html_output_paragraph_heading_open . 
                        $html_output_span_style_font_open->{span} .
                        $html_output_span_style_font_open->{style} .
                        $html_output_span_style_font_open->{font} .
                        $html_output_paragraph_heading_content .
                        $plain_text_translated . 
                        $html_output_span_style_font_close->{font} .
                        $html_output_span_style_font_close->{style} .
                        $html_output_span_style_font_close->{span} .
                        $html_output_paragraph_heading_close . "\n";

                        $html_output_paragraph_heading_open = q{};
                        $html_output_paragraph_heading_content = q{};
                        $html_output_paragraph_heading_close = q{};
                        $html_output_span_style_font_open  = { span => q{}, style => q{}, font => q{} };
                        $html_output_span_style_font_close = { span => q{}, style => q{}, font => q{} };
                        $html_output_bold_italic_open  = { b => q{}, i => q{} };
                        $html_output_bold_italic_close = { b => q{}, i => q{} };
                }
                else {
                    if ($plain_text_translated ne q{}) {
                        print {*STDERR} 'have non-empty $plain_text_translated, appending', "\n";
                        $html_output .= $plain_text_translated . "\n";
                    }
                    else {
                        print {*STDERR} 'have empty $plain_text_translated, skipping', "\n";
                    }
                }

                $plain_text_translated = q{};

                print {*STDERR} 'have $html_output_paragraph_heading_open =    ', $html_output_paragraph_heading_open, "\n";
                print {*STDERR} 'have $html_output_span_style_font_open =                 ', Dumper($html_output_span_style_font_open), "\n";
                print {*STDERR} 'have $html_output_bold_italic_open =                 ', Dumper($html_output_bold_italic_open), "\n";
                print {*STDERR} 'have $html_output_paragraph_heading_content = ', $html_output_paragraph_heading_content, "\n";
                print {*STDERR} 'have $html_output_span_style_font_close =                ', Dumper($html_output_span_style_font_close), "\n";
                print {*STDERR} 'have $html_output_bold_italic_close =                 ', Dumper($html_output_bold_italic_close), "\n";
                print {*STDERR} 'have $html_output_paragraph_heading_close =   ', $html_output_paragraph_heading_close, "\n";
                print {*STDERR} 'have PARTIAL $html_output = ', "\n", $html_output, "\n";

                print {*STDERR} 'Please press <ENTER> to continue...', "\n";
                my string $press_enter = <STDIN>;

                $i++;
            }  # END while loop

            print {*STDERR} 'have FINAL $html_output = ', "\n", $html_output, "\n";

            die 'TMP DEBUG';






            my string_arrayref $url_split = url_check_split($url, $url_master_base);
            my string $url_base = $url_split->[0];
            my string $url_dir  = $url_split->[1];
            my string $url_file = $url_split->[2];
            print 'URL Base:  ', $url_base, "\n";
            print 'URL Dir:   ', $url_dir, "\n";
            print 'URL File:  ', $url_file, "\n";

            my string $save_file_path;
            if ($url_dir ne q{}) {
                print 'Testing if URL dir exists...', "\n";
                if (not (-d $url_dir)) {
                    print 'Creating URL dir...', "\n";
                    make_path($url_dir)
                        or die 'ERROR: Failed to create URL directory: ' . $url_dir . ', dying';
                    print 'Created URL dir!', "\n";
                }
                print 'Creating save file path...', "\n";
                $save_file_path = catfile( $url_dir, $url_file );
                print 'Created save file path!', "\n";
            }
            else {
                $save_file_path = $url_file;
            }

            print 'Save File: ', $save_file_path, "\n";
            open(my $FH, '>', $save_file_path) 
                or die 'ERROR: Could not open file ' . $save_file_path . ' for writing, ' . $! . ', dying';
#            print $FH $response->{content};  # untranslated
            print $FH $html_output;           #   translated
            close $FH
                or die 'ERROR: Could not close file ' . $save_file_path . ' after writing, ' . $! . ', dying';

            # only search for URLs inside HTML files, not PDF files etc.
            if ((not (substr $save_file_path, -4, 4, '.htm')) and
                (not (substr $save_file_path, -5, 5, '.html'))) {
                print 'Skipping File, Non-HTML Data: ', $save_file_path, "\n";
                next;
            }

            my string_hashref $urls_found = {};

#           while ($response->{content} =~ m/<a\s+href\s*=\s*"([\w.]+)">(.+)<\/a>/gxms) {  # greedy, WRONG
#           while ($response->{content} =~ m/<a\s+href\s*=\s*"([\w.\/]+?)">(.+?)<\/a>/gxms) {  # non-greedy
#           while ($response->{content} =~ m/<a\s+href\s*=\s*"([\w.\/]+?)">(.+?)<\/a>/gxmsi) {  # & case insensitive
#           while ($response->{content} =~ m/<a\s+href\s*=\s*(?:(?:'([\w.\/]+?)')|(?:"([\w.\/]+?)"))>.+?<\/a>/gxmsi) {  # & both quotes
            while ($response->{content} =~ m/<a\s+href\s*=\s*(?:(?:'([\w.\/]+?)')|(?:"([\w.\/]+?)")).*?>.+?<\/a>/gxmsi) {  # & classes
#               print {*STDERR} 'have $1 = ', $1, "\n";
#               print {*STDERR} 'have $2 = ', $2, "\n\n";
                my string $url_found;
                if (defined $1) {
                    $url_found = $1;
                }
                elsif (defined $2) {
                    $url_found = $2;
                }
                else {
                    die 'ERROR: Regex match but no match variable data, dying';
                }

                my string $url_found_absolute;

                my string $http = 'http://';
                my string $https = 'https://';
                if (($url_found =~ m/^$http/) or
                    ($url_found =~ m/^$https/)) {

                    if ($url_found !~ m/^$url_master_base/) {
                        print 'Skipping URL, External Website: ', $url_found, "\n";
                        next;
                    }

                    $url_found_absolute = $url_found;
                }
                else {
                    my @dotdot_found = $url_found =~ /\.\.\//g;
                    my integer $dotdot_count = scalar @dotdot_found;

                    # allow exactly one '../'
                    if ($dotdot_count > 1) {
                        print 'Skipping URL, Internal Relative Link, Multiple dot-dot-forward-slash ../ : ', $url_found, "\n";
                        next;
                    }
                    elsif ($dotdot_count == 1) {
                        if ($url_dir ne q{}) {
                            print 'Found URL, Internal Relative Link, dot-dot-forward-slash ../ Inside URL Base: ', $url_found, "\n";
                            substr $url_found, 0, 3, q{};  # strip leading '../'

                            $url_found_absolute = $url_base;

                            # if multiple dirs, discard top in lieu of '../' and include remaining; else do not include dir at all
                            if ($url_dir =~ m/\//) {
                                my @url_dir_split = split /\//, $url_dir;
                                pop @url_dir_split;
                                $url_found_absolute .= '/' . (join '/', @url_dir_split);
                            }

                            $url_found_absolute .= '/' . $url_found;
                        }
                        else {
                            print 'Skipping URL, Internal Relative Link, dot-dot-forward-slash ../ Outside URL Base: ', $url_found, "\n";
                            next;
                        }
                    }
                    elsif ((substr $url_found, 0, 2) eq './') {
                        print 'Found URL, Internal Relative Link, dot-forward-slash ./ : ', $url_found, "\n";
                        substr $url_found, 0, 2, q{};  # strip leading './'

                        # duplicate code, see below
                        $url_found_absolute = $url_base;
                        if ($url_dir ne q{}) { $url_found_absolute .= '/' . $url_dir; }
                        $url_found_absolute .= '/' . $url_found;
                    }
                    elsif ((substr $url_found, 0, 1) eq '/') {
                        # NEED FIX: this will not work correctly if master URL includes subdirectory?
                        print 'Found URL, Internal Relative Link, forward-slash / : ', $url_found, "\n";
                        $url_found_absolute = $url_base . $url_found;
                    }
                    else {
                        print 'Found URL, Internal Relative Link: ', $url_found, "\n";

                        # duplicate code, see above
                        $url_found_absolute = $url_base;
                        if ($url_dir ne q{}) { $url_found_absolute .= '/' . $url_dir; }
                        $url_found_absolute .= '/' . $url_found;
                    }
                }

                if (exists $urls_found->{$url_found_absolute}) {
                    print 'Skipping URL, Already Found: ', $url_found_absolute, "\n";
                }

                print 'Have Found URL, Absolute Version: ', $url_found_absolute, "\n";
                $urls_found->{$url_found_absolute} = 0;
            }

#           print {*STDERR} 'have scalar keys %{$urls_found} = ', scalar keys %{$urls_found}, "\n";
#           print {*STDERR} 'have $urls_found = ', Dumper($urls_found);

            # merge found URLs back into main URLs
            foreach my string $url_found (sort keys %{$urls_found}) {
                if (not exists $urls->{$url_found}) {
                    print 'Found New URL: ', $url_found, "\n";
                    $urls->{$url_found} = [0];  # initialize to arrayref with 0th element set to boolean false '0', not yet downloaded
                    $urls_found_count++;  # increment only if new not-yet-processed URLs are found
                }
                push @{$urls->{$url_found}}, $url;  # record all URLs which link to this found URL, even if not a new URL
            }

            print 'Found New URLs Count: ', $urls_found_count, "\n";
            print "\n";
        }

        print "\n" x 2;
    }
}


# [[[ OPERATIONS ]]]

# receive exactly one command-line argument, check if valid, create base var for use when saving directories, and initialize URL list
my string $url_master = $ARGV[0];
if (not defined $url_master) { die 'ERROR: No command-line argument provided, must specify website URL, dying'; }
my string_arrayref $url_master_split = url_check_split($url_master, q{});
my string $url_master_base = $url_master_split->[0];
my string_hashref $urls_master = { $url_master => [0] };
print 'URL Master Base: ', $url_master_base, "\n";

website_download($urls_master, $url_master_base);

print 'Final URLs: ', "\n", Dumper($urls_master);

my $urls_master_broken = {};
foreach my string $url (sort keys %{$urls_master}) {
    if (not $urls_master->{$url}->[0]) {
        $urls_master_broken->{$url} = $urls_master->{$url};
        shift @{$urls_master_broken->{$url}};  # discard 0th element, boolean true/false value, only keep linking URLs
    }
}

print "\n\n", (SEPARATOR() x 3), "\n\n";
foreach my string $url_broken (sort keys %{$urls_master_broken}) {
    print "\n", (SEPARATOR() x 1), "\n";
    print 'This Broken URL:', "\n", '    ', $url_broken, "\n";
    print 'Is Linked From:', "\n";
    foreach my string $url_broken_link (sort @{$urls_master_broken->{$url_broken}}) {
        print '    ', $url_broken_link, "\n";
    }
}
print 'Bad URLs: ', "\n", Dumper($urls_master_broken);

