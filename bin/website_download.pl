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
our $VERSION = 0.100_000;

# [[[ CRITICS ]]]
## no critic qw(ProhibitUselessNoCritic ProhibitMagicNumbers RequireCheckedSyscalls) # USER DEFAULT 1: allow numeric values & print operator
## no critic qw(RequireInterpolationOfMetachars)  # USER DEFAULT 2: allow single-quoted control characters & sigils
## no critic qw(ProhibitConstantPragma ProhibitMagicNumbers)  # USER DEFAULT 3: allow constants

# [[[ INCLUDES ]]]
use HTTP::Tiny;
use File::Path qw( make_path );
use File::Spec::Functions;

# [[[ CONSTANTS ]]]
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
            print $FH $response->{content};
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
#            while ($response->{content} =~ m/<a\s+href\s*=\s*"([\w.\/]+?)">(.+?)<\/a>/gxms) {  # non-greedy
#            while ($response->{content} =~ m/<a\s+href\s*=\s*"([\w.\/]+?)">(.+?)<\/a>/gxmsi) {  # & case insensitive
#            while ($response->{content} =~ m/<a\s+href\s*=\s*(?:(?:'([\w.\/]+?)')|(?:"([\w.\/]+?)"))>.+?<\/a>/gxmsi) {  # & both quotes
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

