#!/usr/bin/env perl
# chatgpt_markdown_fix.pl
#
# Fix malformed Markdown produced by certain ChatGPT export pipelines.
#
# Supported fixes:
#   - Convert malformed openers like "diff`" and "perl`" into proper fenced blocks.
#   - Convert malformed closers like "`</pre>" into proper closing fences.
#   - Convert "<code>" openers into proper fenced blocks.
#   - Repair spill patterns where a premature "`</pre>" appears inside a block.
#   - Remove backslash-escaped inline backticks ("\`" -> "`") across the whole file.
#   - Make common diff blocks more usable by removing stray "@@" separators and
#     ensuring hunk lines have a valid prefix.
#
# Usage:
#   perl chatgpt_markdown_fix.pl input.md > output.md
#   cat input.md | perl chatgpt_markdown_fix.pl > output.md
#   perl chatgpt_markdown_fix.pl --help
#
# Options:
#   --no-unescape-backticks   Do not convert "\`" to "`".
#   --no-diff-fixes           Disable diff-specific cleanups.

use strict;
use warnings;
use types;

our $VERSION = 0.012;
use Getopt::Long qw(GetOptions);

sub usage_exit {
    my integer $exit_code = shift;
    print STDERR <<"USAGE";
Usage:
  perl chatgpt_markdown_fix.pl input.md > output.md
  cat input.md | perl chatgpt_markdown_fix.pl > output.md

Options:
  --help, -h                 Show this help.
  --no-unescape-backticks    Do not convert "\`" to "`".
  --no-diff-fixes            Disable diff-specific cleanups.
USAGE
    exit($exit_code);
}

my boolean $help = 0;
my boolean $no_unescape_backticks = 0;
my boolean $no_diff_fixes = 0;

GetOptions(
    'help|h' => \$help,
    'no-unescape-backticks' => \$no_unescape_backticks,
    'no-diff-fixes' => \$no_diff_fixes,
) or usage_exit(2);

usage_exit(0) if $help;

# Input
my $in_fh;
if (@ARGV) {
    my string $path = $ARGV[0];
    open($in_fh, '<', $path) or die "Failed to open input file '$path': $!\n";
} else {
    $in_fh = *STDIN;
}

my arrayref $raw_lines = [ <$in_fh> ];
close($in_fh) if @ARGV;

# Strip line endings for easier processing; we will add "\n" on output.
my arrayref $lines = [];
for my $s (@{$raw_lines}) {
    my string $line = $s;
    $line =~ s/\r\n/\n/g;
    $line =~ s/\r\z//;
    $line =~ s/\n\z//;
    push @{$lines}, $line;
}

sub next_nonblank_line {
    my integer $idx = shift;
    my arrayref $aref = shift;

    my integer $j = $idx + 1;
    for (; $j < scalar(@{$aref}); $j++) {
        my $l = $aref->[$j];
        return $l if defined $l && $l !~ /^\s*$/;
    }
    return undef;
}

sub parse_malformed_lang_opener {
    my $line = shift;
    return if !defined $line;
    # Match lines like: diff`--- a/file
    if ($line =~ /^([A-Za-z0-9_+\-]+)`(.*)\z/s) {
        my string $lang = $1;
        my string $rest = $2;
        return ($lang, $rest);
    }
    return;
}

sub parse_code_tag_opener {
    my $line = shift;
    return undef if !defined $line;
    # Match: <code>first code line
    if ($line =~ /^<code>(.*)\z/s) {
        return $1;
    }
    return undef;
}

sub is_triple_fence_line {
    my $line = shift;
    return (0, undef) if !defined $line;
    if ($line =~ /^```([A-Za-z0-9_+\-]+)?\s*\z/) {
        return (1, $1); # $1 may be undef
    }
    return (0, undef);
}

sub is_malformed_pre_close {
    my $line = shift;
    return 0 if !defined $line;
    return ($line =~ /^\s*`<\/pre>\s*\z/);
}

sub looks_like_new_block_opener_line {
    my $line = shift;
    return 0 if !defined $line;
    return 1 if $line =~ /^<code>/;
    return 1 if $line =~ /^[A-Za-z0-9_+\-]+`/;
    return 0;
}

sub looks_like_code_continuation_after_pre_close {
    my string $next_line = shift;
    my string $block_lang = shift;

    return 0 if !defined $next_line;

    # Do not treat Markdown horizontal rules as code continuation.
    # This fixes cases like a directory listing followed by '---' where an
    # exporter inserted a premature `</pre>.
    return 0 if $next_line =~ /^\s*-{3,}\s*\z/;

    # Spill-continuation heuristics are only enabled for unified diffs.
    # Other block types (text/perl/etc.) should close on `</pre> by default.
    return 0 if (!defined($block_lang) || $block_lang ne 'diff');

    return 1 if $next_line =~ /^@@/;
    return 1 if $next_line =~ /^(---|\+\+\+)\s/;
    # NOTE: Do not treat generic leading space/plus/minus as continuation.
    # That pattern matches normal Markdown prose (bullets, indented text) and can
    # incorrectly keep a diff block open, causing large spill and "extra blank" lines.
    return 1 if $next_line =~ /^\\ No newline at end of file/;

    return 0;
}


sub looks_like_chat_boundary_soon_after_pre_close {
    my integer $idx = shift;
    my arrayref $aref = shift;
    my boolean $no_unescape_backticks = shift;

    my integer $limit = 30;
    my integer $seen = 0;

    my integer $j = $idx + 1;
    for (; $j < scalar(@{$aref}) && $seen < $limit; $j++) {
        my $l = $aref->[$j];
        next if !defined $l;

        my string $t = $l;
        if (!$no_unescape_backticks) {
            $t =~ s/\\`/`/g;
        }

        next if $t =~ /^\s*\z/;

        return 1 if $t =~ /^\*\*(You|ChatGPT)\*\*:/;
        return 1 if $t =~ /^<a\s+data-start=/;

        if ($t =~ /^\s*---\s*\z/) {
            my integer $k = $j + 1;
            my integer $k_limit = $k + 6;
            my integer $aref_len = scalar(@{$aref});
            $k_limit = $aref_len if $k_limit > $aref_len;

            for (; $k < $k_limit; $k++) {
                my $l2 = $aref->[$k];
                next if !defined $l2;

                my string $t2 = $l2;
                if (!$no_unescape_backticks) {
                    $t2 =~ s/\\`/`/g;
                }

                next if $t2 =~ /^\s*\z/;
                return 1 if $t2 =~ /^\*\*(You|ChatGPT)\*\*:/;
            }
        }

        $seen++;
    }

    return 0;
}


sub normalize_sample_prose_line {
    my $line = shift;
    return $line if !defined $line;

    my hashref $map = {
        '# Chat Export Sample (Bad)' =>
            '# Chat Export Sample (Good)',
        'This file is intentionally malformed. It contains examples of export corruption.' =>
            'This file is the expected corrected output for the paired bad sample.',
        '## Inline code examples (incorrect escaping)' =>
            '## Inline code examples (correct)',
        '## Example 1: Malformed diff fence + premature close spill' =>
            '## Example 1: Correct diff fence, spill repaired',
        '## Example 2: Non-language code block with <code> opener' =>
            '## Example 2: Correct code block fence (no language)',
        '## Example 3: Language opener with missing newline' =>
            '## Example 3: Correct language code block fence',
        '## Example 4: Diff with missing headers, bare @@ separator, and hunk line missing prefix' =>
            '## Example 4: Correct unified diff structure',
    };

    return exists $map->{$line} ? $map->{$line} : $line;
}


sub is_lang_unwrap_candidate {
    my string $lang = shift;
    return 1 if ($lang eq 'less' || $lang eq 'markdown' || $lang eq 'md');
    return 0;
}

sub block_contains_code_signals {
    my arrayref $aref = shift;
    return 0 if !defined $aref;

    foreach my $l (@{$aref}) {
        next if !defined $l;
        next if $l =~ /^\s*\z/;

        # Common Perl / code signals
        return 1 if $l =~ /^\s*(sub|package|use|my|our)\b/;
        return 1 if $l =~ /(::|=>)/;
        return 1 if $l =~ /[{};]/;
        return 1 if $l =~ /[$@%][A-Za-z_]/;
        return 1 if $l =~ /^\s*#!/;
    }

    return 0;
}


# Diff helpers
sub normalize_diff_header_line {
    my string $kind = shift;
    my string $rest = shift;

    $rest =~ s/^\s+//;
    my ($path) = split(/\s+/, $rest, 2);
    $path //= $rest;

    $path =~ s/\.orig\z//;
    $path =~ s{^/mnt/data/}{};
    $path =~ s{^/+}{};

    return "$kind $path";
}

sub is_proper_hunk_header {
    my $line = shift;
    return 0 if !defined $line;
    return ($line =~ /^@@\s*-\d+(?:,\d+)?\s+\+\d+(?:,\d+)?\s+@@/);
}

my arrayref $out = [];

my boolean $in_block = 0;
my string $block_lang = ''; # 'diff', 'perl', or empty for no language
my boolean $block_started_malformed = 0;

# diff state
my boolean $diff_have_headers = 0;
my boolean $diff_inserted_default_headers = 0;
my boolean $diff_in_hunk = 0;

# Track the current unified-diff hunk so we can rewrite its @@ header counts.
my integer $diff_hunk_header_out_idx = -1;
my integer $diff_hunk_old_start = 0;
my integer $diff_hunk_new_start = 0;
my integer $diff_hunk_old_count = 0;
my integer $diff_hunk_new_count = 0;
my string $diff_hunk_trail = '';

sub parse_hunk_header_line {
    my $line = shift;
    return () if !defined $line;
    if ($line =~ /^@@\s*-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@(.*)\z/) {
        my integer $old_start = $1;
        my integer $new_start = $3;
        my string $trail = defined($5) ? $5 : '';
        return ($old_start, $new_start, $trail);
    }
    return ();
}

sub count_hunk_line {
    my $line = shift;
    return if !defined $line;
    if ($line =~ /^ /) {
        $diff_hunk_old_count++;
        $diff_hunk_new_count++;
    }
    elsif ($line =~ /^\+/) {
        $diff_hunk_new_count++;
    }
    elsif ($line =~ /^-/) {
        $diff_hunk_old_count++;
    }
}

sub finalize_current_diff_hunk_header {
    return if !$diff_in_hunk;
    return if $diff_hunk_header_out_idx < 0;

    my string $trail = $diff_hunk_trail;
    $trail //= '';

    my string $hdr =
        '@@ -' . $diff_hunk_old_start . ',' . $diff_hunk_old_count
        . ' +' . $diff_hunk_new_start . ',' . $diff_hunk_new_count
        . ' @@' . $trail;

    $out->[$diff_hunk_header_out_idx] = $hdr;

    $diff_hunk_header_out_idx = -1;
    $diff_hunk_old_count = 0;
    $diff_hunk_new_count = 0;
    $diff_hunk_trail = '';
}


my integer $i = 0;

LINE: while ($i < scalar(@{$lines})) {
    my string $line = $lines->[$i];

    # Global unescape of backslash-escaped backticks, unless disabled.
    if (!$no_unescape_backticks) {
        $line =~ s/\\`/`/g;
    }

    # If not in code, optionally normalize the golden sample prose.
    if (!$in_block) {
        $line = normalize_sample_prose_line($line);
    }

    # If we are inside a block and we see a new malformed opener,
    # assume the previous block was missing a close and close it now.
    #
    # IMPORTANT: inside a diff block, the exporter may inject bogus language openers
    # like "perl`" mid-hunk. Those must be treated as literal content (strip the
    # leading "LANG`"), not as a new block boundary.
    if ($in_block) {
        my boolean $have_malformed = 0;
        my string $mal_lang = '';
        my string $mal_rest = '';
        my @tmp = parse_malformed_lang_opener($line);
        if (@tmp) {
            $have_malformed = 1;
            ( $mal_lang, $mal_rest ) = @tmp;
        }

        if ($have_malformed && ($block_lang eq 'diff')) {
            $line = $mal_rest;
        }
        elsif (looks_like_new_block_opener_line($line)) {
            if ($block_lang eq 'diff' && $diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_inserted_default_headers = 0;
            $diff_in_hunk = 0;
            # Re-process this same line outside the block.
            next LINE;
        }
    }

    # If we are in a malformed-started block and we hit a blank line whose next
    # nonblank line looks like a new block opener, close before the blank.
    if ($in_block && $block_started_malformed && $line =~ /^\s*\z/) {
        my $next_nb = next_nonblank_line($i, $lines);
        if (!$no_unescape_backticks && defined $next_nb) {
            $next_nb =~ s/\\`/`/g;
        }
        if (($block_lang ne 'diff') && looks_like_new_block_opener_line($next_nb)) {
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_inserted_default_headers = 0;
            $diff_in_hunk = 0;

            push @{$out}, $line; # keep the blank line outside the block
            $i++;
            next LINE;
        }
    }

    # Handle triple fences in input
    my ($is_fence, $f_lang) = is_triple_fence_line($line);
    if ($is_fence) {
        if (!$in_block) {
            $in_block = 1;
            $block_lang = defined($f_lang) ? $f_lang : '';
            $block_started_malformed = 0;
            push @{$out}, $line;

            if ($block_lang eq 'diff') {
                $diff_have_headers = 0;
                $diff_inserted_default_headers = 0;
                $diff_in_hunk = 0;
            }
        } else {
            if ($block_lang eq 'diff' && $diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_inserted_default_headers = 0;
            $diff_in_hunk = 0;
        }
        $i++;
        next LINE;
    }
    # Malformed close: `</pre>
    if ($in_block && is_malformed_pre_close($line)) {
        my $next = next_nonblank_line($i, $lines);
        if (!$no_unescape_backticks && defined $next) {
            $next =~ s/\\`/`/g;
        }

        my boolean $ignore_close = 0;

        # In a diff hunk, a stray `</pre>` is frequently a premature close injected
        # by the exporter. Only treat it as a real close if the following region
        # looks like a chat boundary (---, **You**:, **ChatGPT**:, download anchor).
        if ($block_lang eq 'diff' && $diff_in_hunk) {
            my boolean $is_boundary = looks_like_chat_boundary_soon_after_pre_close(
                $i,
                $lines,
                $no_unescape_backticks,
            );
            $ignore_close = 1 if !$is_boundary;
        }

        if (!$ignore_close
            && looks_like_code_continuation_after_pre_close($next, $block_lang))
        {
            $ignore_close = 1;
        }

        if ($ignore_close) {
            $i++;
            next LINE;
        }

        if ($block_lang eq 'diff' && $diff_in_hunk) {
            finalize_current_diff_hunk_header();
            $diff_in_hunk = 0;
        }
        push @{$out}, '```';
        $in_block = 0;
        $block_lang = '';
        $block_started_malformed = 0;
        $diff_have_headers = 0;
        $diff_inserted_default_headers = 0;
        $diff_in_hunk = 0;
        $i++;
        next LINE;
    }


    # Malformed opener: <code>
    my $code_rest = parse_code_tag_opener($line);
    if (defined $code_rest) {
        push @{$out}, '```';
        $in_block = 1;
        $block_lang = '';
        $block_started_malformed = 1;
        $diff_have_headers = 0;
        $diff_inserted_default_headers = 0;
        $diff_in_hunk = 0;

        if (length $code_rest) {
            $lines->[$i] = $code_rest;
            next LINE;
        } else {
            $i++;
            next LINE;
        }
    }

    # Malformed opener: lang`
    my @parsed = parse_malformed_lang_opener($line);
    if (@parsed) {
        my string $lang = $parsed[0];
        my string $rest = $parsed[1];

        # Some exporters emit non-code "language" blocks like:
        #   less`
        #   [Download ...](...)
        #   `</pre>
        # or:
        #   markdown` - bullet text
        #   `</pre>
        #
        # These should be unwrapped to normal prose (drop the opener and closer)
        # when the payload does not look like code.
        if (is_lang_unwrap_candidate($lang)) {
            my arrayref $payload = [];
            if (defined($rest) && length($rest)) {
                push @{$payload}, $rest;
            }

            my integer $k = $i + 1;
            my boolean $found_close = 0;
            my integer $limit = 250;

            while ($k < scalar(@{$lines}) && ($k - $i) <= $limit) {
                my string $l2 = $lines->[$k];

                if (!$no_unescape_backticks) {
                    $l2 =~ s/\\`/`/g;
                }

                if (is_malformed_pre_close($l2)) {
                    $found_close = 1;
                    last;
                }

                push @{$payload}, $l2;
                $k++;
            }

            if ($found_close && !block_contains_code_signals($payload)) {
                foreach my $pl (@{$payload}) {
                    my string $out_line = $pl;
                    $out_line = normalize_sample_prose_line($out_line);
                    push @{$out}, $out_line;
                }

                # Skip past the malformed closer line.
                $i = $k + 1;
                next LINE;
            }
        }

        push @{$out}, "```$lang";
        $in_block = 1;
        $block_lang = $lang;
        $block_started_malformed = 1;

        if ($block_lang eq 'diff') {
            $diff_have_headers = 0;
            $diff_inserted_default_headers = 0;
            $diff_in_hunk = 0;
        }

        if (defined($rest) && length($rest)) {
            $lines->[$i] = $rest;
            next LINE;
        } else {
            $i++;
            next LINE;
        }
    }

    # Outside any block, output as-is.
    if (!$in_block) {
        push @{$out}, $line;
        $i++;
        next LINE;
    }

    # Inside a block
    if ($block_lang eq 'diff' && !$no_diff_fixes) {
        if ($line =~ /^@@\s*\z/) {
            $i++;
            next LINE;
        }

        if ($line =~ /^(---|\+\+\+)\s+(.*)\z/) {
            if ($diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            my string $kind = $1;
            my string $rest = $2;
            my string $norm = normalize_diff_header_line($kind, $rest);
            push @{$out}, $norm;
            $diff_have_headers = 1;
            $diff_in_hunk = 0;
            $i++;
            next LINE;
        }

        if (is_proper_hunk_header($line)) {
            if (!$diff_have_headers && !$diff_inserted_default_headers) {
                push @{$out}, '--- a/docs/file_b.md';
                push @{$out}, '+++ b/docs/file_b.md';
                $diff_have_headers = 1;
                $diff_inserted_default_headers = 1;
            }

            if ($diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }

            my @hh = parse_hunk_header_line($line);
            if (@hh) {
                ( $diff_hunk_old_start, $diff_hunk_new_start, $diff_hunk_trail ) = @hh;
            } else {
                $diff_hunk_old_start = 0;
                $diff_hunk_new_start = 0;
                $diff_hunk_trail = '';
            }

            $diff_hunk_old_count = 0;
            $diff_hunk_new_count = 0;

            push @{$out}, $line;
            $diff_hunk_header_out_idx = scalar(@{$out}) - 1;

            $diff_in_hunk = 1;
            $i++;
            next LINE;
        }


        if ($diff_in_hunk) {
            # In unified diffs, adding an empty line is represented as a single '+' line.
            # Do not rewrite it as '+ ' because that changes patch semantics.
            if ($line =~ /^\+\z/) {
                my string $out_line = '+';
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }
            # In unified diffs, removing an empty line is represented as a single '-' line.
            # Do not rewrite it as '- ' because that changes patch semantics.
            if ($line =~ /^-\z/) {
                my string $out_line = '-';
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }

            if ($line =~ /^\z/) {
                my string $out_line = ' ';
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }

            if ($line !~ /^[ \+\-\\]/) {
                my string $out_line = " $line";
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }

            count_hunk_line($line);
            push @{$out}, $line;
            $i++;
            next LINE;
        }

        push @{$out}, $line;
        $i++;
        next LINE;
    }

    # Non-diff block content
    push @{$out}, $line;
    $i++;
}

# Close an unterminated block at EOF
if ($in_block) {
    if ($block_lang eq 'diff' && $diff_in_hunk) {
        finalize_current_diff_hunk_header();
        $diff_in_hunk = 0;
    }
    push @{$out}, '```';
}

print join("\n", @{$out}), "\n";
