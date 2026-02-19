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
#   perl chatgpt_markdown_fix.pl input.md
#   perl chatgpt_markdown_fix.pl input1.md input2.md ...
#   perl chatgpt_markdown_fix.pl --overwrite input.md
#   perl chatgpt_markdown_fix.pl --dry-run input.md
#   perl chatgpt_markdown_fix.pl --clean input.md
#   perl chatgpt_markdown_fix.pl --markdownlint input.md
#   perl chatgpt_markdown_fix.pl --help
#
# Options:
#   --overwrite              Allow clobbering existing foo__fixed.<suffix> files.
#   --debug                  Enable debug logging and write foo__fixed.debug files.
#   --dry-run                Do not write any files; still run fixes and tier checks.
#   --clean                  Delete foo__fixed.<suffix> and foo__fixed.debug outputs for each input; leaves inputs intact.
#   --double-fix             Allow processing inputs already tagged __fixed.<suffix> (disabled by default).
#   --no-unescape-backticks   Do not convert "\`" to "`".
#   --no-diff-fixes           Disable diff-specific cleanups.
#   --markdownlint           Apply post-fixes for markdownlint (currently MD041 + MD048 + MD003 + MD019 + MD040 + MD009 + MD022 + MD001 + MD036 + MD025 + MD026 + MD032 + MD007 + MD004 + MD029 + MD030 + MD033 + MD034 + MD037 + MD049 + MD038 + MD035 + MD031 + MD012).

use strict;
use warnings;
use types;

our $VERSION = 0.135;
use Getopt::Long qw(GetOptions);


# Debugging (optional; to STDERR and optionally to per-file .debug files)
# Default is disabled. Enable with --debug or with environment variable CHATGPT_MARKDOWN_FIX_DEBUG=1
my boolean $debug = 0;
if (defined $ENV{'CHATGPT_MARKDOWN_FIX_DEBUG'}) {
    if ($ENV{'CHATGPT_MARKDOWN_FIX_DEBUG'} eq '1') {
        $debug = 1;
    }
    if ($ENV{'CHATGPT_MARKDOWN_FIX_DEBUG'} eq '0') {
        $debug = 0;
    }
}
my integer $dbg_event_count = 0;
my arrayref $dbg_lines = [];
sub dbg {
    return if !$debug;
    my $msg = shift;
    $msg = '' if !defined $msg;
    $dbg_event_count++;
    my $ts = scalar(localtime());
    my string $line = "[chatgpt_markdown_fix v$VERSION][$ts][$dbg_event_count] $msg";
    push @{$dbg_lines}, $line;
    print STDERR $line . "\n";
}

# Debug counters
my integer $cnt_unescaped_backticks = 0;
my integer $cnt_blocks_opened = 0;
my integer $cnt_blocks_closed = 0;
my integer $cnt_blocks_opened_diff = 0;
my integer $cnt_blocks_relabel_diff_to_console = 0;
my integer $cnt_blocks_relabel_diff_to_bash = 0;
my integer $cnt_blocks_relabel_diff_to_sh = 0;
my integer $cnt_blocks_relabel_diff_uncertain = 0;
my integer $cnt_spill_close_on_new_opener = 0;
my integer $cnt_close_on_blank_after_malformed = 0;
my integer $cnt_malformed_pre_close_seen = 0;
my integer $cnt_malformed_pre_close_ignored = 0;
my integer $cnt_malformed_code_tag_openers = 0;
my integer $cnt_malformed_lang_openers = 0;
my integer $cnt_unwrapped_less_markdown_blocks = 0;
my integer $cnt_unwrapped_html_anchors = 0;
my integer $cnt_diff_git_header_lines = 0;
my integer $cnt_diff_header_lines = 0;
my integer $cnt_diff_hunk_headers = 0;
my integer $cnt_diff_hunk_header_rewrites = 0;
my integer $cnt_diff_hunk_lines_empty_to_space = 0;
my integer $cnt_diff_hunk_lines_prefixed_space = 0;
my integer $cnt_diff_hunk_lines_passthrough = 0;
my integer $cnt_diff_missing_headers_before_hunk = 0;
my integer $cnt_diff_contam_blocks = 0;
my integer $cnt_diff_contam_lines_outside_hunk = 0;
my integer $cnt_diff_contam_hunk_empty_lines = 0;
my integer $cnt_diff_contam_hunk_nonprefix_lines = 0;
my integer $cnt_diff_contam_missing_headers_before_hunk = 0;
my integer $cnt_diff_contam_dropped_bare_atat = 0;
my integer $cnt_diff_tierD_allowed_rewrites = 0;
my integer $cnt_diff_tierD_forbidden_rewrites = 0;
my integer $cnt_diff_tierD_dropped_bare_atat = 0;

my integer $cnt_fixed_single_backtick_lang_fence_openers = 0;
my integer $cnt_fixed_single_backtick_missing_fence_openers = 0;
my integer $cnt_markdownlint_md009_fixed_lines = 0;
my integer $cnt_markdownlint_md041_inserted = 0;
my integer $cnt_markdownlint_md048_converted_tilde_fences = 0;
my integer $cnt_markdownlint_md003_converted_setext = 0;
my integer $cnt_markdownlint_md019_fixed_atx = 0;
my integer $cnt_markdownlint_md040_defaulted_fence_lang = 0;
my integer $cnt_markdownlint_md040_removed_stray_fences = 0;
my integer $cnt_markdownlint_md001_adjusted_headings = 0;
my integer $cnt_markdownlint_md036_converted = 0;
my integer $cnt_markdownlint_md036_quoted = 0;
my integer $cnt_markdownlint_md036_stripped_orphan = 0;
my integer $cnt_markdownlint_md025_demoted_h1 = 0;
my integer $cnt_markdownlint_md026_stripped_heading_punct = 0;
my integer $cnt_markdownlint_md022_inserted_blank_lines = 0;
my integer $cnt_markdownlint_md032_inserted_blank_lines = 0;
my integer $cnt_markdownlint_md007_adjusted_items = 0;
my integer $cnt_markdownlint_md007_collapsed_double_marker = 0;
my integer $cnt_markdownlint_md004_normalized_markers = 0;
my integer $cnt_markdownlint_md029_nested_ul_blocks = 0;
my integer $cnt_markdownlint_md029_renumbered_ol_items = 0;
my integer $cnt_markdownlint_md029_warn_possible_misindented_ordered_sublists = 0;
my integer $cnt_markdownlint_md029_escaped_bullet_number_labels = 0;
my integer $cnt_markdownlint_md030_fixed_spaces = 0;
my integer $cnt_markdownlint_md033_need_tags_fixed = 0;
my integer $cnt_markdownlint_md037_fixed_emphasis = 0;
my integer $cnt_markdownlint_md049_converted_emphasis = 0;
my integer $cnt_markdownlint_md038_fixed_code_spans = 0;
my integer $cnt_markdownlint_md034_autolinked_urls = 0;
my integer $cnt_markdownlint_md035_normalized_hr = 0;
my integer $cnt_markdownlint_fenced_grep_blocks = 0;
my integer $cnt_markdownlint_fenced_patch_blocks = 0;
my integer $cnt_markdownlint_fenced_ed_diff_blocks = 0;
my integer $cnt_markdownlint_repaired_broken_diff_fences = 0;
my integer $cnt_markdownlint_fenced_diff_continuations = 0;
my integer $cnt_markdownlint_md031_inserted_blank_lines = 0;
my integer $cnt_markdownlint_md012_collapsed_blank_lines = 0;


# Profile configuration (Step 1a)
# This step centralizes policy selection. Enforcement is implemented in later steps.
my hashref $PROFILES = {
    'recommended-default' => {
        tiers => { A => 1, B => 1, C => 0, D => 1 },
        contamination_policy => 'flag',
        path_header_policy => 'preserve',
        backtick_unescape_policy => 'prose-only',
        relabel_policy => 'only-when-certain',
    },
};

sub usage_exit {
    my integer $exit_code = shift;
    print STDERR <<"USAGE";
Usage:
  perl chatgpt_markdown_fix.pl input.md
  perl chatgpt_markdown_fix.pl input1.md input2.md ...
  perl chatgpt_markdown_fix.pl --overwrite input.md
  perl chatgpt_markdown_fix.pl --dry-run input.md
  perl chatgpt_markdown_fix.pl --clean input.md
  Output files are written alongside inputs as: foo__fixed.<suffix>
  Supported input suffixes: .md .markdown .mdown .mkd .mkdn
Options:
  --help, -h                 Show this help.
  --overwrite                Allow clobbering existing foo__fixed.<suffix> files.
  --dry-run                  Do not write any files; still run fixes and tier checks.
  --clean                    Delete foo__fixed.<suffix> and foo__fixed.debug outputs for each input; leaves inputs intact.
  --double-fix             Allow processing inputs already tagged __fixed.<suffix> (disabled by default).
  --debug                    Enable debug logging and write foo__fixed.debug files.
  --no-debug                 Disable debug logging and do not write .debug files.
  --no-unescape-backticks    Do not convert "\`" to "`".
  --no-diff-fixes            Disable diff-specific cleanups.
  --markdownlint           Apply post-fixes for markdownlint (currently MD041 + MD048 + MD003 + MD019 + MD040 + MD009 + MD022 + MD001 + MD036 + MD025 + MD026 + MD032 + MD007 + MD004 + MD029 + MD030 + MD033 + MD034 + MD037 + MD049 + MD038 + MD035 + MD031 + MD012).
  --profile NAME             Select policy profile (default: recommended-default).
USAGE
    exit($exit_code);
}

sub is_supported_markdown_filename {
    my string $path = shift;
    return 0 if !defined $path;
    return 1 if $path =~ /\.(md|markdown|mdown|mkd|mkdn)\z/;
    return 0;
}


sub is_already_fixed_input_filename {
    my string $path = shift;
    return 0 if !defined $path;
    return 1 if $path =~ /__fixed\.(md|markdown|mdown|mkd|mkdn)\z/;
    return 0;
}


sub compute_fixed_output_path {
    my string $path = shift;
    return '' if !defined $path;

    my string $out = $path;
    if ($out !~ /\.(md|markdown|mdown|mkd|mkdn)\z/) {
        return '';
    }

    $out =~ s/\.(md|markdown|mdown|mkd|mkdn)\z/__fixed.$1/;
    return $out;
}


my boolean $help = 0;
my boolean $no_unescape_backticks = 0;
my boolean $no_diff_fixes = 0;
my boolean $overwrite = 0;
my boolean $dry_run = 0;
my boolean $clean = 0;
my boolean $double_fix = 0;
my boolean $markdownlint = 0;
my string $profile = 'recommended-default';

GetOptions(
    'help|h' => \$help,
    'no-unescape-backticks' => \$no_unescape_backticks,
    'no-diff-fixes' => \$no_diff_fixes,
    'overwrite' => \$overwrite,
    'dry-run' => \$dry_run,
    'clean' => \$clean,
    'double-fix' => \$double_fix,
    'markdownlint' => \$markdownlint,
    'debug!' => \$debug,
    'profile=s' => \$profile,
) or usage_exit(2);

usage_exit(0) if $help;

if ($clean) {
    # --clean is a deletion mode; it does not write outputs and should not run as --dry-run.
    $dry_run = 0;
}

if (!exists $PROFILES->{$profile}) {
    print STDERR "Unknown profile '$profile'\n";
    usage_exit(2);
}

my hashref $profile_cfg = $PROFILES->{$profile};
my string $policy_contamination = $profile_cfg->{'contamination_policy'};
my string $policy_path_header = $profile_cfg->{'path_header_policy'};
my string $policy_backtick_unescape = $profile_cfg->{'backtick_unescape_policy'};
my string $policy_relabel = $profile_cfg->{'relabel_policy'};
my boolean $tierA_enabled = ($profile_cfg->{'tiers'}->{'A'} ? 1 : 0);
my boolean $tierB_enabled = ($profile_cfg->{'tiers'}->{'B'} ? 1 : 0);
my boolean $tierC_enabled = ($profile_cfg->{'tiers'}->{'C'} ? 1 : 0);
my boolean $tierD_enabled = ($profile_cfg->{'tiers'}->{'D'} ? 1 : 0);

dbg("startup: profile=$profile debug=$debug overwrite=$overwrite dry_run=$dry_run clean=$clean double_fix=$double_fix markdownlint=$markdownlint no_unescape_backticks=$no_unescape_backticks no_diff_fixes=$no_diff_fixes policies: contamination=$policy_contamination path_header=$policy_path_header backtick_unescape=$policy_backtick_unescape relabel=$policy_relabel tiers=A:$tierA_enabled B:$tierB_enabled C:$tierC_enabled D:$tierD_enabled");


sub first_nonzero_detail {
    my hashref $details = shift;
    my arrayref $keys = shift;
    return '' if !defined $details;
    return '' if !defined $keys;

    for my $k (@{$keys}) {
        next if !exists $details->{$k};
        my $v = $details->{$k};
        next if !defined $v;
        next if $v == 0;
        return $k . '=' . $v;
    }
    return '';
}


sub build_tier_report {
    my hashref $result = shift;

    my arrayref $tier_parts = [];
    my arrayref $fail_parts = [];

    if ($tierA_enabled) {
        my string $pass_s = 'NA';
        my string $fail_s = '';
        if (defined $result && exists $result->{'tiers'}->{'A'}) {
            my boolean $pass = ($result->{'tiers'}->{'A'}->{'pass'} ? 1 : 0);
            $pass_s = ($pass ? '1' : '0');
            if (!$pass) {
                my hashref $details = $result->{'tiers'}->{'A'}->{'details'};
                $fail_s = first_nonzero_detail($details, [ 'unbalanced_fences', 'pre_close', 'diff_markers_outside' ]);
            }
        }
        push @{$tier_parts}, ('A=' . $pass_s);
        push @{$fail_parts}, ('A:' . $fail_s) if ($fail_s ne '');
    }

    if ($tierB_enabled) {
        my string $pass_s = 'NA';
        my string $fail_s = '';
        if (defined $result && exists $result->{'tiers'}->{'B'}) {
            my boolean $pass = ($result->{'tiers'}->{'B'}->{'pass'} ? 1 : 0);
            $pass_s = ($pass ? '1' : '0');
            if (!$pass) {
                my hashref $details = $result->{'tiers'}->{'B'}->{'details'};
                my arrayref $keys = [ 'code_tag_openers_outside', 'malformed_lang_openers_outside' ];
                if ($policy_backtick_unescape ne 'off') {
                    push @{$keys}, 'backslash_backticks_outside';
                }
                if (!$no_diff_fixes) {
                    push @{$keys}, 'diff_bare_atat_lines';
                    push @{$keys}, 'diff_invalid_hunk_lines';
                }
                if ($policy_contamination eq 'deny') {
                    push @{$keys}, 'diff_missing_headers_before_hunk';
                }
                $fail_s = first_nonzero_detail($details, $keys);
            }
        }
        push @{$tier_parts}, ('B=' . $pass_s);
        push @{$fail_parts}, ('B:' . $fail_s) if ($fail_s ne '');
    }

    if ($tierD_enabled) {
        my string $pass_s = 'NA';
        my string $fail_s = '';
        if (defined $result && exists $result->{'tiers'}->{'D'}) {
            my boolean $pass = ($result->{'tiers'}->{'D'}->{'pass'} ? 1 : 0);
            $pass_s = ($pass ? '1' : '0');
            if (!$pass) {
                my hashref $details = $result->{'tiers'}->{'D'}->{'details'};
                $fail_s = first_nonzero_detail($details, [ 'forbidden_rewrites', 'dropped_bare_atat' ]);
            }
        }
        push @{$tier_parts}, ('D=' . $pass_s);
        push @{$fail_parts}, ('D:' . $fail_s) if ($fail_s ne '');
    }

    my string $tier_s = '';
    if (scalar(@{$tier_parts}) > 0) {
        $tier_s = ' tiers:' . join(',', @{$tier_parts});
    }

    my string $fail_s = '';
    if (scalar(@{$fail_parts}) > 0) {
        $fail_s = ' fail:' . join(',', @{$fail_parts});
    }

    return ($tier_s, $fail_s);
}


sub result_is_tier_clean {
    my hashref $result = shift;

    return 0 if (!defined $result);
    return 0 if (!exists $result->{'tiers'});

    my hashref $tiers = $result->{'tiers'};

    if ($tierA_enabled) {
        return 0 if (!exists $tiers->{'A'} || !$tiers->{'A'}->{'pass'});
    }

    if ($tierB_enabled) {
        return 0 if (!exists $tiers->{'B'} || !$tiers->{'B'}->{'pass'});
    }

    if ($tierD_enabled) {
        return 0 if (!exists $tiers->{'D'} || !$tiers->{'D'}->{'pass'});
    }

    return 1;
}


# Inputs (Step 1 - multi-input plumbing)
# Inputs are required - STDIN mode is removed to support corpus-wide multi-file workflows.
if (!@ARGV) {
    print STDERR "please provide one or more Markdown file names as input\n";
    usage_exit(2);
}

my arrayref $input_paths = [ @ARGV ];

# The per-file loop sets $lines and calls run_fix_pipeline_on_lines().
my arrayref $lines = [];

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
    if ($line =~ /^([A-Za-z0-9_][A-Za-z0-9_+\-]*)`(.*)\z/s) {
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
    if ($line =~ /^(?:```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/) {
        return (1, $1); # $1 may be undef
    }
    return (0, undef);
}


sub is_indented_triple_fence_line {
    my $line = shift;
    return (0, undef) if !defined $line;

    if ($line =~ /^[ 	]{1,3}(?:```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/) {
        my $lang = $1;
        $lang = '' if !defined $lang;
        return (1, $lang);
    }

    return (0, undef);
}
sub is_malformed_pre_close {
    my $line = shift;
    return 0 if !defined $line;
    return ($line =~ /^\s*`<\/pre>\s*\z/);
}

sub parse_single_backtick_unterminated_line {
    my $line = shift;
    return undef if !defined $line;

    # Match a UI-export artifact where a multi-line inline code span starts with a
    # single leading backtick, but never closes on the same line:
    #   `perl
    #   `--- a/foo
    #   `wbraswell@host:~$ cmd
    # This must be treated as a missing fenced code block opener, not as inline code.
    return undef if $line =~ /^(?:```|~~~)/;
    if ($line =~ /^`([^`]*)\z/) {
        return $1;
    }
    return undef;
}

sub is_known_fence_lang {
    my $lang = shift;
    return 0 if !defined $lang;
    $lang =~ s/\s+\z//;
    $lang =~ s/^\s+//;

    # Keep this list intentionally small and conservative.
    return 1 if $lang eq 'perl';
    return 1 if $lang eq 'diff';
    return 1 if $lang eq 'bash';
    return 1 if $lang eq 'sh';
    return 1 if $lang eq 'zsh';
    return 1 if $lang eq 'console';
    return 1 if $lang eq 'text';
    return 1 if $lang eq 'yaml';
    return 1 if $lang eq 'yml';
    return 1 if $lang eq 'json';
    return 1 if $lang eq 'sql';
    return 0;
}

sub find_next_triple_fence_line_idx {
    my integer $idx = shift;
    my arrayref $aref = shift;
    my integer $limit = shift;

    $limit = 200 if !defined $limit || $limit <= 0;

    my integer $aref_len = scalar(@{$aref});
    my integer $max = $idx + $limit;
    $max = $aref_len - 1 if $max > ($aref_len - 1);

    my integer $j = $idx + 1;
    for (; $j <= $max; $j++) {
        my $l = $aref->[$j];
        next if !defined $l;

        my ($is_fence, $lang) = is_triple_fence_line($l);
        if ($is_fence) {
            return $j;
        }
    }

    return -1;
}

sub infer_lang_for_missing_fence_opener {
    my $first_line = shift;
    $first_line = '' if !defined $first_line;

    # Unified diff headers/hunks
    return 'diff' if $first_line =~ /^(---|\+\+\+)\s/;
    return 'diff' if $first_line =~ /^@@/;

    # Typical shell prompt lines
    return 'bash' if $first_line =~ /^[A-Za-z0-9_.-]+\@[A-Za-z0-9_.-]+:.*[\$\#]\s/;
    return 'bash' if $first_line =~ /^\$\s/;

    # Perl-like snippets
    return 'perl' if $first_line =~ /^\s*(package|use|our|my)\b/;

    return 'text';
}

sub looks_like_new_block_opener_line {
    my $line = shift;
    return 0 if !defined $line;
    return 1 if $line =~ /^<code>/;
    return 1 if $line =~ /^[A-Za-z0-9_][A-Za-z0-9_+\-]*`/;
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

    # Special case: inside a diff hunk, consecutive bare triple-fence lines are
    # frequently the close of an inner code fence immediately followed by the
    # close of the outer ```diff block. Treat the first fence as diff payload.
    my integer $k = $idx + 1;
    while ($k < scalar(@{$aref})) {
        my $l1 = $aref->[$k];
        $k++;
        next if !defined $l1;

        my string $t1 = $l1;
        if (!$no_unescape_backticks) {
            $t1 =~ s/\\`/`/g;
        }

        next if $t1 =~ /^\s*\z/;

        return 1 if $t1 =~ /^```\s*\z/;
        last;
    }

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
        return 1 if $t =~ /^\*\*(You|ChatGPT):\*\*/;
        return 1 if $t =~ /^\*\s*\*\s*\*\s*\z/;
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
                return 1 if $t2 =~ /^\*\*(You|ChatGPT):\*\*/;
                return 1 if $t2 =~ /^\*\s*\*\s*\*\s*\z/;
            }
        }

        $seen++;
    }

    return 0;
}




sub should_treat_triple_fence_as_diff_payload {
    my integer $idx = shift;
    my arrayref $aref = shift;
    my boolean $no_unescape_backticks = shift;

    my integer $limit = 200;
    my integer $seen = 0;

    # Special case: inside a diff hunk, consecutive bare triple-fence lines are
    # frequently the close of an inner code fence immediately followed by the
    # close of the outer ```diff block. Treat the first fence as diff payload.
    my integer $k = $idx + 1;
    while ($k < scalar(@{$aref})) {
        my $l1 = $aref->[$k];
        $k++;
        next if !defined $l1;

        my string $t1 = $l1;
        if (!$no_unescape_backticks) {
            $t1 =~ s/\\`/`/g;
        }

        next if $t1 =~ /^\s*\z/;

        return 1 if $t1 =~ /^```\s*\z/;
        last;
    }

    my integer $j = $idx + 1;
    for (; $j < scalar(@{$aref}) && $seen < $limit; $j++) {
        my $l = $aref->[$j];
        next if !defined $l;

        my string $t = $l;
        if (!$no_unescape_backticks) {
            $t =~ s/\\`/`/g;
        }

        next if $t =~ /^\s*\z/;

        # Strong diff continuation signals: treat the current fence as diff payload.
        return 1 if is_proper_hunk_header($t);
        return 1 if $t =~ /^diff --git\b/;
        return 1 if $t =~ /^(---|\+\+\+)\s+\S/;
        return 1 if $t =~ /^index\s+[0-9a-f]+\.\.[0-9a-f]+\b/;
        return 1 if $t =~ /^\\ No newline at end of file/;

        # Strong chat / narrative boundaries: treat the current fence as a real close.
        return 0 if $t =~ /^\*\*(You|ChatGPT)\*\*:/;
        return 0 if $t =~ /^\*\*(You|ChatGPT):\*\*/;
        return 0 if $t =~ /^\*\s*\*\s*\*\s*\z/;
        return 0 if $t =~ /^<a\s+data-start=/;
        return 0 if $t =~ /^\s*---\s*\z/;

        $seen++;
    }

    return 0;
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
sub infer_single_file_path_for_diff_context {
    my integer $idx = shift;
    my arrayref $aref = shift;
    my boolean $no_unescape_backticks = shift;

    my integer $scan = 80;
    my integer $j = $idx - 1;
    for (; $j >= 0 && ($idx - $j) <= $scan; $j--) {
        my $l = $aref->[$j];
        next if !defined $l;

        my string $t = $l;
        if (!$no_unescape_backticks) {
            $t =~ s/\\`/`/g;
        }

        next if $t =~ /^\s*$/;

        # Only trust lines that explicitly describe a patch for a single file.
        next if $t !~ /\bpatch\b/i;

        my @candidates = ($t =~ /`([^`]+)`/g);
        next if scalar(@candidates) != 1;

        my string $cand = $candidates[0];

        next if $cand =~ /\s/;
        next if $cand =~ /</;
        next if $cand !~ m{/};
        next if $cand !~ /\.[A-Za-z0-9]{1,8}$/;

        return $cand;
    }

    return "";
}

sub normalize_diff_header_line {
    my string $kind = shift;
    my string $rest = shift;

    $rest =~ s/^\s+//;

    if ($policy_path_header eq 'preserve') {
        return ($kind . ' ' . $rest);
    }
    my ($path) = split(/\s+/, $rest, 2);
    $path //= $rest;

    $path =~ s/\.orig\z//;
    $path =~ s{^/mnt/data/}{};
    $path =~ s{^/+}{};

    return ($kind . ' ' . $path);
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
my integer $block_open_out_idx = -1; # index in $out for the opening fence line


# diff state
my boolean $diff_have_headers = 0;
my boolean $diff_missing_headers_warned = 0;
my boolean $diff_in_hunk = 0;

# diff contamination state (Step 2)
my boolean $diff_contam_curr_block_seen = 0;
my integer $diff_contam_curr_first_input_idx = -1;
my integer $diff_contam_curr_lines_outside_hunk = 0;
my integer $diff_contam_curr_hunk_empty_lines = 0;
my integer $diff_contam_curr_hunk_nonprefix_lines = 0;
my integer $diff_contam_curr_missing_headers_before_hunk = 0;
my integer $diff_contam_curr_dropped_bare_atat = 0;
my integer $diff_contam_curr_first_outside_hunk_input_idx = -1;
my string $diff_contam_curr_first_outside_hunk_line = '';
my boolean $diff_contam_warned_outside_hunk = 0;
my boolean $diff_contam_warned_hunk_empty = 0;
my boolean $diff_contam_warned_hunk_nonprefix = 0;

# For relabeling ```diff blocks that are not actually diffs.
my boolean $diff_saw_header_minus = 0;
my boolean $diff_saw_header_plus  = 0;
my boolean $diff_saw_git_header   = 0;
my boolean $diff_saw_hunk_header  = 0;

my boolean $diff_relabel_command_only_candidate = 1;
my boolean $diff_relabel_saw_prompt_or_output = 0;
my integer $diff_relabel_nonblank_lines = 0;
my string  $diff_relabel_first_nonblank = '';

sub reset_diff_block_relabel_state {
    $diff_saw_header_minus = 0;
    $diff_saw_header_plus  = 0;
    $diff_saw_git_header   = 0;
    $diff_saw_hunk_header  = 0;

    $diff_relabel_command_only_candidate = 1;
    $diff_relabel_saw_prompt_or_output = 0;
    $diff_relabel_nonblank_lines = 0;
    $diff_relabel_first_nonblank = '';
}

sub reset_diff_block_contamination_state {
    $diff_contam_curr_block_seen = 0;
    $diff_contam_curr_first_input_idx = -1;
    $diff_contam_curr_lines_outside_hunk = 0;
    $diff_contam_curr_hunk_empty_lines = 0;
    $diff_contam_curr_hunk_nonprefix_lines = 0;
    $diff_contam_curr_missing_headers_before_hunk = 0;
    $diff_contam_curr_dropped_bare_atat = 0;
    $diff_contam_curr_first_outside_hunk_input_idx = -1;
    $diff_contam_curr_first_outside_hunk_line = '';
    $diff_contam_warned_outside_hunk = 0;
    $diff_contam_warned_hunk_empty = 0;
    $diff_contam_warned_hunk_nonprefix = 0;
}

sub mark_diff_contaminated {
    my integer $input_idx = shift;

    if (!$diff_contam_curr_block_seen) {
        $diff_contam_curr_block_seen = 1;
        $cnt_diff_contam_blocks++;
    }
    if ($diff_contam_curr_first_input_idx < 0) {
        $diff_contam_curr_first_input_idx = $input_idx;
    }
}

sub maybe_report_diff_contamination_on_block_close {
    my integer $close_input_idx = shift;
    return if $policy_contamination ne 'flag';
    return if !$diff_contam_curr_block_seen;

    if (($diff_contam_curr_lines_outside_hunk > 0) && ($diff_contam_curr_first_outside_hunk_input_idx >= 0)) {
        dbg('diff-contam: unexpected line outside hunk first_seen_input_idx='
            . $diff_contam_curr_first_outside_hunk_input_idx
            . ' line=' . $diff_contam_curr_first_outside_hunk_line);
    }

    dbg('diff-contam: block_summary open_out_idx=' . $block_open_out_idx
        . ' first_input_idx=' . $diff_contam_curr_first_input_idx
        . ' close_input_idx=' . $close_input_idx
        . ' outside_hunk=' . $diff_contam_curr_lines_outside_hunk
        . ' hunk_empty=' . $diff_contam_curr_hunk_empty_lines
        . ' hunk_nonprefix=' . $diff_contam_curr_hunk_nonprefix_lines
        . ' dropped_bare_atat=' . $diff_contam_curr_dropped_bare_atat
        . ' missing_headers_before_hunk=' . $diff_contam_curr_missing_headers_before_hunk);
}

sub looks_like_shell_prompt_line {
    my $l = shift;
    return 0 if !defined $l;
    return ($l =~ /^[\$#>]\s+/);
}

sub looks_like_shell_output_line {
    my $l = shift;
    return 0 if !defined $l;

    return 1 if $l =~ /^total\s+\d+\b/;
    return 1 if $l =~ /^[dl-][rwx-]{9}\b/;
    return 1 if $l =~ /^\s*Deleted\s+`/;
    return 1 if $l =~ /^\s*Created\s+`/;
    return 1 if $l =~ /^\s*Removed\s+`/;

    return 0;
}

sub looks_like_shell_command_line {
    my $l = shift;
    return 0 if !defined $l;
    return 0 if $l =~ /^\s*\z/;

    return 0 if looks_like_shell_prompt_line($l);
    return 0 if looks_like_shell_output_line($l);

    return 1 if $l =~ /^\s*#!/;
    return 1 if $l =~ /^\s*[A-Za-z_][A-Za-z0-9_]*=/;
    return 1 if $l =~ /^\s*(?:sudo\s+)?[A-Za-z0-9_~.\/][A-Za-z0-9_~.\/:-]*/;

    return 0;
}

sub note_diff_block_line_for_relabel {
    my $l = shift;
    return if !defined $l;

    if ($l !~ /^\s*\z/) {
        $diff_relabel_nonblank_lines++;
        if (!defined($diff_relabel_first_nonblank) || $diff_relabel_first_nonblank eq '') {
            $diff_relabel_first_nonblank = $l;
        }
    }

    if (looks_like_shell_prompt_line($l) || looks_like_shell_output_line($l)) {
        $diff_relabel_saw_prompt_or_output = 1;
    }

    if ($l !~ /^\s*\z/ && !looks_like_shell_command_line($l)) {
        $diff_relabel_command_only_candidate = 0;
    }
}

sub choose_non_diff_language_for_diff_block {
    my string $first = $diff_relabel_first_nonblank;
    $first //= '';

    if ($first =~ /^\s*#!\s*(?:\/bin\/sh|\/usr\/bin\/env\s+sh)\b/) {
        return 'sh';
    }
    if ($first =~ /^\s*#!/) {
        return 'bash';
    }

    return 'console' if $diff_relabel_saw_prompt_or_output;
    return 'bash' if $diff_relabel_command_only_candidate && $diff_relabel_nonblank_lines > 0;
    return 'console';
}

sub maybe_relabel_non_diff_diff_block {
    return if !defined $block_lang || $block_lang ne 'diff';
    return if $block_open_out_idx < 0;

    my boolean $is_real_diff =
        $diff_saw_hunk_header
        || $diff_saw_git_header
        || ($diff_saw_header_minus && $diff_saw_header_plus);

    if ($is_real_diff) {
        dbg("diff-relabel: keep as diff (real diff signals present) open_out_idx=$block_open_out_idx");
        return;
    }

    if ($policy_relabel eq 'never') {
        dbg("diff-relabel: policy=never keep as diff open_out_idx=" . $block_open_out_idx);
        return;
    }

    if ($policy_relabel eq 'only-when-certain') {
        my boolean $certain = 0;

        $certain = 1 if $diff_relabel_saw_prompt_or_output;
        $certain = 1 if (!$certain && $diff_relabel_command_only_candidate && ($diff_relabel_nonblank_lines > 0));

        if (!$certain) {
            $cnt_blocks_relabel_diff_uncertain++;
            dbg("diff-relabel: policy=only-when-certain keep as diff (uncertain) open_out_idx=" . $block_open_out_idx . " first_nonblank='" . $diff_relabel_first_nonblank . "'");
            return;
        }
    }

    my string $lang = choose_non_diff_language_for_diff_block();
    dbg("diff-relabel: relabel diff -> " . $lang . " open_out_idx=" . $block_open_out_idx
        . " first_nonblank='" . $diff_relabel_first_nonblank
        . "' saw_prompt_or_output=" . $diff_relabel_saw_prompt_or_output
        . " command_only_candidate=" . $diff_relabel_command_only_candidate
        . " nonblank_lines=" . $diff_relabel_nonblank_lines);

    if ($lang eq 'console') { $cnt_blocks_relabel_diff_to_console++; }
    elsif ($lang eq 'bash') { $cnt_blocks_relabel_diff_to_bash++; }
    elsif ($lang eq 'sh') { $cnt_blocks_relabel_diff_to_sh++; }

    # If we relabel away from diff, do not count this block toward diff-contamination stats.
    if (($policy_contamination eq 'flag') && $diff_contam_curr_block_seen) {
        $cnt_diff_contam_blocks-- if $cnt_diff_contam_blocks > 0;

        if ($cnt_diff_contam_lines_outside_hunk >= $diff_contam_curr_lines_outside_hunk) {
            $cnt_diff_contam_lines_outside_hunk -= $diff_contam_curr_lines_outside_hunk;
        }
        else {
            $cnt_diff_contam_lines_outside_hunk = 0;
        }

        if ($cnt_diff_contam_hunk_empty_lines >= $diff_contam_curr_hunk_empty_lines) {
            $cnt_diff_contam_hunk_empty_lines -= $diff_contam_curr_hunk_empty_lines;
        }
        else {
            $cnt_diff_contam_hunk_empty_lines = 0;
        }

        if ($cnt_diff_contam_hunk_nonprefix_lines >= $diff_contam_curr_hunk_nonprefix_lines) {
            $cnt_diff_contam_hunk_nonprefix_lines -= $diff_contam_curr_hunk_nonprefix_lines;
        }
        else {
            $cnt_diff_contam_hunk_nonprefix_lines = 0;
        }

        if ($cnt_diff_contam_missing_headers_before_hunk >= $diff_contam_curr_missing_headers_before_hunk) {
            $cnt_diff_contam_missing_headers_before_hunk -= $diff_contam_curr_missing_headers_before_hunk;
        }
        else {
            $cnt_diff_contam_missing_headers_before_hunk = 0;
        }

        if ($cnt_diff_contam_dropped_bare_atat >= $diff_contam_curr_dropped_bare_atat) {
            $cnt_diff_contam_dropped_bare_atat -= $diff_contam_curr_dropped_bare_atat;
        }
        else {
            $cnt_diff_contam_dropped_bare_atat = 0;
        }

        # Suppress per-block contamination reporting for this relabeled block.
        $diff_contam_curr_block_seen = 0;
        $diff_contam_curr_first_input_idx = -1;
        $diff_contam_curr_lines_outside_hunk = 0;
        $diff_contam_curr_hunk_empty_lines = 0;
        $diff_contam_curr_hunk_nonprefix_lines = 0;
        $diff_contam_curr_missing_headers_before_hunk = 0;
        $diff_contam_curr_dropped_bare_atat = 0;
        $diff_contam_curr_first_outside_hunk_input_idx = -1;
        $diff_contam_curr_first_outside_hunk_line = '';
    }

    $out->[$block_open_out_idx] = "```" . $lang;
}

# Track the current unified-diff hunk so we can rewrite its @@ header counts.
my integer $diff_hunk_header_out_idx = -1;
my integer $diff_hunk_old_start = 0;
my integer $diff_hunk_new_start = 0;
my integer $diff_hunk_old_count = 0;
my integer $diff_hunk_new_count = 0;
my string $diff_hunk_trail = '';

sub reset_run_state {
    # Per-run counters
    $cnt_unescaped_backticks = 0;
    $cnt_blocks_opened = 0;
    $cnt_blocks_closed = 0;
    $cnt_blocks_opened_diff = 0;
    $cnt_blocks_relabel_diff_to_console = 0;
    $cnt_blocks_relabel_diff_to_bash = 0;
    $cnt_blocks_relabel_diff_to_sh = 0;
    $cnt_blocks_relabel_diff_uncertain = 0;
    $cnt_spill_close_on_new_opener = 0;
    $cnt_close_on_blank_after_malformed = 0;
    $cnt_malformed_pre_close_seen = 0;
    $cnt_malformed_pre_close_ignored = 0;
    $cnt_malformed_code_tag_openers = 0;
    $cnt_malformed_lang_openers = 0;
    $cnt_unwrapped_less_markdown_blocks = 0;
    $cnt_unwrapped_html_anchors = 0;
    $cnt_diff_git_header_lines = 0;
    $cnt_diff_header_lines = 0;
    $cnt_diff_hunk_headers = 0;
    $cnt_diff_hunk_header_rewrites = 0;
    $cnt_diff_hunk_lines_empty_to_space = 0;
    $cnt_diff_hunk_lines_prefixed_space = 0;
    $cnt_diff_hunk_lines_passthrough = 0;
    $cnt_diff_missing_headers_before_hunk = 0;
    $cnt_diff_contam_blocks = 0;
    $cnt_diff_contam_lines_outside_hunk = 0;
    $cnt_diff_contam_hunk_empty_lines = 0;
    $cnt_diff_contam_hunk_nonprefix_lines = 0;
    $cnt_diff_contam_missing_headers_before_hunk = 0;
    $cnt_diff_contam_dropped_bare_atat = 0;
    $cnt_diff_tierD_allowed_rewrites = 0;
    $cnt_diff_tierD_forbidden_rewrites = 0;
    $cnt_diff_tierD_dropped_bare_atat = 0;

    # Per-run output and parser state
    $out = [];

    $in_block = 0;
    $block_lang = '';
    $block_started_malformed = 0;
    $block_open_out_idx = -1;

    $diff_have_headers = 0;
    $diff_missing_headers_warned = 0;
    $diff_in_hunk = 0;

    reset_diff_block_contamination_state();
    reset_diff_block_relabel_state();

    # Current unified-diff hunk tracking
    $diff_hunk_header_out_idx = -1;
    $diff_hunk_old_start = 0;
    $diff_hunk_new_start = 0;
    $diff_hunk_old_count = 0;
    $diff_hunk_new_count = 0;
    $diff_hunk_trail = '';
}


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

    my string $old_hdr = $out->[$diff_hunk_header_out_idx];

    my string $trail = $diff_hunk_trail;
    $trail //= '';

    my string $hdr =
        '@@ -' . $diff_hunk_old_start . ',' . $diff_hunk_old_count
        . ' +' . $diff_hunk_new_start . ',' . $diff_hunk_new_count
        . ' @@' . $trail;

    my boolean $did_change = ($old_hdr ne $hdr);

    if ($did_change) {
        $out->[$diff_hunk_header_out_idx] = $hdr;

        $cnt_diff_hunk_header_rewrites++;
        dbg('diff-hunk: rewrite header out_idx=' . $diff_hunk_header_out_idx . ' old=' . $old_hdr . ' new=' . $hdr);

        if ($tierD_enabled) {
            $cnt_diff_tierD_allowed_rewrites++;
        }
    }


    $diff_hunk_header_out_idx = -1;
    $diff_hunk_old_count = 0;
    $diff_hunk_new_count = 0;
    $diff_hunk_trail = '';
}



sub validate_tierA_output {
    my arrayref $out_lines = shift;

    my integer $cnt_fence_lines = 0;
    my integer $cnt_pre_close = 0;
    my integer $cnt_diff_markers_outside = 0;
    my boolean $in_any_fence = 0;

    my integer $idx = 0;
    while ($idx < scalar(@{$out_lines})) {
        my string $line = $out_lines->[$idx];

        my boolean $is_fence = 0;
        my string $fence_lang = undef;
        my @f = is_triple_fence_line($line);
        if ($f[0]) {
            $is_fence = 1;
            $fence_lang = $f[1];
        }

        if ($is_fence) {
            $cnt_fence_lines++;
            $in_any_fence = ($in_any_fence ? 0 : 1);
            $idx++;
            next;
        }

        if (!$in_any_fence) {
            if (defined $line && ($line =~ /<\/pre>/)) {
                $cnt_pre_close++;
            }

            # Diff markers should not appear outside fenced code blocks.
            if (defined $line) {
                if ($line =~ /^diff --git\b/) {
                    $cnt_diff_markers_outside++;
                }
                elsif ($line =~ /^@@\s+-\d+/) {
                    $cnt_diff_markers_outside++;
                }
                elsif ($line =~ /^(---|\+\+\+)\s+(?:a\/|b\/|\/mnt\/|\S+\.orig\b|\S+\t\d{4}-\d{2}-\d{2})/) {
                    # Ignore a pure Markdown horizontal rule line '---'
                    $cnt_diff_markers_outside++ if $line ne '---';
                }
            }
        }

        $idx++;
    }

    my integer $cnt_unbalanced_fences = 0;
    $cnt_unbalanced_fences = 1 if $in_any_fence;

    return {
        fence_lines => $cnt_fence_lines,
        unbalanced_fences => $cnt_unbalanced_fences,
        pre_close => $cnt_pre_close,
        diff_markers_outside => $cnt_diff_markers_outside,
    };
}


sub validate_tierB_output {
    my arrayref $out_lines = shift;

    my integer $cnt_code_tag_openers_outside = 0;
    my integer $cnt_malformed_lang_openers_outside = 0;
    my integer $cnt_backslash_backticks_outside = 0;

    my integer $cnt_diff_bare_atat_lines = 0;
    my integer $cnt_diff_invalid_hunk_lines = 0;
    my integer $cnt_diff_missing_headers_before_hunk = 0;

    my boolean $in_any_fence = 0;
    my string $curr_lang = '';

    my boolean $in_diff = 0;
    my boolean $diff_in_hunk = 0;
    my boolean $diff_saw_git = 0;
    my boolean $diff_saw_minus = 0;
    my boolean $diff_saw_plus = 0;
    my boolean $diff_missing_headers_flagged = 0;

    my integer $idx = 0;
    while ($idx < scalar(@{$out_lines})) {
        my string $line = $out_lines->[$idx];

        my boolean $is_fence = 0;
        my string $fence_lang = undef;
        my @f = is_triple_fence_line($line);
        if ($f[0]) {
            $is_fence = 1;
            $fence_lang = $f[1];
        }

        if ($is_fence) {
            if (!$in_any_fence) {
                $in_any_fence = 1;
                $curr_lang = defined($fence_lang) ? $fence_lang : '';

                $in_diff = 1 if $curr_lang eq 'diff';
                if ($in_diff) {
                    $diff_in_hunk = 0;
                    $diff_saw_git = 0;
                    $diff_saw_minus = 0;
                    $diff_saw_plus = 0;
                    $diff_missing_headers_flagged = 0;
                }
            }
            else {
                $in_any_fence = 0;
                $curr_lang = '';
                $in_diff = 0;
                $diff_in_hunk = 0;
            }

            $idx++;
            next;
        }

        if (!$in_any_fence) {
            if (defined $line && ($line =~ /^<code>/)) {
                $cnt_code_tag_openers_outside++;
            }

            if (defined $line && ($line =~ /^(?:diff|perl|bash|text|console|json|yaml|html|xml|sh)`/)) {
                $cnt_malformed_lang_openers_outside++;
            }

            if ($policy_backtick_unescape ne 'off') {
                if (defined $line) {
                    my integer $n = 0;
                    $n++ while ($line =~ /\\`/g);
                    $cnt_backslash_backticks_outside += $n;
                }
            }

            $idx++;
            next;
        }

        if ($in_diff) {
            if (defined $line && ($line =~ /^diff --git\b/)) {
                $diff_saw_git = 1;
            }
            elsif (defined $line && ($line =~ /^---\s+/)) {
                $diff_saw_minus = 1;
            }
            elsif (defined $line && ($line =~ /^\+\+\+\s+/)) {
                $diff_saw_plus = 1;
            }

            if (defined $line && ($line =~ /^@@\s*\z/)) {
                $cnt_diff_bare_atat_lines++;
            }

            if (defined $line && ($line =~ /^@@\s*-\d+/)) {
                $diff_in_hunk = 1;

                if (!$diff_missing_headers_flagged) {
                    my boolean $have_headers = 0;
                    $have_headers = 1 if $diff_saw_git;
                    $have_headers = 1 if (!$have_headers && $diff_saw_minus && $diff_saw_plus);

                    if (!$have_headers) {
                        $cnt_diff_missing_headers_before_hunk++;
                        $diff_missing_headers_flagged = 1;
                    }
                }
            }
            elsif ($diff_in_hunk) {
                if (defined $line && ($line !~ /^\s*\z/)) {
                    if ($line !~ /^[\\ \+\-]/) {
                        # Allow a new hunk header or header lines to reset hunk state.
                        if ($line =~ /^@@\s*-\d+/) {
                            # (handled above)
                        }
                        elsif ($line =~ /^diff --git\b/ || $line =~ /^---\s+/ || $line =~ /^\+\+\+\s+/) {
                            $diff_in_hunk = 0;
                        }
                        else {
                            $cnt_diff_invalid_hunk_lines++;
                        }
                    }
                }
            }

            $idx++;
            next;
        }

        $idx++;
    }

    return {
        code_tag_openers_outside => $cnt_code_tag_openers_outside,
        malformed_lang_openers_outside => $cnt_malformed_lang_openers_outside,
        backslash_backticks_outside => $cnt_backslash_backticks_outside,
        diff_bare_atat_lines => $cnt_diff_bare_atat_lines,
        diff_invalid_hunk_lines => $cnt_diff_invalid_hunk_lines,
        diff_missing_headers_before_hunk => $cnt_diff_missing_headers_before_hunk,
    };
}


sub run_fix_pipeline_on_lines {
    my arrayref $lines_in = shift;
    $lines = $lines_in;
    reset_run_state();

my integer $dbg_start_idx = 0;
$dbg_start_idx = scalar(@{$dbg_lines}) if $debug;

my integer $i = 0;

LINE: while ($i < scalar(@{$lines})) {
    my string $line = $lines->[$i];

    # Unescape of backslash-escaped backticks, unless disabled.
    # Under backtick_unescape_policy=prose-only, do not unescape inside fenced code blocks.
    my boolean $allow_unescape_backticks = 0;
    if (!$no_unescape_backticks) {
        if ($policy_backtick_unescape eq 'off') {
            $allow_unescape_backticks = 0;
        }
        elsif ($policy_backtick_unescape eq 'prose-only') {
            $allow_unescape_backticks = 1 if !$in_block;
        }
        else {
            # 'all' (or unknown) - legacy behavior
            $allow_unescape_backticks = 1;
        }
    }
    if ($allow_unescape_backticks) {
        my integer $n = ($line =~ s/\\`/`/g);
        $cnt_unescaped_backticks += $n if $n;
    }

    # If not in code, handle UI-export artifacts and other prose-level repairs.
    if (!$in_block) {
        # Unwrap ChatGPT UI export anchors like:
        #   <a ... class="cursor-pointer">Download ...</a>
        # Preserve only the visible text.
        if (defined $line && ($line =~ /<a\b/i) && ($line =~ /<\/a>/i)) {
            my string $old_line = $line;
            $line =~ s/<a\b[^>]*>//ig;
            $line =~ s/<\/a>//ig;
            if ($line ne $old_line) {
                $cnt_unwrapped_html_anchors++;
                dbg('unwrap-anchor: input_idx=' . $i);
            }
        }

        # If a UI export produced a multi-line inline code span that starts with
        # `--- a/...` then the following `+++ ...` line can leak without the
        # opening backtick. Prefix it with a backtick so TierA does not see raw
        # diff markers outside fences.
        if (defined $line && ($line =~ /^\+\+\+\s+(?:a\/|b\/|\/mnt\/|\S+\.orig\b|\S+\t\d{4}-\d{2}-\d{2})/)) {
            my string $prev = ($i > 0) ? $lines->[$i - 1] : '';
            if (!$no_unescape_backticks && defined $prev) {
                $prev =~ s/\\`/`/g;
            }
            if (defined $prev && ($prev =~ /^`---\s+/)) {
                $line = '`' . $line;
                dbg('inline-code: prefixed +++ diff header with backtick at input_idx=' . $i);
            }
        }

        # Fix a common UI-export corruption where a multi-line inline code span
        # starts with a single leading backtick (often `perl, `---, or `user@host$ ...)
        # and later closes with a bare triple-fence line. Convert it into a real
        # fenced code block opener so the Markdown is structurally correct.
        my string $sb = parse_single_backtick_unterminated_line($line);
        if (defined $sb) {
            my integer $fidx = find_next_triple_fence_line_idx($i, $lines, 400);
            if ($fidx >= 0) {
                my $fline = $lines->[$fidx];
                my ($is_f, $f_lang) = is_triple_fence_line($fline);

                # Only treat the first encountered fence as a close candidate when it is bare.
                if ($is_f && (!defined($f_lang) || $f_lang eq '')) {
                    my string $trim = $sb;
                    $trim =~ s/\s+\z//;

                    # Case A: the line is actually the language label (ex: `perl)
                    if ($trim =~ /^[A-Za-z][A-Za-z0-9_+\-]*\z/ && is_known_fence_lang($trim)) {
                        $lines->[$i] = '```' . $trim;
                        $cnt_fixed_single_backtick_lang_fence_openers++;
                        dbg('single-backtick-fence: rewrite `LANG to ```LANG at input_idx=' . $i);
                        next LINE;
                    }

                    # Case B: the line is the first code payload line; insert a new opener.
                    my string $ilang = infer_lang_for_missing_fence_opener($sb);
                    $lines->[$i] = '```' . $ilang;
                    splice @{$lines}, $i + 1, 0, $sb;
                    $cnt_fixed_single_backtick_missing_fence_openers++;
                    dbg('single-backtick-fence: insert missing opener ```' . $ilang . ' at input_idx=' . $i);

                    # Special: if this is a diff block and the next line is a diff header that was
                    # also prefixed with a single backtick, strip that prefix now that we are fenced.
                    if ($ilang eq 'diff') {
                        my integer $nidx = $i + 2;
                        if ($nidx < scalar(@{$lines})) {
                            my $nl = $lines->[$nidx];
                            if (defined $nl && $nl =~ /^`(?:---|\+\+\+)\s/) {
                                $nl =~ s/^`//;
                                $lines->[$nidx] = $nl;
                                dbg('single-backtick-fence: stripped backtick from diff header line at input_idx=' . $nidx);
                            }
                        }
                    }

                    next LINE;
                }
            }
        }

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

        my boolean $is_new_triple_fence_opener = 0;
        my ($maybe_tf, $maybe_tf_lang) = is_triple_fence_line($line);
        if ($maybe_tf && defined($maybe_tf_lang) && $maybe_tf_lang ne '') {
            $is_new_triple_fence_opener = 1;
            if ($block_lang eq 'diff' && $diff_in_hunk) {
                $is_new_triple_fence_opener = 0
                    if should_treat_triple_fence_as_diff_payload($i, $lines, $no_unescape_backticks);
            }
        }

        if ($have_malformed && ($block_lang eq 'diff')) {
            $line = $mal_rest;
        }
        elsif ($is_new_triple_fence_opener || looks_like_new_block_opener_line($line)) {
            $cnt_spill_close_on_new_opener++;
            dbg("spill-fix: closing unterminated block lang='$block_lang' at input_idx=$i due to new opener line");
            if ($block_lang eq 'diff' && $diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            if ($block_lang eq 'diff' && !$no_diff_fixes) {
                maybe_relabel_non_diff_diff_block();
            }
            if ($block_lang eq 'diff') {
                maybe_report_diff_contamination_on_block_close($i);
                reset_diff_block_contamination_state();
            }
            $cnt_blocks_closed++;
            dbg("spill-close: input_idx=$i lang='$block_lang'");
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_open_out_idx = -1;
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_missing_headers_warned = 0;
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
            $cnt_close_on_blank_after_malformed++;
            dbg("spill-fix: closing malformed-started block before blank at input_idx=$i lang='$block_lang'");
            $cnt_blocks_closed++;
            dbg("spill-close: blank input_idx=$i lang='$block_lang'");
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_open_out_idx = -1;
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_missing_headers_warned = 0;
            $diff_in_hunk = 0;

            push @{$out}, $line; # keep the blank line outside the block
            $i++;
            next LINE;
        }
    }

    # Special case: inside a diff hunk, an indented triple-fence line (1-3 spaces)
    # is often a real fence boundary that the exporter indented under bullets.
    # If the following region looks like narrative/chat (not diff continuation),
    # treat it as a real fence close, not as hunk content.
    if ($in_block && $block_lang eq 'diff' && $diff_in_hunk) {
        my ($maybe_ifence, $maybe_ilang) = is_indented_triple_fence_line($line);
        if ($maybe_ifence
            && !should_treat_triple_fence_as_diff_payload($i, $lines, $no_unescape_backticks))
        {
            $cnt_blocks_closed++;
            dbg("fence-close: indented inside diff hunk at input_idx=$i lang='$block_lang'");
            finalize_current_diff_hunk_header();
            $diff_in_hunk = 0;
            if ($block_lang eq 'diff' && !$no_diff_fixes) {
                maybe_relabel_non_diff_diff_block();
            }
            if ($block_lang eq 'diff') {
                maybe_report_diff_contamination_on_block_close($i);
                reset_diff_block_contamination_state();
            }
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_open_out_idx = -1;
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_missing_headers_warned = 0;
            $diff_in_hunk = 0;
            $i++;
            next LINE;
        }
    }

    # Special case: inside a diff hunk, a bare triple-fence line may be patch payload
    # (lost its leading ' ', '+' or '-' prefix) rather than a real Markdown fence boundary.
    if ($in_block && $block_lang eq 'diff' && $diff_in_hunk) {
        my ($maybe_fence, $maybe_lang) = is_triple_fence_line($line);
        if ($maybe_fence && should_treat_triple_fence_as_diff_payload($i, $lines, $no_unescape_backticks)) {
            my string $out_line = (' ' . $line);
            $cnt_diff_hunk_lines_prefixed_space++;
            if ($tierD_enabled) {
                $cnt_diff_tierD_allowed_rewrites++;
            }
            if ($policy_contamination eq 'flag') {
                $cnt_diff_contam_hunk_nonprefix_lines++;
                mark_diff_contaminated($i);
            }
            count_hunk_line($out_line);
            push @{$out}, $out_line;
            $i++;
            next LINE;
        }
    }

    # Handle triple fences in input
    my ($is_fence, $f_lang) = is_triple_fence_line($line);
    if ($is_fence) {
        if (!$in_block) {
            $in_block = 1;

            my string $open_line = $line;
            $block_lang = defined($f_lang) ? $f_lang : '';
            if ($markdownlint && $block_lang eq '') {
                $open_line = '```text';
                $block_lang = 'text';
            }

            $block_started_malformed = 0;
            $cnt_blocks_opened++;
            $cnt_blocks_opened_diff++ if $block_lang eq 'diff';
            dbg("fence-open: input_idx=$i lang='$block_lang'");
            push @{$out}, $open_line;
            $block_open_out_idx = scalar(@{$out}) - 1;

            if ($block_lang eq 'diff') {
                reset_diff_block_relabel_state();
                reset_diff_block_contamination_state();
                $diff_have_headers = 0;
                $diff_missing_headers_warned = 0;
                $diff_in_hunk = 0;
            }
        } else {
            if ($block_lang eq 'diff' && $diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            if ($block_lang eq 'diff' && !$no_diff_fixes) {
                maybe_relabel_non_diff_diff_block();
            }
            if ($block_lang eq 'diff') {
                maybe_report_diff_contamination_on_block_close($i);
                reset_diff_block_contamination_state();
            }
            $cnt_blocks_closed++;
            dbg("fence-close: input_idx=$i lang='$block_lang'");
            push @{$out}, '```';
            $in_block = 0;
            $block_lang = '';
            $block_started_malformed = 0;
            $diff_have_headers = 0;
            $diff_missing_headers_warned = 0;
            $diff_in_hunk = 0;
        }
        $i++;
        next LINE;
    }
    # Malformed close: `</pre>
    if ($in_block && is_malformed_pre_close($line)) {
        $cnt_malformed_pre_close_seen++;
        dbg("malformed-close: saw `</pre> inside block lang='$block_lang' at input_idx=$i");
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
            $cnt_malformed_pre_close_ignored++;
            dbg("malformed-close: ignored premature `</pre> inside lang='$block_lang' at input_idx=$i");
            $i++;
            next LINE;
        }

        if ($block_lang eq 'diff' && $diff_in_hunk) {
            finalize_current_diff_hunk_header();
            $diff_in_hunk = 0;
        }
        if ($block_lang eq 'diff' && !$no_diff_fixes) {
            maybe_relabel_non_diff_diff_block();
        }
        if ($block_lang eq 'diff') {
            maybe_report_diff_contamination_on_block_close($i);
            reset_diff_block_contamination_state();
        }
        $cnt_blocks_closed++;
        dbg("malformed-close: closing block lang='$block_lang' at input_idx=$i");
        push @{$out}, '```';
        $in_block = 0;
        $block_lang = '';
        $block_open_out_idx = -1;
        $block_started_malformed = 0;
        $diff_have_headers = 0;
        $diff_in_hunk = 0;
        $i++;
        next LINE;
    }


    # Malformed opener: <code>
    my $code_rest = parse_code_tag_opener($line);
    if (defined $code_rest) {
        $cnt_malformed_code_tag_openers++;
        dbg("malformed-open: <code> at input_idx=$i");
        my string $open_line = '```';
        if ($markdownlint) {
            $open_line = '```text';
        }
        push @{$out}, $open_line;
        $block_open_out_idx = scalar(@{$out}) - 1;
        $in_block = 1;
        $block_lang = '';
        if ($markdownlint) {
            $block_lang = 'text';
        }
        $block_started_malformed = 1;
        $cnt_blocks_opened++;
        $diff_have_headers = 0;
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
        $cnt_malformed_lang_openers++;
        my string $lang = $parsed[0];
        my string $rest = $parsed[1];
        dbg("malformed-open: lang='$lang' at input_idx=$i");

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
                $cnt_unwrapped_less_markdown_blocks++;
                dbg("unwrap: lang='$lang' payload_lines=" . scalar(@{$payload}) . " at input_idx=$i");
                foreach my $pl (@{$payload}) {
                    my string $out_line = $pl;
                    push @{$out}, $out_line;
                }

                # Skip past the malformed closer line.
                $i = $k + 1;
                next LINE;
            }
        }

        push @{$out}, "```$lang";
        $block_open_out_idx = scalar(@{$out}) - 1;
        $in_block = 1;
        $block_lang = $lang;
        $block_started_malformed = 1;
        $cnt_blocks_opened++;
        $cnt_blocks_opened_diff++ if $block_lang eq 'diff';

        if ($block_lang eq 'diff') {
            reset_diff_block_relabel_state();
            reset_diff_block_contamination_state();
            $diff_have_headers = 0;
            $diff_missing_headers_warned = 0;
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

    # Outside any block, scrub stray </pre> tokens that can re-trigger HTML rendering.
    # Exporters sometimes leak these outside fenced blocks; TierA forbids literal </pre>
    # outside fences. If the line is just a standalone close tag (often wrapped in 0-3
    # backticks), drop it. Otherwise, escape it to plain text.
    if (!$in_block && defined $line && ($line =~ /<\/pre>/)) {
        my string $t = $line;
        $t =~ s/^\s+//;
        $t =~ s/\s+\z//;

        if ($t =~ /^`{0,3}<\/pre>\z/) {
            dbg('scrub: dropped stray </pre> outside block at input_idx=' . $i);
            $i++;
            next LINE;
        }

        my integer $n = ($line =~ s/<\/pre>/&lt;\/pre&gt;/g);
        if ($n) {
            dbg('scrub: escaped </pre> outside block count=' . $n . ' at input_idx=' . $i);
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
        note_diff_block_line_for_relabel($line);

        if ($line =~ /^(?:diff --git\b|index\s+|new\s+file\s+mode\b|deleted\s+file\s+mode\b|rename\s+from\b|rename\s+to\b|similarity\s+index\b|dissimilarity\s+index\b|Binary\s+files\b|GIT\s+binary\s+patch\b)/) {
            $diff_saw_git_header = 1;
            $cnt_diff_git_header_lines++;
            push @{$out}, $line;
            $i++;
            next LINE;
        }
        # If a bare "@@" line appears inside a hunk, treat it as contaminated payload
        # rather than dropping it (data loss).
        if ($diff_in_hunk && $line =~ /^@@\s*\z/) {
            my string $out_line = (' ' . $line);
            $cnt_diff_hunk_lines_prefixed_space++;
            if ($tierD_enabled) {
                $cnt_diff_tierD_allowed_rewrites++;
            }
            if ($policy_contamination eq 'flag') {
                $cnt_diff_contam_hunk_nonprefix_lines++;
                mark_diff_contaminated($i);
            }
            count_hunk_line($out_line);
            push @{$out}, $out_line;
            $i++;
            next LINE;
        }

        if ($line =~ /^(---|\+\+\+)\s+(.*)\z/) {
            $diff_saw_header_minus = 1 if $1 eq '---';
            $diff_saw_header_plus  = 1 if $1 eq '+++';
            $cnt_diff_header_lines++;
            dbg("diff-header: kind=$1 at input_idx=$i");
            if ($diff_in_hunk) {
                finalize_current_diff_hunk_header();
                $diff_in_hunk = 0;
            }
            my string $kind = $1;
            my string $rest = $2;
            my string $norm = normalize_diff_header_line($kind, $rest);

            my string $out_line = $line;
            if ($policy_path_header ne 'preserve') {
                $out_line = $norm;
            }

            if ($tierD_enabled) {
                if ($out_line ne $line) {
                    $cnt_diff_tierD_allowed_rewrites++;
                }
            }

            push @{$out}, $out_line;
            $diff_have_headers = 1;
            $diff_in_hunk = 0;
            $i++;
            next LINE;
        }

        if (is_proper_hunk_header($line)) {
            $diff_saw_hunk_header = 1;
            $cnt_diff_hunk_headers++;
            dbg("diff-hunk: header at input_idx=$i line='" . $line . "'");

            if (!$diff_have_headers) {
                my string $inferred_path = infer_single_file_path_for_diff_context($i, $lines, $no_unescape_backticks);
                if ($inferred_path ne "") {
                    my string $minus = normalize_diff_header_line("---", $inferred_path);
                    my string $plus  = normalize_diff_header_line("+++", $inferred_path);

                    $diff_saw_header_minus = 1;
                    $diff_saw_header_plus  = 1;

                    $cnt_diff_header_lines += 2;
                    push @{$out}, $minus;
                    push @{$out}, $plus;

                    $diff_have_headers = 1;
                    dbg("diff-header: inferred headers before first hunk");
                }
            }


            if (!$diff_have_headers) {
                if (!$diff_missing_headers_warned) {
                    $cnt_diff_missing_headers_before_hunk++;
                    $diff_missing_headers_warned = 1;
                    dbg('diff-contam: missing headers before first hunk at input_idx=' . $i
                        . ' (policy=' . $policy_contamination . ', not inserting defaults)');
                    $cnt_diff_contam_missing_headers_before_hunk++;
                    $diff_contam_curr_missing_headers_before_hunk++;
                    mark_diff_contaminated($i);
                }
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
                $cnt_diff_hunk_lines_empty_to_space++;
                if ($policy_contamination eq 'flag') {
                    $cnt_diff_contam_hunk_empty_lines++;
                    $diff_contam_curr_hunk_empty_lines++;
                    mark_diff_contaminated($i);
                    if (!$diff_contam_warned_hunk_empty) {
                        $diff_contam_warned_hunk_empty = 1;
                        dbg('diff-contam: empty line inside hunk at input_idx=' . $i);
                    }
                }
                if ($tierD_enabled) {
                    $cnt_diff_tierD_allowed_rewrites++;
                }
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }

            if ($line !~ /^[ \+\-\\]/) {
                my string $out_line = (' ' . $line);
                $cnt_diff_hunk_lines_prefixed_space++;
                if ($policy_contamination eq 'flag') {
                    $cnt_diff_contam_hunk_nonprefix_lines++;
                    $diff_contam_curr_hunk_nonprefix_lines++;
                    mark_diff_contaminated($i);
                    if (!$diff_contam_warned_hunk_nonprefix) {
                        $diff_contam_warned_hunk_nonprefix = 1;
                        my string $snippet = $line;
                        $snippet =~ s/\t/\\t/g;
                        $snippet = substr($snippet, 0, 120) if length($snippet) > 120;
                        dbg('diff-contam: non-diff line inside hunk at input_idx=' . $i
                            . ' line=' . $snippet);
                    }
                }
                if ($tierD_enabled) {
                    $cnt_diff_tierD_allowed_rewrites++;
                }
                count_hunk_line($out_line);
                push @{$out}, $out_line;
                $i++;
                next LINE;
            }

            $cnt_diff_hunk_lines_passthrough++;
            count_hunk_line($line);
            push @{$out}, $line;
            $i++;
            next LINE;
        }

        
        # Drop stray "@@" separator lines outside hunks.
        if ($line =~ /^@@\s*\z/) {
            if ($policy_contamination eq 'flag') {
                mark_diff_contaminated($i);
            }
            $cnt_diff_contam_dropped_bare_atat++;
            $diff_contam_curr_dropped_bare_atat++;

            if ($tierD_enabled) {
                $cnt_diff_tierD_allowed_rewrites++;
                $cnt_diff_tierD_dropped_bare_atat++;
            }

            $i++;
            next LINE;
        }

        
        if ($policy_contamination eq 'flag') {
            my boolean $ok = 0;

            $ok = 1 if $line =~ /^diff --git\b/;
            $ok = 1 if $line =~ /^index\s+[0-9a-f]+(?:\.\.[0-9a-f]+)?\b/;
            $ok = 1 if $line =~ /^(?:---|\+\+\+)\s+/;
            $ok = 1 if $line =~ /^(?:new file mode|deleted file mode|old mode|new mode|similarity index|rename from|rename to|copy from|copy to)\b/;
            $ok = 1 if $line =~ /^Binary files\b/;
            $ok = 1 if $line =~ /^GIT binary patch\b/;
            $ok = 1 if $line =~ /^@@\s/;
            $ok = 1 if $line =~ /^\\ No newline at end of file/;

            if (!$ok) {
                $cnt_diff_contam_lines_outside_hunk++;
                $diff_contam_curr_lines_outside_hunk++;
                mark_diff_contaminated($i);
                if (!$diff_contam_warned_outside_hunk) {
                    $diff_contam_warned_outside_hunk = 1;
                    my string $snippet = $line;
                    $snippet =~ s/\t/\\t/g;
                    $snippet = substr($snippet, 0, 120) if length($snippet) > 120;
                    $diff_contam_curr_first_outside_hunk_input_idx = $i;
                    $diff_contam_curr_first_outside_hunk_line = $snippet;
                }
            }
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
    dbg("eof: closing unterminated block lang='$block_lang'");
    $cnt_blocks_closed++;
    if ($block_lang eq 'diff' && $diff_in_hunk) {
        finalize_current_diff_hunk_header();
        $diff_in_hunk = 0;
    }
    if ($block_lang eq 'diff' && !$no_diff_fixes) {
        maybe_relabel_non_diff_diff_block();
    }
    if ($block_lang eq 'diff') {
        my integer $close_input_idx = scalar(@{$lines}) - 1;
        maybe_report_diff_contamination_on_block_close($close_input_idx);
        reset_diff_block_contamination_state();
    }
    push @{$out}, '```';
}

if ($markdownlint) {
    my boolean $ml_in_block = 0;
    my string $ml_lang = '';

    for (my integer $ml_i = 0; $ml_i < scalar(@{$out}); $ml_i++) {
        my string $ml_line = $out->[$ml_i];

        my boolean $is_fence = 0;
        my string $f_lang = '';
        ($is_fence, $f_lang) = is_triple_fence_line($ml_line);
        if ($is_fence) {
            if (!$ml_in_block) {
                $ml_in_block = 1;
                $ml_lang = (defined($f_lang) ? $f_lang : '');
                $ml_lang = '' if (!defined $ml_lang);
            } else {
                $ml_in_block = 0;
                $ml_lang = '';
            }
            next;
        }

        # Do not touch diff payload lines - trailing whitespace can be meaningful.
        if ($ml_in_block && $ml_lang eq 'diff') {
            next;
        }

        my string $orig = $ml_line;

        # MD009: allow only 0 or 2 trailing spaces.
        # - whitespace-only lines become truly blank
        # - 1 trailing whitespace char is removed
        # - 2+ trailing whitespace chars become exactly 2 spaces
        if ($ml_line =~ /^\s+\z/) {
            $ml_line = '';
        } elsif ($ml_line =~ /^(.*?)([ \t]+)\z/s) {
            my string $body = $1;
            my string $trail = $2;
            if (length($trail) == 1) {
                $ml_line = $body;
            } else {
                $ml_line = $body . '  ';
            }
        }

        if ($ml_line ne $orig) {
            $out->[$ml_i] = $ml_line;
            $cnt_markdownlint_md009_fixed_lines++;
        }
    }

    dbg('markdownlint: md009_fixed_lines=' . $cnt_markdownlint_md009_fixed_lines);
}

dbg('summary: unescaped_backticks=' . $cnt_unescaped_backticks
    . ' blocks_opened=' . $cnt_blocks_opened
    . ' blocks_closed=' . $cnt_blocks_closed
    . ' diff_blocks_opened=' . $cnt_blocks_opened_diff
    . ' diff_relabel_console=' . $cnt_blocks_relabel_diff_to_console
    . ' diff_relabel_bash=' . $cnt_blocks_relabel_diff_to_bash
    . ' diff_relabel_sh=' . $cnt_blocks_relabel_diff_to_sh
    . ' diff_relabel_uncertain=' . $cnt_blocks_relabel_diff_uncertain);
dbg('summary: spill_close_on_new_opener=' . $cnt_spill_close_on_new_opener
    . ' close_on_blank_after_malformed=' . $cnt_close_on_blank_after_malformed
    . ' malformed_pre_close_seen=' . $cnt_malformed_pre_close_seen
    . ' malformed_pre_close_ignored=' . $cnt_malformed_pre_close_ignored
    . ' malformed_code_tag_openers=' . $cnt_malformed_code_tag_openers
    . ' malformed_lang_openers=' . $cnt_malformed_lang_openers
    . ' unwrapped_less_markdown=' . $cnt_unwrapped_less_markdown_blocks
    . ' unwrapped_html_anchors=' . $cnt_unwrapped_html_anchors);
dbg('summary: diff_git_header_lines=' . $cnt_diff_git_header_lines
    . ' diff_header_lines=' . $cnt_diff_header_lines
    . ' diff_hunk_headers=' . $cnt_diff_hunk_headers
    . ' diff_hunk_header_rewrites=' . $cnt_diff_hunk_header_rewrites
    . ' hunk_empty_to_space=' . $cnt_diff_hunk_lines_empty_to_space
    . ' hunk_prefixed_space=' . $cnt_diff_hunk_lines_prefixed_space
    . ' hunk_passthrough=' . $cnt_diff_hunk_lines_passthrough
    . ' missing_headers_before_hunk=' . $cnt_diff_missing_headers_before_hunk
    . ' contam_blocks=' . $cnt_diff_contam_blocks
    . ' contam_outside_hunk=' . $cnt_diff_contam_lines_outside_hunk
    . ' contam_hunk_empty=' . $cnt_diff_contam_hunk_empty_lines
    . ' contam_hunk_nonprefix=' . $cnt_diff_contam_hunk_nonprefix_lines
    . ' contam_dropped_bare_atat=' . $cnt_diff_contam_dropped_bare_atat
    . ' contam_missing_headers_before_hunk=' . $cnt_diff_contam_missing_headers_before_hunk);

my hashref $tier_results = {};

if ($tierA_enabled) {
    my hashref $tierA_r = validate_tierA_output($out);
    my boolean $tierA_pass = 1;
    $tierA_pass = 0 if ($tierA_r->{'unbalanced_fences'} != 0);
    $tierA_pass = 0 if ($tierA_r->{'pre_close'} != 0);
    $tierA_pass = 0 if ($tierA_r->{'diff_markers_outside'} != 0);

    $tier_results->{'A'} = { pass => $tierA_pass, details => $tierA_r };

    dbg('tierA: pass=' . $tierA_pass
        . ' fence_lines=' . $tierA_r->{'fence_lines'}
        . ' unbalanced_fences=' . $tierA_r->{'unbalanced_fences'}
        . ' pre_close=' . $tierA_r->{'pre_close'}
        . ' diff_markers_outside=' . $tierA_r->{'diff_markers_outside'});
}

if ($tierB_enabled) {
    my hashref $tierB_r = validate_tierB_output($out);
    my boolean $tierB_pass = 1;

    $tierB_pass = 0 if ($tierB_r->{'code_tag_openers_outside'} != 0);
    $tierB_pass = 0 if ($tierB_r->{'malformed_lang_openers_outside'} != 0);

    if ($policy_backtick_unescape ne 'off') {
        $tierB_pass = 0 if ($tierB_r->{'backslash_backticks_outside'} != 0);
    }

    if (!$no_diff_fixes) {
        $tierB_pass = 0 if ($tierB_r->{'diff_bare_atat_lines'} != 0);
        $tierB_pass = 0 if ($tierB_r->{'diff_invalid_hunk_lines'} != 0);
    }

    if ($policy_contamination eq 'deny') {
        $tierB_pass = 0 if ($tierB_r->{'diff_missing_headers_before_hunk'} != 0);
    }

    $tier_results->{'B'} = { pass => $tierB_pass, details => $tierB_r };

    dbg('tierB: pass=' . $tierB_pass
        . ' code_tag_openers_outside=' . $tierB_r->{'code_tag_openers_outside'}
        . ' malformed_lang_openers_outside=' . $tierB_r->{'malformed_lang_openers_outside'}
        . ' backslash_backticks_outside=' . $tierB_r->{'backslash_backticks_outside'}
        . ' diff_bare_atat_lines=' . $tierB_r->{'diff_bare_atat_lines'}
        . ' diff_invalid_hunk_lines=' . $tierB_r->{'diff_invalid_hunk_lines'}
        . ' diff_missing_headers_before_hunk=' . $tierB_r->{'diff_missing_headers_before_hunk'});
}


if ($tierD_enabled) {
    my boolean $tierD_pass = 1;
    $tierD_pass = 0 if ($cnt_diff_tierD_forbidden_rewrites != 0);

    $tier_results->{'D'} = {
        pass => $tierD_pass,
        details => {
            allowed_rewrites => $cnt_diff_tierD_allowed_rewrites,
            forbidden_rewrites => $cnt_diff_tierD_forbidden_rewrites,
            dropped_bare_atat => $cnt_diff_tierD_dropped_bare_atat,
        },
    };

    dbg('tierD: pass=' . $tierD_pass
        . ' allowed_rewrites=' . $cnt_diff_tierD_allowed_rewrites
        . ' forbidden_rewrites=' . $cnt_diff_tierD_forbidden_rewrites
        . ' dropped_bare_atat=' . $cnt_diff_tierD_dropped_bare_atat);
}






    my hashref $counters = {
        unescaped_backticks => $cnt_unescaped_backticks,
        blocks_opened => $cnt_blocks_opened,
        blocks_closed => $cnt_blocks_closed,
        diff_blocks_opened => $cnt_blocks_opened_diff,
        diff_relabel_console => $cnt_blocks_relabel_diff_to_console,
        diff_relabel_bash => $cnt_blocks_relabel_diff_to_bash,
        diff_relabel_sh => $cnt_blocks_relabel_diff_to_sh,
        diff_relabel_uncertain => $cnt_blocks_relabel_diff_uncertain,
        spill_close_on_new_opener => $cnt_spill_close_on_new_opener,
        close_on_blank_after_malformed => $cnt_close_on_blank_after_malformed,
        malformed_pre_close_seen => $cnt_malformed_pre_close_seen,
        malformed_pre_close_ignored => $cnt_malformed_pre_close_ignored,
        malformed_code_tag_openers => $cnt_malformed_code_tag_openers,
        malformed_lang_openers => $cnt_malformed_lang_openers,
        unwrapped_less_markdown => $cnt_unwrapped_less_markdown_blocks,
        unwrapped_html_anchors => $cnt_unwrapped_html_anchors,
        diff_git_header_lines => $cnt_diff_git_header_lines,
        diff_header_lines => $cnt_diff_header_lines,
        diff_hunk_headers => $cnt_diff_hunk_headers,
        diff_hunk_header_rewrites => $cnt_diff_hunk_header_rewrites,
        hunk_empty_to_space => $cnt_diff_hunk_lines_empty_to_space,
        hunk_prefixed_space => $cnt_diff_hunk_lines_prefixed_space,
        hunk_passthrough => $cnt_diff_hunk_lines_passthrough,
        diff_missing_headers_before_hunk => $cnt_diff_missing_headers_before_hunk,
        contam_blocks => $cnt_diff_contam_blocks,
        contam_outside_hunk => $cnt_diff_contam_lines_outside_hunk,
        contam_hunk_empty => $cnt_diff_contam_hunk_empty_lines,
        contam_hunk_nonprefix => $cnt_diff_contam_hunk_nonprefix_lines,
        contam_missing_headers_before_hunk => $cnt_diff_contam_missing_headers_before_hunk,
        contam_dropped_bare_atat => $cnt_diff_contam_dropped_bare_atat,
        tierD_allowed_rewrites => $cnt_diff_tierD_allowed_rewrites,
        tierD_forbidden_rewrites => $cnt_diff_tierD_forbidden_rewrites,
        tierD_dropped_bare_atat => $cnt_diff_tierD_dropped_bare_atat,
    };

    my arrayref $debug_run_lines = [];
    if ($debug) {
        my integer $dbg_end_idx = scalar(@{$dbg_lines}) - 1;
        if ($dbg_end_idx >= $dbg_start_idx) {
            $debug_run_lines = [ @{$dbg_lines}[$dbg_start_idx .. $dbg_end_idx] ];
        }
    }

    return {
        fixed_lines => $out,
        tiers => $tier_results,
        counters => $counters,
        debug_lines => $debug_run_lines,
    };
}

my integer $ok_count = 0;
my integer $skip_count = 0;
my integer $fail_count = 0;

for my $path (@{$input_paths}) {
    if (!is_supported_markdown_filename($path)) {
        print STDERR "Unsupported input file suffix (only .md .markdown .mdown .mkd .mkdn): '$path'\n";
        $fail_count++;
        next;
    }
    if (!$clean && !$double_fix && is_already_fixed_input_filename($path)) {
        my string $msg = "SKIP already fixed input '$path' (use --double-fix to allow)";
        print STDERR $msg . "\n";
        dbg($msg);
        $skip_count++;
        next;
    }

    if ($clean && !-e $path) {
        print STDERR "Input path does not exist for --clean: '$path'\n";
        $fail_count++;
        next;
    }

    my string $planned_out_path = '';
    if ($clean && is_already_fixed_input_filename($path)) {
        # Allow directly cleaning a previously generated __fixed.<suffix> file when passed explicitly.
        $planned_out_path = $path;
    } else {
        $planned_out_path = compute_fixed_output_path($path);
    }
    dbg("output: planned fixed path='" . $planned_out_path . "'");

    if ($planned_out_path eq '') {
        print STDERR "Failed to compute output filename for input '$path'\n";
        $fail_count++;
        next;
    }

    my boolean $out_exists = (-e $planned_out_path ? 1 : 0);
    my boolean $blocked_out = ($out_exists && !$overwrite ? 1 : 0);

    my string $planned_dbg_path = '';
    my boolean $dbg_exists = 0;
    my boolean $blocked_dbg = 0;

    if ($debug || $clean) {
        $planned_dbg_path = $planned_out_path;
        $planned_dbg_path =~ s/\.(md|markdown|mdown|mkd|mkdn)\z/.debug/;
        if ($planned_dbg_path eq $planned_out_path) {
            $planned_dbg_path = $planned_out_path . '.debug';
        }
        $dbg_exists = (-e $planned_dbg_path ? 1 : 0);
        $blocked_dbg = ($dbg_exists && !$overwrite ? 1 : 0);
        if ($debug && !$clean) {
            $dbg_lines = [];
            dbg("file: input='$path' output='$planned_out_path' debug='$planned_dbg_path'");
        }
    }

    if ($clean) {
        my string $out_act = 'MISSING';
        my string $dbg_act = 'MISSING';

        if (-e $planned_out_path) {
            if (!unlink $planned_out_path) {
                print STDERR "CLEAN FAILED to delete output '$planned_out_path': $!\n";
                $fail_count++;
                next;
            }
            $out_act = 'DELETED';
        }

        if ($planned_dbg_path ne '' && -e $planned_dbg_path) {
            if (!unlink $planned_dbg_path) {
                print STDERR "CLEAN FAILED to delete debug output '$planned_dbg_path': $!\n";
                $fail_count++;
                next;
            }
            $dbg_act = 'DELETED';
        }

        print STDERR "CLEAN output=$out_act '$planned_out_path' debug=$dbg_act '$planned_dbg_path'\n";
        $ok_count++;
        next;
    }

    if ($blocked_out && !$dry_run) {
        print STDERR "Refusing to overwrite existing output '$planned_out_path' (use --overwrite)\n";
        $fail_count++;
        next;
    }

    if ($blocked_dbg && !$dry_run) {
        print STDERR "Refusing to overwrite existing debug output '$planned_dbg_path' (use --overwrite)\n";
        $fail_count++;
        next;
    }

    my $in_fh;
    if (!open($in_fh, '<', $path)) {
        print STDERR "Failed to open input file '$path': $!\n";
        $fail_count++;
        next;
    }
    dbg("input: opened file path='$path'");

    my arrayref $raw_lines = [ <$in_fh> ];
    close($in_fh);

    dbg("input: raw lines read=" . scalar(@{$raw_lines}));

    # Strip line endings for easier processing; we will add "\n" on output.
    my arrayref $this_lines = [];
    for my $s (@{$raw_lines}) {
        my string $line = $s;
        $line =~ s/\r\n/\n/g;
        $line =~ s/\r\z//;
        $line =~ s/\n\z//;
        push @{$this_lines}, $line;
    }

    my hashref $result = run_fix_pipeline_on_lines($this_lines);
    my arrayref $out_lines = $result->{'fixed_lines'};

    if ($markdownlint) {
        if (!(defined $out_lines->[0] && $out_lines->[0] =~ /^#\s+/)) {
            my string $title = $planned_out_path;
            $title =~ s#.*/##;
            $title =~ s/\.(md|markdown|mdown|mkd|mkdn)\z//;
            $title =~ s/__fixed\z//;
            unshift @{$out_lines}, '# ' . $title, '';
            $cnt_markdownlint_md041_inserted++;
            dbg("markdownlint: md041_inserted_h1 title='$title'");
        }


        # MD048: code fence style - normalize tilde fences (~~~) to backtick fences (```).
        # Also ensure any backtick-fence-like lines inside a converted block do not terminate it
        # by indenting them to 4+ leading spaces.
        my integer $md048_converted = 0;
        my arrayref $md048_lines = [];
        my boolean $md048_in_tilde = 0;
        my string $md048_open_prefix = '';
        my string $md048_open_indent = '';

        for (my integer $md048_i = 0; $md048_i < scalar(@{$out_lines}); $md048_i++) {
            my string $md048_line = $out_lines->[$md048_i];

            if (!$md048_in_tilde) {
                if ($md048_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3})~~~([A-Za-z0-9_+\-]+)?\s*\z/s) {
                    my string $md048_prefix = $1;
                    my string $md048_indent = $2;
                    my string $md048_lang = $3;
                    $md048_lang = '' if !defined $md048_lang;
                    $md048_lang =~ s/\s+\z//s;
                    $md048_lang =~ s/^\s+//s;
                    $md048_lang = 'text' if $md048_lang eq '';

                    push @{$md048_lines}, $md048_prefix . $md048_indent . '```' . $md048_lang;
                    $md048_in_tilde = 1;
                    $md048_open_prefix = $md048_prefix;
                    $md048_open_indent = $md048_indent;
                    $md048_converted++;
                    next;
                }

                push @{$md048_lines}, $md048_line;
                next;
            }

            # Inside a tilde-fenced block we are converting to backticks.
            if ($md048_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3})~~~\s*\z/s) {
                my string $md048_prefix = $1;
                my string $md048_indent = $2;

                if ($md048_prefix eq $md048_open_prefix and $md048_indent eq $md048_open_indent) {
                    push @{$md048_lines}, $md048_open_prefix . $md048_open_indent . '```';
                    $md048_in_tilde = 0;
                    $md048_open_prefix = '';
                    $md048_open_indent = '';
                    $md048_converted++;
                    next;
                }
            }

            # Prevent accidental termination after conversion: a line like ``` or ```perl
            # inside the block must be treated as literal payload, not as a closing fence.
            if ($md048_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3}```.*)\z/s) {
                my string $md048_prefix = $1;
                my string $md048_rest = $2;
                push @{$md048_lines}, $md048_prefix . '    ' . $md048_rest;
                next;
            }

            push @{$md048_lines}, $md048_line;
        }

        if ($md048_converted > 0) {
            $out_lines = $md048_lines;
            $cnt_markdownlint_md048_converted_tilde_fences += $md048_converted;
            dbg('markdownlint: md048_converted_tilde_fences=' . $md048_converted);
        }


        # MD040: fenced-code-language. Ensure fenced code blocks have a language specified.
        # This targets indented and blockquoted fences too.
        # Also drop stray bare fences like "```" when they are immediately followed by "```lang" with the same
        # blockquote-prefix/indent/marker. Those are wrapper artifacts from UI export and trigger MD040.
        my integer $md040_added = 0;
        my integer $md040_dropped = 0;
        my arrayref $md040_lines = [];
        my boolean $md040_in_fence = 0;
        my string $md040_fence_prefix = '';
        my string $md040_fence_indent = '';
        my string $md040_fence_marker = '';

        for (my integer $md040_i = 0; $md040_i < scalar(@{$out_lines}); $md040_i++) {
            my string $md040_line = $out_lines->[$md040_i];

            if ($md040_line =~ /^(\s*(?:>\s*)*)([ 	]{0,12})(```|~~~)(?:\s*([A-Za-z0-9_+\-]+))?\s*\z/s) {
                my string $md040_prefix = $1;
                my string $md040_indent = $2;
                my string $md040_marker = $3;
                my string $md040_lang = $4;
                $md040_lang = '' if !defined $md040_lang;

                if (!$md040_in_fence) {
                    if ($md040_lang eq '') {
                        my boolean $md040_drop = 0;
                        my integer $md040_k = $md040_i + 1;

                        while ($md040_k < scalar(@{$out_lines})) {
                            my string $md040_next = $out_lines->[$md040_k];
                            last if ($md040_next !~ /^\s*\z/s and $md040_next !~ /^\s*(?:>\s*)+\z/s);
                            $md040_k++;
                        }

                        if ($md040_k < scalar(@{$out_lines})) {
                            my string $md040_next = $out_lines->[$md040_k];
                            if ($md040_next =~ /^(\s*(?:>\s*)*)([ 	]{0,12})(```|~~~)\s*([A-Za-z0-9_+\-]+)\s*\z/s) {
                                my string $md040_next_prefix = $1;
                                my string $md040_next_indent = $2;
                                my string $md040_next_marker = $3;
                                my string $md040_next_lang = $4;
                                if ($md040_next_lang ne ''
                                    and $md040_next_prefix eq $md040_prefix
                                    and $md040_next_indent eq $md040_indent
                                    and $md040_next_marker eq $md040_marker) {
                                    $md040_drop = 1;
                                }
                            }
                        }

                        if ($md040_drop) {
                            $md040_dropped++;
                            next;
                        }

                        $md040_in_fence = 1;
                        $md040_fence_prefix = $md040_prefix;
                        $md040_fence_indent = $md040_indent;
                        $md040_fence_marker = $md040_marker;

                        push @{$md040_lines}, $md040_prefix . $md040_indent . $md040_marker . 'text';
                        $md040_added++;
                        next;
                    }

                    $md040_in_fence = 1;
                    $md040_fence_prefix = $md040_prefix;
                    $md040_fence_indent = $md040_indent;
                    $md040_fence_marker = $md040_marker;

                    push @{$md040_lines}, $md040_line;
                    next;
                }

                if ($md040_lang eq '' and $md040_prefix eq $md040_fence_prefix and $md040_indent eq $md040_fence_indent and $md040_marker eq $md040_fence_marker) {
                    $md040_in_fence = 0;
                    $md040_fence_prefix = '';
                    $md040_fence_indent = '';
                    $md040_fence_marker = '';

                    push @{$md040_lines}, $md040_line;
                    next;
                }

                push @{$md040_lines}, $md040_line;
                next;
            }

            push @{$md040_lines}, $md040_line;
        }

        if ($md040_added > 0 or $md040_dropped > 0) {
            $out_lines = $md040_lines;
            $cnt_markdownlint_md040_defaulted_fence_lang += $md040_added;
            $cnt_markdownlint_md040_removed_stray_fences += $md040_dropped;
            dbg('markdownlint: md040_defaulted_fence_lang=' . $md040_added);
            dbg('markdownlint: md040_removed_stray_fences=' . $md040_dropped);
        }


        # MD040: remove stray wrapper fences that appear at the start of a speaker block.
        # Pattern: a speaker header (e.g. **ChatGPT**:), optional blank lines, a bare fence (``` or ~~~),
        # then a fenced opener with language (```diff, ```perl, etc). Drop the bare fence.
        my integer $md040_speaker_removed = 0;
        my arrayref $md040_speaker_lines = [];
        my integer $md040_s_i = 0;

        while ($md040_s_i < scalar(@{$out_lines})) {
            my string $md040_s_line = $out_lines->[$md040_s_i];

            if ($md040_s_line =~ /^\*\*(?:You|ChatGPT)\*\*:\s*\z/s) {
                push @{$md040_speaker_lines}, $md040_s_line;
                $md040_s_i++;

                my integer $md040_s_j = $md040_s_i;

                while ($md040_s_j < scalar(@{$out_lines})) {
                    my string $md040_s_next = $out_lines->[$md040_s_j];
                    last if ($md040_s_next !~ /^\s*\z/s and $md040_s_next !~ /^\s*(?:>\s*)+\z/s);
                    push @{$md040_speaker_lines}, $md040_s_next;
                    $md040_s_j++;
                }

                if ($md040_s_j < scalar(@{$out_lines})) {
                    my string $md040_s_first = $out_lines->[$md040_s_j];

                    if ($md040_s_first =~ /^(\s*(?:>\s*)*)([ 	]{0,12})(```|~~~)\s*\z/s) {
                        my string $md040_s_prefix = $1;
                        my string $md040_s_indent = $2;
                        my string $md040_s_marker = $3;

                        my integer $md040_s_k = $md040_s_j + 1;

                        while ($md040_s_k < scalar(@{$out_lines})) {
                            my string $md040_s_after = $out_lines->[$md040_s_k];
                            last if ($md040_s_after !~ /^\s*\z/s and $md040_s_after !~ /^\s*(?:>\s*)+\z/s);
                            $md040_s_k++;
                        }

                        if ($md040_s_k < scalar(@{$out_lines})) {
                            my string $md040_s_after = $out_lines->[$md040_s_k];

                            if ($md040_s_after =~ /^(\s*(?:>\s*)*)([ 	]{0,12})(```|~~~)\s*([A-Za-z0-9_+\-]+)\s*\z/s) {
                                my string $md040_s_after_prefix = $1;
                                my string $md040_s_after_indent = $2;
                                my string $md040_s_after_marker = $3;
                                my string $md040_s_after_lang = $4;

                                if ($md040_s_after_lang ne ''
                                    and $md040_s_after_prefix eq $md040_s_prefix
                                    and $md040_s_after_indent eq $md040_s_indent
                                    and $md040_s_after_marker eq $md040_s_marker) {
                                    $md040_speaker_removed++;
                                    $cnt_markdownlint_md040_removed_stray_fences++;
                                    $md040_s_i = $md040_s_j + 1;
                                    next;
                                }
                            }
                        }
                    }
                }

                $md040_s_i = $md040_s_j;
                next;
            }

            push @{$md040_speaker_lines}, $md040_s_line;
            $md040_s_i++;
        }

        if ($md040_speaker_removed > 0) {
            $out_lines = $md040_speaker_lines;
            dbg('markdownlint: md040_removed_stray_speaker_fences=' . $md040_speaker_removed);
        }

        # Repair broken ```diff fences that were prematurely closed (typically by embedded ``` lines).
        # This happens in some chat transcripts where only the first part of a diff appears inside the
        # code block, but the remainder continues as raw + / - diff lines, which then triggers markdownlint.
        my integer $ml_repaired_here = 0;
        my arrayref $ml_repaired_lines = [];
        my integer $ml_r_i = 0;

        while ($ml_r_i < scalar(@{$out_lines})) {
            my string $ml_r_line = $out_lines->[$ml_r_i];

            if ($ml_r_line =~ /^```diff\s*\z/s) {
                my integer $ml_r_open_i = $ml_r_i;
                my integer $ml_r_close_i = -1;
                my integer $ml_r_scan_limit = 2000;

                for (my integer $ml_r_j = $ml_r_i + 1; $ml_r_j < scalar(@{$out_lines}) && ($ml_r_j - $ml_r_i) < $ml_r_scan_limit; $ml_r_j++) {
                    if ($out_lines->[$ml_r_j] =~ /^```\s*\z/s) {
                        $ml_r_close_i = $ml_r_j;
                        last;
                    }
                }

                if ($ml_r_close_i >= 0) {
                    my boolean $ml_r_has_continuation = 0;
                    my integer $ml_r_k = $ml_r_close_i + 1;
                    my integer $ml_r_cont_limit = 40;

                    while ($ml_r_k < scalar(@{$out_lines}) && ($ml_r_k - $ml_r_close_i) <= $ml_r_cont_limit) {
                        my string $ml_r_next = $out_lines->[$ml_r_k];

                        if ($ml_r_next =~ /^\s*\z/s) {
                            $ml_r_k++;
                            next;
                        }

                        if ($ml_r_next =~ /^[+-]/s ||
                            $ml_r_next =~ /^\@\@/s ||
                            $ml_r_next =~ /^---\s+a\//s ||
                            $ml_r_next =~ /^\+\+\+\s+b\//s) {
                            $ml_r_has_continuation = 1;
                        }

                        last;
                    }

                    if ($ml_r_has_continuation) {
                        my integer $ml_r_end_i = -1;
                        my integer $ml_r_seek_limit = 10000;

                        for (my integer $ml_r_m = $ml_r_close_i + 1; $ml_r_m < scalar(@{$out_lines}) && ($ml_r_m - $ml_r_close_i) < $ml_r_seek_limit; $ml_r_m++) {
                            if ($out_lines->[$ml_r_m] =~ /^---\s*\z/s) {
                                my integer $ml_r_n = $ml_r_m + 1;
                                while ($ml_r_n < scalar(@{$out_lines}) && $out_lines->[$ml_r_n] =~ /^\s*\z/s) {
                                    $ml_r_n++;
                                }
                                if ($ml_r_n < scalar(@{$out_lines}) && $out_lines->[$ml_r_n] =~ /^\*\*(?:You|ChatGPT)\*\*:\s*\z/s) {
                                    $ml_r_end_i = $ml_r_m;
                                    last;
                                }
                            }

                            if ($out_lines->[$ml_r_m] =~ /^\*\*(?:You|ChatGPT)\*\*:\s*\z/s) {
                                $ml_r_end_i = $ml_r_m;
                                last;
                            }
                        }

                        if ($ml_r_end_i < 0) {
                            $ml_r_end_i = scalar(@{$out_lines});
                        }

                        push @{$ml_repaired_lines}, '```diff';

                        for (my integer $ml_r_p = $ml_r_open_i + 1; $ml_r_p < $ml_r_end_i; $ml_r_p++) {
                            my string $ml_r_payload = $out_lines->[$ml_r_p];
                            if ($ml_r_payload =~ /^[ \t]{0,3}```/s) {
                                $ml_r_payload = '    ' . $ml_r_payload;
                            }
                            push @{$ml_repaired_lines}, $ml_r_payload;
                        }

                        push @{$ml_repaired_lines}, '```';

                        $ml_repaired_here++;
                        $ml_r_i = $ml_r_end_i;
                        next;
                    }
                }
            }

            push @{$ml_repaired_lines}, $ml_r_line;
            $ml_r_i++;
        }

        if ($ml_repaired_here > 0) {
            $out_lines = $ml_repaired_lines;
            $cnt_markdownlint_repaired_broken_diff_fences += $ml_repaired_here;
            dbg('markdownlint: repaired_broken_diff_fences_added=' . $ml_repaired_here);
        }


        # MD003: heading style. Convert Setext headings to ATX headings (atx).
        my boolean $md003_in_block = 0;

        for (my integer $md003_i = 0; $md003_i + 1 < scalar(@{$out_lines}); $md003_i++) {
            my string $md003_line = $out_lines->[$md003_i];
            my string $md003_next = $out_lines->[$md003_i + 1];

            my boolean $md003_is_fence = 0;
            my string $md003_f_lang = '';
            ($md003_is_fence, $md003_f_lang) = is_triple_fence_line($md003_line);
            if ($md003_is_fence) {
                $md003_in_block = ($md003_in_block ? 0 : 1);
                next;
            }
            next if $md003_in_block;

            my string $md003_indent_s = '';
            if ($md003_line =~ /^(\s*)/s) {
                $md003_indent_s = $1;
            }
            if (length($md003_indent_s) > 3) {
                next;
            }

            my string $md003_text = $md003_line;
            $md003_text =~ s/\A\s+//s;
            $md003_text =~ s/\s+\z//s;
            if ($md003_text eq '') {
                next;
            }

            if ($md003_next =~ /^(\s*)(=+|-+)\s*\z/s) {
                my string $md003_ul_indent_s = $1;
                my string $md003_marks = $2;

                if (length($md003_ul_indent_s) > 3) {
                    next;
                }
                if (length($md003_marks) < 3) {
                    next;
                }

                my string $md003_prefix = '## ';
                if ($md003_marks =~ /=/s) {
                    $md003_prefix = '# ';
                }

                my string $md003_new_line = $md003_prefix . $md003_text;
                if ($md003_new_line ne $md003_line) {
                    $out_lines->[$md003_i] = $md003_new_line;
                }
                $out_lines->[$md003_i + 1] = '';
                $cnt_markdownlint_md003_converted_setext++;
                $md003_i++;
                next;
            }
        }

        dbg('markdownlint: md003_converted_setext=' . $cnt_markdownlint_md003_converted_setext);

        # MD019: no multiple spaces after ATX heading markers.
        my boolean $md019_in_block = 0;

        for (my integer $md019_i = 0; $md019_i < scalar(@{$out_lines}); $md019_i++) {
            my string $md019_line = $out_lines->[$md019_i];

            my boolean $md019_is_fence = 0;
            my string $md019_f_lang = '';
            ($md019_is_fence, $md019_f_lang) = is_triple_fence_line($md019_line);
            if ($md019_is_fence) {
                $md019_in_block = ($md019_in_block ? 0 : 1);
                next;
            }
            next if $md019_in_block;

            if ($md019_line =~ /^(#{1,6})\s{2,}(\S.*)\z/s) {
                my string $md019_hashes = $1;
                my string $md019_rest = $2;
                my string $md019_new_line = $md019_hashes . ' ' . $md019_rest;
                if ($md019_new_line ne $md019_line) {
                    $out_lines->[$md019_i] = $md019_new_line;
                    $cnt_markdownlint_md019_fixed_atx++;
                }
            }
        }

        dbg('markdownlint: md019_fixed_atx=' . $cnt_markdownlint_md019_fixed_atx);

        # MD025: single H1 per document. Demote additional H1 headings to H2.
        my boolean $md025_in_block = 0;
        my integer $md025_seen_h1 = 0;

        for (my integer $md025_i = 0; $md025_i < scalar(@{$out_lines}); $md025_i++) {
            my string $md025_line = $out_lines->[$md025_i];

            my boolean $md025_is_fence = 0;
            my string $md025_f_lang = '';
            ($md025_is_fence, $md025_f_lang) = is_triple_fence_line($md025_line);
            if ($md025_is_fence) {
                $md025_in_block = ($md025_in_block ? 0 : 1);
                next;
            }
            next if $md025_in_block;

            if ($md025_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3})#\s+(\S.*)\z/s) {
                my string $md025_prefix = $1;
                my string $md025_indent = $2;
                my string $md025_rest = $3;

                $md025_seen_h1++;
                if ($md025_seen_h1 > 1) {
                    if ($md025_rest ne '') {
                        my string $md025_new_line = $md025_prefix . $md025_indent . '## ' . $md025_rest;
                        if ($md025_new_line ne $md025_line) {
                            $out_lines->[$md025_i] = $md025_new_line;
                            $cnt_markdownlint_md025_demoted_h1++;
                        }
                    }
                }
            }
        }

        dbg('markdownlint: md025_demoted_h1=' . $cnt_markdownlint_md025_demoted_h1);

        # MD036: emphasis used instead of a heading.
my boolean $md036_in_block = 0;
my string $md036_prev_context = '';

for (my integer $md036_i = 0; $md036_i < scalar(@{$out_lines}); $md036_i++) {
    my string $md036_line = $out_lines->[$md036_i];

    my boolean $md036_is_fence = 0;
    my string $md036_f_lang = '';
    ($md036_is_fence, $md036_f_lang) = is_triple_fence_line($md036_line);
    if ($md036_is_fence) {
        $md036_in_block = ($md036_in_block ? 0 : 1);
        next;
    }
    next if $md036_in_block;

    # Strip orphan emphasis marker lines like '**' that commonly precede quoted excerpts.
    if ($md036_line =~ /^\s*(\*\*|__|\*|_)\s*\z/s) {
        if ($md036_line !~ /^\s*\z/s) {
            $out_lines->[$md036_i] = '';
            $cnt_markdownlint_md036_stripped_orphan++;
        }
        next;
    }

    # If this looks like an emphasized quote line, convert to a blockquote instead of a heading.
    if ($md036_line =~ /^\s*_(.+)_\s*\z/s) {
        my string $md036_inner = $1;

        if (length($md036_inner) >= 40 && $md036_prev_context =~ /(quote|verbatim|excerpt)/i) {
            my string $md036_new_line = '> ' . $md036_inner;
            if ($md036_new_line ne $md036_line) {
                $out_lines->[$md036_i] = $md036_new_line;
                $md036_line = $md036_new_line;
                $cnt_markdownlint_md036_quoted++;
            }
        }
    }

    # Strict: only convert lines that are exactly one bold span with no internal '*' chars.
    if ($md036_line =~ /^\*\*([^*]+?)\*\*\z/s) {
        my string $md036_text = $1;
        $md036_text =~ s/\s+\z//;
        $md036_text =~ s/\A\s+//;

        # Avoid creating headings that end with ':' (would trip MD026 later).
        $md036_text =~ s/:\z//;

        if ($md036_text ne '') {
            my string $md036_new_line = '## ' . $md036_text;
            if ($md036_new_line ne $md036_line) {
                $out_lines->[$md036_i] = $md036_new_line;
                $cnt_markdownlint_md036_converted++;
                $md036_line = $md036_new_line;
            }
        }
    }

    if ($md036_line =~ /\S/s) {
        $md036_prev_context = $md036_line;
    }
}


        dbg('markdownlint: md036_converted=' . $cnt_markdownlint_md036_converted);
        dbg('markdownlint: md036_quoted=' . $cnt_markdownlint_md036_quoted);
        dbg('markdownlint: md036_stripped_orphan=' . $cnt_markdownlint_md036_stripped_orphan);

        # MD001: heading levels should only increment by one level at a time.
        my boolean $md001_in_block = 0;
        my integer $md001_last_level = 0;

        for (my integer $md001_i = 0; $md001_i < scalar(@{$out_lines}); $md001_i++) {
            my string $md001_line = $out_lines->[$md001_i];

            my boolean $md001_is_fence = 0;
            my string $md001_f_lang = '';
            ($md001_is_fence, $md001_f_lang) = is_triple_fence_line($md001_line);
            if ($md001_is_fence) {
                $md001_in_block = ($md001_in_block ? 0 : 1);
                next;
            }
            next if $md001_in_block;

            if ($md001_line =~ /^(#{1,6})\s+(.*)\z/s) {
                my integer $md001_level = length($1);
                my string $md001_rest = $2;

                if ($md001_last_level != 0 && $md001_level > ($md001_last_level + 1)) {
                    my integer $md001_new_level = $md001_last_level + 1;
                    $md001_new_level = 6 if ($md001_new_level > 6);

                    my string $md001_hashes = ('#' x $md001_new_level);
                    my string $md001_new_line = $md001_hashes . ' ' . $md001_rest;

                    if ($md001_new_line ne $md001_line) {
                        $out_lines->[$md001_i] = $md001_new_line;
                        $cnt_markdownlint_md001_adjusted_headings++;
                    }

                    $md001_level = $md001_new_level;
                }

                $md001_last_level = $md001_level;
            }
        }

        dbg('markdownlint: md001_adjusted_headings=' . $cnt_markdownlint_md001_adjusted_headings);

# MD026: trailing punctuation in headings (most often ':' or '.').
my boolean $md026_in_block = 0;

for (my integer $md026_i = 0; $md026_i < scalar(@{$out_lines}); $md026_i++) {
    my string $md026_line = $out_lines->[$md026_i];

    my boolean $md026_is_fence = 0;
    my string $md026_f_lang = '';
    ($md026_is_fence, $md026_f_lang) = is_triple_fence_line($md026_line);
    if ($md026_is_fence) {
        $md026_in_block = ($md026_in_block ? 0 : 1);
        next;
    }
    next if $md026_in_block;

    if ($md026_line =~ /^(#{1,6})\s+(.*?)\s*([:.])\s*\z/s) {
        my string $md026_hashes = $1;
        my string $md026_rest = $2;

        $md026_rest =~ s/\s+\z//;
        $md026_rest =~ s/\A\s+//;

        if ($md026_rest ne '') {
            my string $md026_new_line = $md026_hashes . ' ' . $md026_rest;
            if ($md026_new_line ne $md026_line) {
                $out_lines->[$md026_i] = $md026_new_line;
                $cnt_markdownlint_md026_stripped_heading_punct++;
            }
        }
    }
}

dbg('markdownlint: md026_stripped_heading_punct=' . $cnt_markdownlint_md026_stripped_heading_punct);

        # MD022: headings should be surrounded by blank lines.
        my boolean $md022_in_block = 0;
        my arrayref $md022_new_lines = [];

        for (my integer $md022_i = 0; $md022_i < scalar(@{$out_lines}); $md022_i++) {
            my string $md022_line = $out_lines->[$md022_i];

            my boolean $md022_is_fence = 0;
            my string $md022_f_lang = '';
            ($md022_is_fence, $md022_f_lang) = is_triple_fence_line($md022_line);
            if ($md022_is_fence) {
                push @{$md022_new_lines}, $md022_line;
                $md022_in_block = ($md022_in_block ? 0 : 1);
                next;
            }
            if ($md022_in_block) {
                push @{$md022_new_lines}, $md022_line;
                next;
            }

            if ($md022_line =~ /^(\s*)(#{1,6})\s+(\S.*)\z/s) {
                my string $md022_indent_s = $1;
                my integer $md022_indent = length($md022_indent_s);

                if ($md022_indent <= 3) {
                    if (scalar(@{$md022_new_lines}) > 0) {
                        my string $md022_prev = $md022_new_lines->[-1];
                        my boolean $md022_prev_blank = ($md022_prev =~ /^\s*\z/s ? 1 : 0);
                        if (!$md022_prev_blank) {
                            push @{$md022_new_lines}, '';
                            $cnt_markdownlint_md022_inserted_blank_lines++;
                        }
                    }

                    push @{$md022_new_lines}, $md022_line;

                    if ($md022_i + 1 < scalar(@{$out_lines})) {
                        my string $md022_next = $out_lines->[$md022_i + 1];
                        my boolean $md022_next_blank = ($md022_next =~ /^\s*\z/s ? 1 : 0);
                        if (!$md022_next_blank) {
                            push @{$md022_new_lines}, '';
                            $cnt_markdownlint_md022_inserted_blank_lines++;
                        }
                    }

                    next;
                }
            }

            push @{$md022_new_lines}, $md022_line;
        }

        $out_lines = $md022_new_lines;
        dbg('markdownlint: md022_inserted_blank_lines=' . $cnt_markdownlint_md022_inserted_blank_lines);

        # MD032: lists should be surrounded by blank lines.
        my boolean $md032_in_fence = 0;
        my string $md032_fence_prefix = '';
        my string $md032_fence_indent = '';
        my string $md032_fence_marker = '';
        my arrayref $md032_new_lines = [];

        for (my integer $md032_i = 0; $md032_i < scalar(@{$out_lines}); $md032_i++) {
            my string $md032_line = $out_lines->[$md032_i];

            my boolean $md032_is_fence = 0;
            my string $md032_prefix = '';
            my string $md032_indent = '';
            my string $md032_marker = '';
            my string $md032_lang = '';

            if ($md032_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3})(```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/s) {
                $md032_is_fence = 1;
                $md032_prefix = $1;
                $md032_indent = $2;
                $md032_marker = $3;
                $md032_lang = $4;
                $md032_lang = '' if !defined $md032_lang;
            }

            if ($md032_is_fence) {
                push @{$md032_new_lines}, $md032_line;

                if (!$md032_in_fence) {
                    $md032_in_fence = 1;
                    $md032_fence_prefix = $md032_prefix;
                    $md032_fence_indent = $md032_indent;
                    $md032_fence_marker = $md032_marker;
                }
                else {
                    if ($md032_prefix eq $md032_fence_prefix and $md032_indent eq $md032_fence_indent and $md032_marker eq $md032_fence_marker and $md032_lang eq '') {
                        $md032_in_fence = 0;
                        $md032_fence_prefix = '';
                        $md032_fence_indent = '';
                        $md032_fence_marker = '';
                    }
                }

                next;
            }

            if ($md032_in_fence) {
                push @{$md032_new_lines}, $md032_line;
                next;
            }

            my string $md032_quote_prefix = '';
            my string $md032_body = $md032_line;
            if ($md032_line =~ /^(\s*(?:>\s*)+)(.*)\z/s) {
                $md032_quote_prefix = $1;
                $md032_body = $2;
            }

            my boolean $md032_is_list = 0;
            if ($md032_body =~ /^\s*[-+*](?:\s+\S|\s*\z)/s || $md032_body =~ /^\s*\d+[.)](?:\s+\S|\s*\z)/s) {
                $md032_is_list = 1;
            }

            if ($md032_is_list) {
                my string $md032_blank_line = '';
                if ($md032_quote_prefix ne '') {
                    $md032_blank_line = $md032_quote_prefix;
                    $md032_blank_line =~ s/\s+\z//s;
                }

                # Ensure blank line before list start (unless continuing a list).
                if (scalar(@{$md032_new_lines}) > 0) {
                    my string $md032_prev = $md032_new_lines->[-1];

                    my boolean $md032_prev_blank = 0;
                    if ($md032_prev =~ /^\s*\z/s || $md032_prev =~ /^\s*(?:>\s*)+\z/s) {
                        $md032_prev_blank = 1;
                    }

                    my string $md032_prev_body = $md032_prev;
                    $md032_prev_body =~ s/^\s*(?:>\s*)+//s;

                    my boolean $md032_prev_list = 0;
                    if ($md032_prev_body =~ /^\s*[-+*](?:\s+\S|\s*\z)/s || $md032_prev_body =~ /^\s*\d+[.)](?:\s+\S|\s*\z)/s) {
                        $md032_prev_list = 1;
                    }

                    if (!$md032_prev_blank && !$md032_prev_list) {
                        push @{$md032_new_lines}, $md032_blank_line;
                        $cnt_markdownlint_md032_inserted_blank_lines++;
                    }
                }

                push @{$md032_new_lines}, $md032_line;

                # Ensure blank line after list block (when next line is not blank/list/continuation).
                if ($md032_i + 1 < scalar(@{$out_lines})) {
                    my string $md032_next = $out_lines->[$md032_i + 1];

                    my boolean $md032_next_blank = 0;
                    if ($md032_next =~ /^\s*\z/s || $md032_next =~ /^\s*(?:>\s*)+\z/s) {
                        $md032_next_blank = 1;
                    }

                    my string $md032_next_body = $md032_next;
                    $md032_next_body =~ s/^\s*(?:>\s*)+//s;

                    my boolean $md032_next_list = 0;
                    if ($md032_next_body =~ /^\s*[-+*](?:\s+\S|\s*\z)/s || $md032_next_body =~ /^\s*\d+[.)](?:\s+\S|\s*\z)/s) {
                        $md032_next_list = 1;
                    }

                    my boolean $md032_next_continuation = 0;
                    if (!$md032_next_blank && !$md032_next_list) {
                        if ($md032_next_body =~ /^\s{2,}\S/s) {
                            $md032_next_continuation = 1;
                        }
                    }

                    if (!$md032_next_blank && !$md032_next_list && !$md032_next_continuation) {
                        push @{$md032_new_lines}, $md032_blank_line;
                        $cnt_markdownlint_md032_inserted_blank_lines++;
                    }
                }

                next;
            }

            push @{$md032_new_lines}, $md032_line;
        }

        $out_lines = $md032_new_lines;
        dbg('markdownlint: md032_inserted_blank_lines=' . $cnt_markdownlint_md032_inserted_blank_lines);




        # MD007: unordered list indentation must be multiples of 4.
        my boolean $md007_in_block = 0;

        for (my integer $md007_i = 0; $md007_i < scalar(@{$out_lines}); $md007_i++) {
            my string $md007_line = $out_lines->[$md007_i];
            my string $md007_quote_prefix = '';
            my string $md007_work_line = $md007_line;
            if ($md007_work_line =~ /^(\s*(?:>\s*)+)(.*)\z/s) {
                $md007_quote_prefix = $1;
                $md007_work_line = $2;
            }


            my boolean $md007_is_fence = 0;
            my string $md007_f_lang = '';
            ($md007_is_fence, $md007_f_lang) = is_triple_fence_line($md007_work_line);
            if (!$md007_is_fence) {
                ($md007_is_fence, $md007_f_lang) = is_indented_triple_fence_line($md007_work_line);
            }
            if ($md007_is_fence) {
                $md007_in_block = ($md007_in_block ? 0 : 1);
                next;
            }
            next if $md007_in_block;

            # Collapse accidental double-marker bullets like "- - item" which trigger MD007.
            if ($md007_work_line =~ /^(\s*)([-+*])\s+([-+*])\s+(\S.*)\z/s) {
                my string $md007_indent_s = $1;
                my string $md007_marker = $2;
                my string $md007_rest = $4;

                if ($md007_rest =~ /[A-Za-z0-9`]/s) {
                    my string $md007_new_work_line = $md007_indent_s . $md007_marker . ' ' . $md007_rest;
                    my string $md007_new_full_line = $md007_quote_prefix . $md007_new_work_line;
                    if ($md007_new_full_line ne $md007_line) {
                        $out_lines->[$md007_i] = $md007_new_full_line;
                        $md007_line = $md007_new_full_line;
                        $md007_work_line = $md007_new_work_line;
                        $cnt_markdownlint_md007_collapsed_double_marker++;
                    }
                }
            }

            if ($md007_work_line =~ /^(\s*)([-+*])(\s+)(\S.*)\z/s) {
                my string $md007_indent_s = $1;
                my string $md007_marker = $2;
                my string $md007_space = $3;
                my string $md007_rest = $4;

                my integer $md007_indent = length($md007_indent_s);
                my integer $md007_new_indent = $md007_indent;

                if ($md007_indent > 0 && ($md007_indent % 4) != 0) {
                    $md007_new_indent = $md007_indent + (4 - ($md007_indent % 4));
                }

                if ($md007_new_indent != $md007_indent) {
                    my string $md007_new_work_line = (' ' x $md007_new_indent) . $md007_marker . $md007_space . $md007_rest;
                    my string $md007_new_full_line = $md007_quote_prefix . $md007_new_work_line;
                    if ($md007_new_full_line ne $md007_line) {
                        $out_lines->[$md007_i] = $md007_new_full_line;
                        $cnt_markdownlint_md007_adjusted_items++;
                    }
                }
            }
        }

        dbg('markdownlint: md007_adjusted_items=' . $cnt_markdownlint_md007_adjusted_items);
        dbg('markdownlint: md007_collapsed_double_marker=' . $cnt_markdownlint_md007_collapsed_double_marker);

        # MD004: unordered list markers must use '-'.
        my boolean $md004_in_block = 0;

        for (my integer $md004_i = 0; $md004_i < scalar(@{$out_lines}); $md004_i++) {
            my string $md004_line = $out_lines->[$md004_i];

            my boolean $md004_is_fence = 0;
            my string $md004_f_lang = '';
            ($md004_is_fence, $md004_f_lang) = is_triple_fence_line($md004_line);
            if ($md004_is_fence) {
                $md004_in_block = ($md004_in_block ? 0 : 1);
                next;
            }
            next if $md004_in_block;

            # Avoid touching horizontal-rule candidates like "* * *".
            my string $md004_trim = $md004_line;
            $md004_trim =~ s/\A\s+//s;
            $md004_trim =~ s/\A(?:>\s*)+//s;
            $md004_trim =~ s/\A\s+//s;
            $md004_trim =~ s/\s+\z//s;
            if ($md004_trim =~ /^[*+]\s*[*+]\s*[*+](\s*[*+]\s*)*\z/s) {
                next;
            }

            if ($md004_line =~ /^(\s*(?:>\s*)*)([*+])(\s+)(\S.*)\z/s) {
                my string $md004_prefix_s = $1;
                my string $md004_space = $3;
                my string $md004_rest = $4;

                my string $md004_new_line = $md004_prefix_s . '-' . $md004_space . $md004_rest;
                if ($md004_new_line ne $md004_line) {
                    $out_lines->[$md004_i] = $md004_new_line;
                    $cnt_markdownlint_md004_normalized_markers++;
                }
            }
        }

        dbg('markdownlint: md004_normalized_markers=' . $cnt_markdownlint_md004_normalized_markers);


        # MD030: spaces after list markers (exactly 1).
        my boolean $md030_in_block = 0;

        for (my integer $md030_i = 0; $md030_i < scalar(@{$out_lines}); $md030_i++) {
            my string $md030_line = $out_lines->[$md030_i];

            my boolean $md030_is_fence = 0;
            my string $md030_f_lang = '';
            ($md030_is_fence, $md030_f_lang) = is_triple_fence_line($md030_line);
            if ($md030_is_fence) {
                $md030_in_block = ($md030_in_block ? 0 : 1);
                next;
            }
            next if $md030_in_block;

            # Unordered list marker.
            if ($md030_line =~ /^(\s*)([-+*])\s{2,}(\S.*)\z/s) {
                my string $md030_indent_s = $1;
                my string $md030_marker = $2;
                my string $md030_rest = $3;

                my string $md030_new_line = $md030_indent_s . $md030_marker . ' ' . $md030_rest;
                if ($md030_new_line ne $md030_line) {
                    $out_lines->[$md030_i] = $md030_new_line;
                    $cnt_markdownlint_md030_fixed_spaces++;
                }
                next;
            }

            # Ordered list marker.
            if ($md030_line =~ /^(\s*)(\d+[.)])\s{2,}(\S.*)\z/s) {
                my string $md030_indent_s = $1;
                my string $md030_marker = $2;
                my string $md030_rest = $3;

                my string $md030_new_line = $md030_indent_s . $md030_marker . ' ' . $md030_rest;
                if ($md030_new_line ne $md030_line) {
                    $out_lines->[$md030_i] = $md030_new_line;
                    $cnt_markdownlint_md030_fixed_spaces++;
                }
                next;
            }
        }

        dbg('markdownlint: md030_fixed_spaces=' . $cnt_markdownlint_md030_fixed_spaces);

        # MD029: avoid accidental ordered-list parsing for bullet items that start with "N." or "N)" labels.
        # Example: "- 7. ..." can be parsed as a nested ordered list item and triggers MD029.
        # Escape the delimiter so it renders as text: "7\.".
        my boolean $md029_label_in_fence = 0;
        my string $md029_label_fence_prefix = '';
        my string $md029_label_fence_indent = '';
        my string $md029_label_fence_marker = '';

        for (my integer $md029_label_i = 0; $md029_label_i < scalar(@{$out_lines}); $md029_label_i++) {
            my string $md029_label_line = $out_lines->[$md029_label_i];

            if ($md029_label_line =~ /^(\s*(?:>\s*)*)([ \t]{0,12})(```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/s) {
                my string $md029_label_prefix = $1;
                my string $md029_label_indent = $2;
                my string $md029_label_marker = $3;
                my string $md029_label_lang = $4;
                $md029_label_lang = '' if !defined $md029_label_lang;

                if (!$md029_label_in_fence) {
                    $md029_label_in_fence = 1;
                    $md029_label_fence_prefix = $md029_label_prefix;
                    $md029_label_fence_indent = $md029_label_indent;
                    $md029_label_fence_marker = $md029_label_marker;
                    next;
                }

                if ($md029_label_prefix eq $md029_label_fence_prefix
                    and $md029_label_indent eq $md029_label_fence_indent
                    and $md029_label_marker eq $md029_label_fence_marker
                    and $md029_label_lang eq '') {
                    $md029_label_in_fence = 0;
                    $md029_label_fence_prefix = '';
                    $md029_label_fence_indent = '';
                    $md029_label_fence_marker = '';
                }
                next;
            }

            next if $md029_label_in_fence;

            if ($md029_label_line =~ /^(\s*(?:>\s*)*)(\s*[-+*]\s+)(\d+)([.)])(\s+)(\S.*)\z/s) {
                my string $md029_label_prefix = $1;
                my string $md029_label_bullet = $2;
                my string $md029_label_num = $3;
                my string $md029_label_delim = $4;
                my string $md029_label_space = $5;
                my string $md029_label_rest = $6;

                my string $md029_label_new_line =
                    $md029_label_prefix .
                    $md029_label_bullet .
                    $md029_label_num .
                    '\\' .
                    $md029_label_delim .
                    $md029_label_space .
                    $md029_label_rest;

                if ($md029_label_new_line ne $md029_label_line) {
                    $out_lines->[$md029_label_i] = $md029_label_new_line;
                    $cnt_markdownlint_md029_escaped_bullet_number_labels++;
                }
            }
        }

        dbg('markdownlint: md029_escaped_bullet_number_labels=' . $cnt_markdownlint_md029_escaped_bullet_number_labels);


        # MD029: renumber ordered lists to satisfy 1/2/3 sequential style per indentation level.
        my boolean $md029_renumber_in_block = 0;
        my hashref $md029_renumber_next_by_indent = {};
        my hashref $md029_renumber_active_by_indent = {};

        my string $md029_renumber_active_quote_prefix = '';

        my integer $md029_renumber_warn_emitted = 0;
        my integer $md029_renumber_warn_limit = 25;

        for (my integer $md029_renumber_i = 0; $md029_renumber_i < scalar(@{$out_lines}); $md029_renumber_i++) {
            my string $md029_renumber_line = $out_lines->[$md029_renumber_i];
            my string $md029_renumber_quote_prefix = '';
            my string $md029_renumber_work_line = $md029_renumber_line;

            if ($md029_renumber_work_line =~ /^(\s*(?:>\s*)+)(.*)\z/s) {
                $md029_renumber_quote_prefix = $1;
                $md029_renumber_work_line = $2;
            }

            if ($md029_renumber_quote_prefix ne $md029_renumber_active_quote_prefix) {
                $md029_renumber_next_by_indent = {};
                $md029_renumber_active_by_indent = {};
                $md029_renumber_active_quote_prefix = $md029_renumber_quote_prefix;
            }


            my boolean $md029_renumber_is_fence = 0;
            my string $md029_renumber_f_lang = '';
            ($md029_renumber_is_fence, $md029_renumber_f_lang) = is_triple_fence_line($md029_renumber_line);
            if ($md029_renumber_is_fence) {
                $md029_renumber_in_block = ($md029_renumber_in_block ? 0 : 1);
                $md029_renumber_next_by_indent = {};
                $md029_renumber_active_by_indent = {};
                $md029_renumber_active_quote_prefix = '';
                next;
            }
            next if $md029_renumber_in_block;

            if ($md029_renumber_work_line =~ /^(\s*)(\d+)([.)])(\s+)(\S.*)\z/s) {
                my string $md029_renumber_indent_s = $1;
                my integer $md029_renumber_indent = length($md029_renumber_indent_s);
                my integer $md029_renumber_orig_num = $2 + 0;
                my string $md029_renumber_delim = $3;
                my string $md029_renumber_space = $4;
                my string $md029_renumber_rest = $5;

                foreach my $k (sort { $b <=> $a } keys %{$md029_renumber_active_by_indent}) {
                    if ($k > $md029_renumber_indent) {
                        delete $md029_renumber_active_by_indent->{$k};
                        delete $md029_renumber_next_by_indent->{$k};
                    }
                }

                my integer $md029_renumber_parent_indent = -1;
                foreach my $k (keys %{$md029_renumber_active_by_indent}) {
                    if ($k < $md029_renumber_indent && $k > $md029_renumber_parent_indent) {
                        $md029_renumber_parent_indent = $k;
                    }
                }

                my boolean $md029_renumber_already_active = (exists $md029_renumber_active_by_indent->{$md029_renumber_indent} ? 1 : 0);

                my integer $md029_renumber_expected = 1;
                if ($md029_renumber_already_active) {
                    $md029_renumber_expected = $md029_renumber_next_by_indent->{$md029_renumber_indent};
                }

                my boolean $md029_renumber_warn = 0;
                my string $md029_renumber_warn_reason = '';

                # Warn on mis-indented ordered sublists: our canonical style is 4 spaces per nesting level.
                if ($md029_renumber_indent > 0 && ($md029_renumber_indent % 4) != 0) {
                    $md029_renumber_warn = 1;
                    $md029_renumber_warn_reason = 'ordered list indent is not a multiple of 4';
                }

                # Warn on a likely ordered-sublist restart that is not indented enough (often shows up as a restart to 1).
                if (!$md029_renumber_warn && $md029_renumber_already_active && $md029_renumber_orig_num == 1 && $md029_renumber_expected != 1) {
                    my integer $md029_prev_nonblank_i = $md029_renumber_i - 1;
                    while ($md029_prev_nonblank_i >= 0) {
                        my string $md029_prev_line = $out_lines->[$md029_prev_nonblank_i];
                        my boolean $md029_prev_is_fence = 0;
                        my string $md029_prev_f_lang = '';
                        ($md029_prev_is_fence, $md029_prev_f_lang) = is_triple_fence_line($md029_prev_line);
                        last if $md029_prev_is_fence;
                        last if ($md029_prev_line !~ /^\s*\z/s);
                        $md029_prev_nonblank_i--;
                    }

                    if ($md029_prev_nonblank_i >= 0) {
                        my string $md029_prev_line = $out_lines->[$md029_prev_nonblank_i];
                        my integer $md029_prev_indent = 0;
                        if ($md029_prev_line =~ /^(\s+)/s) {
                            $md029_prev_indent = length($1);
                        }

                        if ($md029_prev_indent > $md029_renumber_indent) {
                            $md029_renumber_warn = 1;
                            $md029_renumber_warn_reason = 'ordered list restarts at 1 after indented content; possible mis-indented ordered sublist';
                        }
                    }
                }

                if ($md029_renumber_warn && $md029_renumber_warn_emitted < $md029_renumber_warn_limit) {
                    $md029_renumber_warn_emitted++;
                    $cnt_markdownlint_md029_warn_possible_misindented_ordered_sublists++;

                    my string $md029_warn_msg =
                        'WARN markdownlint: possible mis-indented ordered sublist: ' .
                        $planned_out_path .
                        ':line ' .
                        ($md029_renumber_i + 1) .
                        ' - ' .
                        $md029_renumber_warn_reason .
                        ' (orig=' .
                        $md029_renumber_orig_num .
                        ' expected=' .
                        $md029_renumber_expected .
                        ' indent=' .
                        $md029_renumber_indent .
                        ')';

                    print STDERR $md029_warn_msg . "\n";
                    dbg($md029_warn_msg);
                }

                # Additional heuristic: warn if the indent increase from a parent ordered list level is suspiciously small.
                if ($md029_renumber_warn_emitted < $md029_renumber_warn_limit && $md029_renumber_parent_indent >= 0) {
                    my integer $md029_renumber_delta = $md029_renumber_indent - $md029_renumber_parent_indent;
                    if ($md029_renumber_delta > 0 && $md029_renumber_delta < 4) {
                        $md029_renumber_warn_emitted++;
                        $cnt_markdownlint_md029_warn_possible_misindented_ordered_sublists++;

                        my string $md029_warn_msg =
                            'WARN markdownlint: possible mis-indented ordered sublist: ' .
                            $planned_out_path .
                            ':line ' .
                            ($md029_renumber_i + 1) .
                            ' - ' .
                            'indent increase from parent is less than 4' .
                            ' (parent_indent=' .
                            $md029_renumber_parent_indent .
                            ' indent=' .
                            $md029_renumber_indent .
                            ')';

                        print STDERR $md029_warn_msg . "\n";
                        dbg($md029_warn_msg);
                    }
                }

                $md029_renumber_active_by_indent->{$md029_renumber_indent} = 1;
                $md029_renumber_next_by_indent->{$md029_renumber_indent} = $md029_renumber_expected + 1;

                my string $md029_renumber_new_line =
                    $md029_renumber_quote_prefix . $md029_renumber_indent_s . $md029_renumber_expected . $md029_renumber_delim . $md029_renumber_space . $md029_renumber_rest;

                if ($md029_renumber_new_line ne $md029_renumber_line) {
                    $out_lines->[$md029_renumber_i] = $md029_renumber_new_line;
                    $cnt_markdownlint_md029_renumbered_ol_items++;
                }
                next;
            }

            if ($md029_renumber_work_line =~ /^(\s*)([-+*])(\s+)(\S.*)\z/s) {
                # Do not terminate an ordered list when we encounter an unordered list at the same indentation.
                # This is a common ChatGPT output bug (sublist not indented enough), and the later
                # md029_nest pass will fix the indentation without corrupting the ordered list numbering.
                next;
            }

            next if ($md029_renumber_work_line =~ /^\s*\z/s);

            my integer $md029_renumber_line_indent = 0;
            if ($md029_renumber_work_line =~ /^(\s+)/s) {
                $md029_renumber_line_indent = length($1);
            }

            foreach my $k (sort { $b <=> $a } keys %{$md029_renumber_active_by_indent}) {
                if ($md029_renumber_line_indent <= $k) {
                    delete $md029_renumber_active_by_indent->{$k};
                    delete $md029_renumber_next_by_indent->{$k};
                }
            }
        }

        dbg('markdownlint: md029_renumbered_ol_items=' . $cnt_markdownlint_md029_renumbered_ol_items);
        dbg('markdownlint: md029_warn_possible_misindented_ordered_sublists=' . $cnt_markdownlint_md029_warn_possible_misindented_ordered_sublists);

        # MD029: keep ordered lists intact by nesting unordered sublists under the most recent ordered list item.
        my boolean $md029_nest_in_block = 0;
        my boolean $md029_nest_ol_active = 0;
        my integer $md029_nest_ol_indent = 0;

        for (my integer $md029_nest_i = 0; $md029_nest_i < scalar(@{$out_lines}); $md029_nest_i++) {
            my string $md029_nest_line = $out_lines->[$md029_nest_i];

            my boolean $md029_nest_is_fence = 0;
            my string $md029_nest_f_lang = '';
            ($md029_nest_is_fence, $md029_nest_f_lang) = is_triple_fence_line($md029_nest_line);
            if ($md029_nest_is_fence) {
                $md029_nest_in_block = ($md029_nest_in_block ? 0 : 1);
                $md029_nest_ol_active = 0;
                next;
            }
            next if $md029_nest_in_block;

            if ($md029_nest_line =~ /^(\s*)(\d+)([.)])(\s+)(\S.*)\z/s) {
                $md029_nest_ol_active = 1;
                $md029_nest_ol_indent = length($1);
                next;
            }

            if ($md029_nest_ol_active) {
                if ($md029_nest_line =~ /^\s*\z/s) {
                    next;
                }

                my integer $md029_nest_line_indent = 0;
                if ($md029_nest_line =~ /^(\s+)/s) {
                    $md029_nest_line_indent = length($1);
                }

                if (($md029_nest_line_indent <= $md029_nest_ol_indent)
                    and ($md029_nest_line !~ /^\s{0,3}[-+*]\s+\S/s)
                    and ($md029_nest_line !~ /^\s{0,3}\d+[.)]\s+\S/s)) {
                    $md029_nest_ol_active = 0;
                    next;
                }

                if ($md029_nest_line =~ /^(\s*)([-+*])(\s+)(\S.*)\z/s) {
                    my string $md029_nest_ul_indent_s = $1;
                    my integer $md029_nest_ul_indent = length($md029_nest_ul_indent_s);

                    if ($md029_nest_ul_indent <= $md029_nest_ol_indent) {
                        my integer $md029_nest_delta = ($md029_nest_ol_indent + 4) - $md029_nest_ul_indent;

                        if ($md029_nest_delta > 0) {
                            my integer $md029_nest_k = $md029_nest_i;
                            while ($md029_nest_k < scalar(@{$out_lines})) {
                                my string $md029_nest_kline = $out_lines->[$md029_nest_k];

                                my boolean $md029_nest_k_is_fence = 0;
                                my string $md029_nest_k_f_lang = '';
                                ($md029_nest_k_is_fence, $md029_nest_k_f_lang) = is_triple_fence_line($md029_nest_kline);
                                last if $md029_nest_k_is_fence;

                                if ($md029_nest_kline =~ /^\s*\z/s) {
                                    $md029_nest_k++;
                                    next;
                                }

                                my integer $md029_nest_k_indent = 0;
                                if ($md029_nest_kline =~ /^(\s+)/s) {
                                    $md029_nest_k_indent = length($1);
                                }

                                last if ($md029_nest_k_indent < $md029_nest_ul_indent);

                                if ($md029_nest_k_indent == $md029_nest_ul_indent) {
                                    last if ($md029_nest_kline !~ /^\s{0,3}[-+*]\s+\S/s);
                                }

                                $out_lines->[$md029_nest_k] = (' ' x $md029_nest_delta) . $md029_nest_kline;
                                $md029_nest_k++;
                            }

                            $cnt_markdownlint_md029_nested_ul_blocks++;
                            $md029_nest_i = $md029_nest_k - 1;
                            next;
                        }
                    }
                }
            }
        }

        dbg('markdownlint: md029_nested_ul_blocks=' . $cnt_markdownlint_md029_nested_ul_blocks);

# MD035: horizontal rule style. Convert '* * *' style to '---'.
my boolean $md035_in_block = 0;

for (my integer $md035_i = 0; $md035_i < scalar(@{$out_lines}); $md035_i++) {
    my string $md035_line = $out_lines->[$md035_i];

    my boolean $md035_is_fence = 0;
    my string $md035_f_lang = '';
    ($md035_is_fence, $md035_f_lang) = is_triple_fence_line($md035_line);
    if ($md035_is_fence) {
        $md035_in_block = ($md035_in_block ? 0 : 1);
        next;
    }
    next if $md035_in_block;

    my string $md035_trim = $md035_line;
    $md035_trim =~ s/\A\s+//s;
    $md035_trim =~ s/\s+\z//s;

    if ($md035_trim =~ /^\*{3,}\z/s || $md035_trim =~ /^\*\s*\*\s*\*(\s*\*\s*)*\z/s) {
        my string $md035_indent = '';
        if ($md035_line =~ /^(\s*)/s) {
            $md035_indent = $1;
        }
        my string $md035_new_line = $md035_indent . '---';
        if ($md035_new_line ne $md035_line) {
            $out_lines->[$md035_i] = $md035_new_line;
            $cnt_markdownlint_md035_normalized_hr++;
        }
    }
}

dbg('markdownlint: md035_normalized_hr=' . $cnt_markdownlint_md035_normalized_hr);

# Fence grep-like output blocks and patch/diff hunks to prevent markdownlint from interpreting them as Markdown.
my boolean $verbatim_fence_in_block = 0;
my string $verbatim_fence_active_lang = '';
my boolean $verbatim_fence_just_closed_diff = 0;
my arrayref $verbatim_fence_new_lines = [];

for (my integer $verbatim_fence_i = 0; $verbatim_fence_i < scalar(@{$out_lines}); $verbatim_fence_i++) {
    my string $verbatim_fence_line = $out_lines->[$verbatim_fence_i];

    my boolean $verbatim_fence_is_fence = 0;
    my string $verbatim_fence_f_lang = '';
    ($verbatim_fence_is_fence, $verbatim_fence_f_lang) = is_triple_fence_line($verbatim_fence_line);
    if ($verbatim_fence_is_fence) {
        push @{$verbatim_fence_new_lines}, $verbatim_fence_line;

        if (!$verbatim_fence_in_block) {
            $verbatim_fence_in_block = 1;
            $verbatim_fence_active_lang = (defined $verbatim_fence_f_lang ? $verbatim_fence_f_lang : '');
            $verbatim_fence_just_closed_diff = 0;
        }
        else {
            $verbatim_fence_in_block = 0;
            $verbatim_fence_just_closed_diff = ($verbatim_fence_active_lang eq 'diff' ? 1 : 0);
            $verbatim_fence_active_lang = '';
        }

        next;
    }
    if ($verbatim_fence_in_block) {
        push @{$verbatim_fence_new_lines}, $verbatim_fence_line;
        next;
    }

    # If we just closed a diff fence, and the subsequent lines contain both '+' and '-' prefixes,
    # it is likely that the diff payload continues in prose form (UI export truncation).
    # Fence the continuation to prevent markdownlint from interpreting diff lines as Markdown.
    if ($verbatim_fence_just_closed_diff) {
        if ($verbatim_fence_line =~ /^\s*\z/s) {
            push @{$verbatim_fence_new_lines}, $verbatim_fence_line;
            next;
        }

        my boolean $verbatim_fence_is_diff_continuation = 0;

        if ($verbatim_fence_line =~ /^[+-]/s) {
            my integer $verbatim_fence_scan_limit = 800;
            my integer $verbatim_fence_plus = 0;
            my integer $verbatim_fence_minus = 0;
            my integer $verbatim_fence_hits = 0;

            my integer $verbatim_fence_scan_k = $verbatim_fence_i;
            while ($verbatim_fence_scan_k < scalar(@{$out_lines}) && ($verbatim_fence_scan_k - $verbatim_fence_i) < $verbatim_fence_scan_limit) {
                my string $verbatim_fence_scan_line = $out_lines->[$verbatim_fence_scan_k];

                last if $verbatim_fence_scan_line =~ /^\*\*(?:You|ChatGPT)\*\*:\s*\z/s;

                my boolean $verbatim_fence_scan_is_fence = 0;
                my string $verbatim_fence_scan_f_lang = '';
                ($verbatim_fence_scan_is_fence, $verbatim_fence_scan_f_lang) = is_triple_fence_line($verbatim_fence_scan_line);
                last if $verbatim_fence_scan_is_fence;

                last if $verbatim_fence_scan_line =~ /^\s*---\s*\z/s;

                if ($verbatim_fence_scan_line =~ /^\+/s) {
                    $verbatim_fence_plus++;
                    $verbatim_fence_hits++;
                }
                elsif ($verbatim_fence_scan_line =~ /^-/s) {
                    $verbatim_fence_minus++;
                    $verbatim_fence_hits++;
                }
                elsif ($verbatim_fence_scan_line =~ /^(?:@@|diff --git|index |---\s|\+\+\+\s)/s) {
                    $verbatim_fence_hits++;
                }

                $verbatim_fence_scan_k++;

                last if ($verbatim_fence_plus > 0 && $verbatim_fence_minus > 0 && $verbatim_fence_hits >= 6 && ($verbatim_fence_scan_k - $verbatim_fence_i) >= 12);
            }

            if ($verbatim_fence_plus > 0 && $verbatim_fence_minus > 0 && $verbatim_fence_hits >= 6) {
                $verbatim_fence_is_diff_continuation = 1;

                push @{$verbatim_fence_new_lines}, '```diff';

                my integer $verbatim_fence_diff_k = $verbatim_fence_i;
                while ($verbatim_fence_diff_k < scalar(@{$out_lines}) && ($verbatim_fence_diff_k - $verbatim_fence_i) < $verbatim_fence_scan_limit) {
                    my string $verbatim_fence_diff_line = $out_lines->[$verbatim_fence_diff_k];

                    last if $verbatim_fence_diff_line =~ /^\*\*(?:You|ChatGPT)\*\*:\s*\z/s;

                    my boolean $verbatim_fence_diff_is_fence = 0;
                    my string $verbatim_fence_diff_f_lang = '';
                    ($verbatim_fence_diff_is_fence, $verbatim_fence_diff_f_lang) = is_triple_fence_line($verbatim_fence_diff_line);
                    last if $verbatim_fence_diff_is_fence;

                    last if $verbatim_fence_diff_line =~ /^\s*---\s*\z/s;

                    push @{$verbatim_fence_new_lines}, $verbatim_fence_diff_line;
                    $verbatim_fence_diff_k++;
                }

                $verbatim_fence_i = $verbatim_fence_diff_k - 1;

                push @{$verbatim_fence_new_lines}, '```';
                $cnt_markdownlint_fenced_diff_continuations++;
            }
        }

        $verbatim_fence_just_closed_diff = 0;

        if ($verbatim_fence_is_diff_continuation) {
            next;
        }
    }

    # Patch hunks in some chat transcripts are shown with "***NNN,MMM****" and "---  end of patch  ---" lines.
    # They are not Markdown, and should be treated as verbatim text.
    if ($verbatim_fence_line =~ /^\*{3}\s*\d+(?:,\d+)?\s*\*{3,}\s*\z/s) {
        my boolean $verbatim_fence_found_end = 0;
        my integer $verbatim_fence_scan_limit = 500;
        my integer $verbatim_fence_scan_k = $verbatim_fence_i;

        while ($verbatim_fence_scan_k < scalar(@{$out_lines}) && ($verbatim_fence_scan_k - $verbatim_fence_i) < $verbatim_fence_scan_limit) {
            my string $verbatim_fence_scan_line = $out_lines->[$verbatim_fence_scan_k];
            if ($verbatim_fence_scan_line =~ /^-{3}\s+end\s+of\s+patch\s+-{3}\s*\z/s) {
                $verbatim_fence_found_end = 1;
                last;
            }
            $verbatim_fence_scan_k++;
        }

        if ($verbatim_fence_found_end) {
            push @{$verbatim_fence_new_lines}, '```diff';

            my integer $verbatim_fence_patch_k = $verbatim_fence_i;
            while ($verbatim_fence_patch_k < scalar(@{$out_lines})) {
                my string $verbatim_fence_patch_line = $out_lines->[$verbatim_fence_patch_k];
                push @{$verbatim_fence_new_lines}, $verbatim_fence_patch_line;

                $verbatim_fence_patch_k++;

                last if ($verbatim_fence_patch_line =~ /^-{3}\s+end\s+of\s+patch\s+-{3}\s*\z/s);

                last if (($verbatim_fence_patch_k - $verbatim_fence_i) >= $verbatim_fence_scan_limit);
            }

            $verbatim_fence_i = $verbatim_fence_patch_k - 1;

            push @{$verbatim_fence_new_lines}, '```';
            $cnt_markdownlint_fenced_patch_blocks++;
            next;
        }
    }

    # Ed-style diff output blocks (e.g. "114c123" followed by "< ..." and "> ..." lines).
    # These are not Markdown, and should be treated as verbatim text.
    if ($verbatim_fence_line =~ /^\d+(?:,\d+)?[acd]\d+(?:,\d+)?\s*\z/s) {
        my integer $verbatim_fence_scan_limit = 500;
        my boolean $verbatim_fence_found_payload = 0;

        my integer $verbatim_fence_scan_k = $verbatim_fence_i + 1;
        while ($verbatim_fence_scan_k < scalar(@{$out_lines}) && ($verbatim_fence_scan_k - $verbatim_fence_i) < $verbatim_fence_scan_limit) {
            my string $verbatim_fence_scan_line = $out_lines->[$verbatim_fence_scan_k];

            if ($verbatim_fence_scan_line =~ /^\s*\z/s) {
                $verbatim_fence_scan_k++;
                next;
            }

            if ($verbatim_fence_scan_line =~ /^\d+(?:,\d+)?[acd]\d+(?:,\d+)?\s*\z/s) {
                $verbatim_fence_scan_k++;
                next;
            }

            if ($verbatim_fence_scan_line =~ /^\s*[<>]\s/s || $verbatim_fence_scan_line =~ /^\s*-{3}\s*\z/s || $verbatim_fence_scan_line =~ /^\s*#{1,6}\s*[<>]\s/s) {
                $verbatim_fence_found_payload = 1;
            }

            last;
        }

        if ($verbatim_fence_found_payload) {
            push @{$verbatim_fence_new_lines}, '```diff';

            my integer $verbatim_fence_diff_k = $verbatim_fence_i;
            while ($verbatim_fence_diff_k < scalar(@{$out_lines})) {
                my string $verbatim_fence_diff_line = $out_lines->[$verbatim_fence_diff_k];

                if ($verbatim_fence_diff_line =~ /^\s*\z/s) {
                    push @{$verbatim_fence_new_lines}, $verbatim_fence_diff_line;
                    $verbatim_fence_diff_k++;
                    next;
                }

                if ($verbatim_fence_diff_line =~ /^\d+(?:,\d+)?[acd]\d+(?:,\d+)?\s*\z/s ||
                    $verbatim_fence_diff_line =~ /^\s*[<>]\s/s ||
                    $verbatim_fence_diff_line =~ /^\s*-{3}\s*\z/s ||
                    $verbatim_fence_diff_line =~ /^\s*#{1,6}\s*[<>]\s/s) {
                    push @{$verbatim_fence_new_lines}, $verbatim_fence_diff_line;
                    $verbatim_fence_diff_k++;
                    next;
                }

                last;
            }

            $verbatim_fence_i = $verbatim_fence_diff_k - 1;

            push @{$verbatim_fence_new_lines}, '```';
            $cnt_markdownlint_fenced_ed_diff_blocks++;

            next;
        }
    }


    # Grep-like output blocks: "path/to/file:123:..." often contain patterns that look like Markdown.
    # Wrap runs of 2+ consecutive grep-like lines in a fenced code block.
    if ($verbatim_fence_line =~ /^(\s{0,3})[^:\s]+\/[^:\s]+:\d+:\s*\S.*\z/s) {
        if ($verbatim_fence_i + 1 < scalar(@{$out_lines})) {
            my string $verbatim_fence_next = $out_lines->[$verbatim_fence_i + 1];
            if ($verbatim_fence_next =~ /^(\s{0,3})[^:\s]+\/[^:\s]+:\d+:\s*\S.*\z/s) {
                push @{$verbatim_fence_new_lines}, '```text';

                my integer $verbatim_fence_grep_k = $verbatim_fence_i;
                while ($verbatim_fence_grep_k < scalar(@{$out_lines})) {
                    my string $verbatim_fence_grep_line = $out_lines->[$verbatim_fence_grep_k];
                    last if ($verbatim_fence_grep_line !~ /^(\s{0,3})[^:\s]+\/[^:\s]+:\d+:\s*\S.*\z/s);

                    push @{$verbatim_fence_new_lines}, $verbatim_fence_grep_line;

                    $verbatim_fence_grep_k++;
                }

                $verbatim_fence_i = $verbatim_fence_grep_k - 1;

                push @{$verbatim_fence_new_lines}, '```';
                $cnt_markdownlint_fenced_grep_blocks++;

                next;
            }
        }
    }

    push @{$verbatim_fence_new_lines}, $verbatim_fence_line;
}

$out_lines = $verbatim_fence_new_lines;

dbg('markdownlint: fenced_grep_blocks=' . $cnt_markdownlint_fenced_grep_blocks);
dbg('markdownlint: fenced_patch_blocks=' . $cnt_markdownlint_fenced_patch_blocks);
dbg('markdownlint: fenced_ed_diff_blocks=' . $cnt_markdownlint_fenced_ed_diff_blocks);

# MD034: no bare URLs. Wrap bare URLs in autolinks (<...>).
my boolean $md034_in_block = 0;

for (my integer $md034_i = 0; $md034_i < scalar(@{$out_lines}); $md034_i++) {
    my string $md034_line = $out_lines->[$md034_i];

    my boolean $md034_is_fence = 0;
    my string $md034_f_lang = '';
    ($md034_is_fence, $md034_f_lang) = is_triple_fence_line($md034_line);
    if ($md034_is_fence) {
        $md034_in_block = ($md034_in_block ? 0 : 1);
        next;
    }
    next if $md034_in_block;

    # Preserve simple inline code spans while fixing bare URLs.
    my arrayref $md034_spans = [];
    my string $md034_work = $md034_line;

    $md034_work =~ s/(`[^`]*`)/do {
        my integer $md034_idx = scalar(@{$md034_spans});
        push @{$md034_spans}, $1;
        "\x00MD034SPAN" . $md034_idx . "\x00";
    }/ge;

    my integer $md034_hits = 0;
    $md034_work =~ s{
        (?<!<)
        (?<!\]\()
        (https?://\S+?)
        (?=(\s|\z))
    }{
        my string $md034_url = $1;
        my string $md034_trail = '';
        while ($md034_url =~ s/([)\].,;:!?]+)\z//s) {
            $md034_trail = $1 . $md034_trail;
        }
        $md034_hits++;
        '<' . $md034_url . '>' . $md034_trail;
    }gex;

    if (scalar(@{$md034_spans}) > 0) {
        for (my integer $md034_j = 0; $md034_j < scalar(@{$md034_spans}); $md034_j++) {
            my string $md034_ph = "\x00MD034SPAN" . $md034_j . "\x00";
            $md034_work =~ s/\Q$md034_ph\E/$md034_spans->[$md034_j]/g;
        }
    }

    if ($md034_work ne $md034_line) {
        $out_lines->[$md034_i] = $md034_work;
        $cnt_markdownlint_md034_autolinked_urls += $md034_hits;
    }
}

dbg('markdownlint: md034_autolinked_urls=' . $cnt_markdownlint_md034_autolinked_urls);

# MD033: no inline HTML. Convert pseudo-tags like <NEED ...> to [NEED ...].
my boolean $md033_in_block = 0;

for (my integer $md033_i = 0; $md033_i < scalar(@{$out_lines}); $md033_i++) {
    my string $md033_line = $out_lines->[$md033_i];

    my boolean $md033_is_fence = 0;
    my string $md033_f_lang = '';
    ($md033_is_fence, $md033_f_lang) = is_triple_fence_line($md033_line);
    if ($md033_is_fence) {
        $md033_in_block = ($md033_in_block ? 0 : 1);
        next;
    }
    next if $md033_in_block;

    if ($md033_line =~ /<NEED\b[^>]*>/s) {
        my string $md033_new = $md033_line;
        $md033_new =~ s/<(NEED\b[^>]*)>/do {
            my string $md033_inner = $1;
            $cnt_markdownlint_md033_need_tags_fixed++;
            '[' . $md033_inner . ']';
        }/ge;

        if ($md033_new ne $md033_line) {
            $out_lines->[$md033_i] = $md033_new;
        }
    }
}

dbg('markdownlint: md033_need_tags_fixed=' . $cnt_markdownlint_md033_need_tags_fixed);

# MD037: no spaces inside emphasis markers. Trim spaces immediately inside emphasis spans.
my boolean $md037_in_block = 0;

for (my integer $md037_i = 0; $md037_i < scalar(@{$out_lines}); $md037_i++) {
    my string $md037_line = $out_lines->[$md037_i];

    my boolean $md037_is_fence = 0;
    my string $md037_f_lang = '';
    ($md037_is_fence, $md037_f_lang) = is_triple_fence_line($md037_line);
    if ($md037_is_fence) {
        $md037_in_block = ($md037_in_block ? 0 : 1);
        next;
    }
    next if $md037_in_block;

    # Preserve simple inline code spans while fixing emphasis.
    my arrayref $md037_spans = [];
    my string $md037_work = $md037_line;

    $md037_work =~ s/(`[^`]*`)/do {
        my integer $md037_idx = scalar(@{$md037_spans});
        push @{$md037_spans}, $1;
        chr(0) . 'MD037SPAN' . $md037_idx . chr(0);
    }/ge;

    my integer $md037_hits = 0;

    $md037_work =~ s/\*\*([^*]*?)\*\*/do {
        my string $md037_inner = $1;
        my string $md037_trim = $md037_inner;

        $md037_trim =~ s{\A\s+}{}s;
        $md037_trim =~ s{\s+\z}{}s;

        if ($md037_trim ne $md037_inner and $md037_trim ne '') {
            $md037_hits++;
            '**' . $md037_trim . '**';
        }
        else {
            '**' . $md037_inner . '**';
        }
    }/ge;

    $md037_work =~ s/__(?!_)([^_]*?)(?<!_)__/do {
        my string $md037_inner = $1;
        my string $md037_trim = $md037_inner;

        $md037_trim =~ s{\A\s+}{}s;
        $md037_trim =~ s{\s+\z}{}s;

        if ($md037_trim ne $md037_inner and $md037_trim ne '') {
            $md037_hits++;
            '__' . $md037_trim . '__';
        }
        else {
            '__' . $md037_inner . '__';
        }
    }/ge;

    $md037_work =~ s/(?<!\*)\*([^*]*?)\*(?!\*)/do {
        my string $md037_inner = $1;
        my string $md037_trim = $md037_inner;

        $md037_trim =~ s{\A\s+}{}s;
        $md037_trim =~ s{\s+\z}{}s;

        if ($md037_trim ne $md037_inner and $md037_trim ne '') {
            $md037_hits++;
            '*' . $md037_trim . '*';
        }
        else {
            '*' . $md037_inner . '*';
        }
    }/ge;

    $md037_work =~ s/(?<!_)_([^_]*?)_(?!_)/do {
        my string $md037_inner = $1;
        my string $md037_trim = $md037_inner;

        $md037_trim =~ s{\A\s+}{}s;
        $md037_trim =~ s{\s+\z}{}s;

        if ($md037_trim ne $md037_inner and $md037_trim ne '') {
            $md037_hits++;
            '_' . $md037_trim . '_';
        }
        else {
            '_' . $md037_inner . '_';
        }
    }/ge;

    if (scalar(@{$md037_spans}) > 0) {
        for (my integer $md037_j = 0; $md037_j < scalar(@{$md037_spans}); $md037_j++) {
            my string $md037_ph = chr(0) . 'MD037SPAN' . $md037_j . chr(0);
            $md037_work =~ s/\Q$md037_ph\E/$md037_spans->[$md037_j]/g;
        }
    }

    if ($md037_hits > 0 and $md037_work ne $md037_line) {
        $out_lines->[$md037_i] = $md037_work;
        $cnt_markdownlint_md037_fixed_emphasis += $md037_hits;
    }
}

dbg('markdownlint: md037_fixed_emphasis=' . $cnt_markdownlint_md037_fixed_emphasis);

# MD049: emphasis-style. Convert single-asterisk emphasis spans to underscores.
my boolean $md049_in_block = 0;

for (my integer $md049_i = 0; $md049_i < scalar(@{$out_lines}); $md049_i++) {
    my string $md049_line = $out_lines->[$md049_i];

    my boolean $md049_is_fence = 0;
    my string $md049_f_lang = '';
    ($md049_is_fence, $md049_f_lang) = is_triple_fence_line($md049_line);
    if ($md049_is_fence) {
        $md049_in_block = ($md049_in_block ? 0 : 1);
        next;
    }
    next if $md049_in_block;

    # Preserve simple inline code spans while converting emphasis markers.
    my arrayref $md049_spans = [];
    my string $md049_work = $md049_line;

    $md049_work =~ s/(`[^`]*`)/do {
        my integer $md049_idx = scalar(@{$md049_spans});
        push @{$md049_spans}, $1;
        chr(0) . 'MD049SPAN' . $md049_idx . chr(0);
    }/ge;

    my integer $md049_hits = 0;

    $md049_work =~ s/(?<!\\)(?<!\*)\*([^\s*](?:[^*]*?[^\s*])?)\*(?!\*)/do {
        my string $md049_inner = $1;
        $md049_hits++;
        '_' . $md049_inner . '_';
    }/ge;

    if (scalar(@{$md049_spans}) > 0) {
        for (my integer $md049_j = 0; $md049_j < scalar(@{$md049_spans}); $md049_j++) {
            my string $md049_ph = chr(0) . 'MD049SPAN' . $md049_j . chr(0);
            $md049_work =~ s/\Q$md049_ph\E/$md049_spans->[$md049_j]/g;
        }
    }

    if ($md049_hits > 0 and $md049_work ne $md049_line) {
        $out_lines->[$md049_i] = $md049_work;
        $cnt_markdownlint_md049_converted_emphasis += $md049_hits;
    }
}

dbg('markdownlint: md049_converted_emphasis=' . $cnt_markdownlint_md049_converted_emphasis);

# MD038: no spaces inside code spans. Trim spaces immediately inside single-backtick spans.
my boolean $md038_in_block = 0;

for (my integer $md038_i = 0; $md038_i < scalar(@{$out_lines}); $md038_i++) {
    my string $md038_line = $out_lines->[$md038_i];

    my boolean $md038_is_fence = 0;
    my string $md038_f_lang = '';
    ($md038_is_fence, $md038_f_lang) = is_triple_fence_line($md038_line);
    if ($md038_is_fence) {
        $md038_in_block = ($md038_in_block ? 0 : 1);
        next;
    }
    next if $md038_in_block;

    my integer $md038_hits = 0;
    my string $md038_new = $md038_line;

    $md038_new =~ s/(?<!`)`([^`]*?)`(?!`)/do {
        my string $md038_inner = $1;
        my string $md038_trim = $md038_inner;

        $md038_trim =~ s{\A\s+}{}s;
        $md038_trim =~ s{\s+\z}{}s;

        if ($md038_trim ne $md038_inner && $md038_trim ne '') {
            $md038_hits++;
            '`' . $md038_trim . '`';
        }
        else {
            '`' . $md038_inner . '`';
        }
    }/ge;

    if ($md038_hits > 0 && $md038_new ne $md038_line) {
        $out_lines->[$md038_i] = $md038_new;
        $cnt_markdownlint_md038_fixed_code_spans += $md038_hits;
    }
}

dbg('markdownlint: md038_fixed_code_spans=' . $cnt_markdownlint_md038_fixed_code_spans);




# MD031: fenced code blocks should be surrounded by blank lines.
my boolean $md031_in_block = 0;
my string $md031_active_prefix = '';
my string $md031_active_indent = '';
my string $md031_active_marker = '';
my arrayref $md031_new_lines = [];

for (my integer $md031_i = 0; $md031_i < scalar(@{$out_lines}); $md031_i++) {
    my string $md031_line = $out_lines->[$md031_i];

    my boolean $md031_is_fence = 0;
    my string $md031_prefix = '';
    my string $md031_indent = '';
    my string $md031_marker = '';
    my string $md031_lang = '';

    if ($md031_line =~ /^(\s*(?:>\s*)*)([ \t]{0,12})(```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/s) {
        $md031_is_fence = 1;
        $md031_prefix = $1;
        $md031_indent = $2;
        $md031_marker = $3;
        $md031_lang = $4;
        $md031_lang = '' if !defined $md031_lang;
    }

    if ($md031_is_fence) {
        my string $md031_blank_line = '';
        my string $md031_prefix_trim = $md031_prefix;
        $md031_prefix_trim =~ s/\s+\z//s;
        $md031_blank_line = $md031_prefix_trim . $md031_indent;

        if (!$md031_in_block) {
            # Opening fence: ensure blank line before it (unless start-of-file).
            if (scalar(@{$md031_new_lines}) > 0) {
                my string $md031_prev = $md031_new_lines->[-1];

                my boolean $md031_prev_blank = 0;
                if ($md031_prev =~ /^\s*\z/s || $md031_prev =~ /^\s*(?:>\s*)+\z/s) {
                    $md031_prev_blank = 1;
                }

                if (!$md031_prev_blank) {
                    push @{$md031_new_lines}, $md031_blank_line;
                    $cnt_markdownlint_md031_inserted_blank_lines++;
                }
            }

            push @{$md031_new_lines}, $md031_line;

            $md031_in_block = 1;
            $md031_active_prefix = $md031_prefix;
            $md031_active_indent = $md031_indent;
            $md031_active_marker = $md031_marker;

            next;
        }

        # Closing fence: only close if this fence matches the opener.
        if ($md031_prefix eq $md031_active_prefix and $md031_indent eq $md031_active_indent and $md031_marker eq $md031_active_marker and $md031_lang eq '') {
            push @{$md031_new_lines}, $md031_line;

            $md031_in_block = 0;
            $md031_active_prefix = '';
            $md031_active_indent = '';
            $md031_active_marker = '';

            if ($md031_i + 1 < scalar(@{$out_lines})) {
                my string $md031_next = $out_lines->[$md031_i + 1];

                my boolean $md031_next_blank = 0;
                if ($md031_next =~ /^\s*\z/s || $md031_next =~ /^\s*(?:>\s*)+\z/s) {
                    $md031_next_blank = 1;
                }

                if (!$md031_next_blank) {
                    push @{$md031_new_lines}, $md031_blank_line;
                    $cnt_markdownlint_md031_inserted_blank_lines++;
                }
            }

            next;
        }

        # Inside a fenced code block, treat non-matching fence lines as payload.
        push @{$md031_new_lines}, $md031_line;
        next;
    }

    push @{$md031_new_lines}, $md031_line;
}

$out_lines = $md031_new_lines;
dbg('markdownlint: md031_inserted_blank_lines=' . $cnt_markdownlint_md031_inserted_blank_lines);

# MD012: no multiple consecutive blank lines. Collapse to a single blank line outside fenced code blocks.
# markdownlint treats blockquote-empty lines like ">" (or nested ">>") as blank lines for MD012 purposes.
# We also need to recognize indented and blockquoted fences so we do not collapse blanks inside fenced blocks.
my boolean $md012_in_block = 0;
my arrayref $md012_new_lines = [];
my boolean $md012_prev_blank = 0;
my string $md012_prev_blank_out = '';

for (my integer $md012_i = 0; $md012_i < scalar(@{$out_lines}); $md012_i++) {
    my string $md012_line = $out_lines->[$md012_i];

    my boolean $md012_is_fence = 0;
    my string $md012_f_lang = '';

    # Recognize fences even when indented or inside blockquotes.
    if ($md012_line =~ /^(\s*(?:>\s*)*)([ \t]{0,3})(```|~~~)([A-Za-z0-9_+\-]+)?\s*\z/s) {
        $md012_is_fence = 1;
        $md012_f_lang = $4;
        $md012_f_lang = '' if !defined $md012_f_lang;
    }
    else {
        ($md012_is_fence, $md012_f_lang) = is_triple_fence_line($md012_line);
        if (!$md012_is_fence) {
            ($md012_is_fence, $md012_f_lang) = is_indented_triple_fence_line($md012_line);
        }
    }

    if ($md012_is_fence) {
        push @{$md012_new_lines}, $md012_line;
        $md012_in_block = ($md012_in_block ? 0 : 1);
        $md012_prev_blank = 0;
        $md012_prev_blank_out = '';
        next;
    }

    if ($md012_in_block) {
        push @{$md012_new_lines}, $md012_line;
        next;
    }

    my boolean $md012_blank = 0;
    my string $md012_blank_out = '';

    if ($md012_line =~ /^\s*\z/s) {
        $md012_blank = 1;
        $md012_blank_out = '';
    }
    elsif ($md012_line =~ /^(\s*(?:>\s*)+)\s*\z/s) {
        $md012_blank = 1;
        $md012_blank_out = $1;
        $md012_blank_out =~ s/\s+\z//s;
    }

    if ($md012_blank) {
        if ($md012_prev_blank) {
            $cnt_markdownlint_md012_collapsed_blank_lines++;
            next;
        }
        push @{$md012_new_lines}, $md012_blank_out;
        $md012_prev_blank = 1;
        $md012_prev_blank_out = $md012_blank_out;
        next;
    }

    push @{$md012_new_lines}, $md012_line;
    $md012_prev_blank = 0;
    $md012_prev_blank_out = '';
}

$out_lines = $md012_new_lines;
dbg('markdownlint: md012_collapsed_blank_lines=' . $cnt_markdownlint_md012_collapsed_blank_lines);
    }

    if ($dry_run) {
        my string $out_action = 'WOULD WRITE';
        $out_action = 'WOULD OVERWRITE' if ($out_exists && $overwrite);
        $out_action = 'WOULD SKIP (exists)' if ($blocked_out);

        my string $dbg_action = '';
        if ($debug) {
            my string $dbg_act = 'WOULD WRITE';
            $dbg_act = 'WOULD OVERWRITE' if ($dbg_exists && $overwrite);
            $dbg_act = 'WOULD SKIP (exists)' if ($blocked_dbg);
            $dbg_action = " debug=$dbg_act '$planned_dbg_path'";
        }

        my ($tier_s, $fail_s) = build_tier_report($result);
        print STDERR "DRY-RUN $out_action '$planned_out_path'$dbg_action$tier_s$fail_s\n";

        # Dry-run is a verification mode:
        # - existing outputs do not count as failures
        # - tier failures do count as failures
        my boolean $pass = result_is_tier_clean($result);
        if ($pass) {
            $ok_count++;
        } else {
            $fail_count++;
        }

        next;
    }

    my $out_fh;
    if (!open($out_fh, '>', $planned_out_path)) {
        print STDERR "Failed to open output file '$planned_out_path' for writing: $!\n";
        $fail_count++;
        next;
    }

    print $out_fh join("\n", @{$out_lines}), "\n";
    if (!close($out_fh)) {
        print STDERR "Failed to close output file '$planned_out_path': $!\n";
        $fail_count++;
        next;
    }

    my ($tier_s, $fail_s) = build_tier_report($result);
    print STDERR "WROTE '$planned_out_path'$tier_s$fail_s\n";

    if ($debug) {
        my $dbg_fh;
        if (!open($dbg_fh, '>', $planned_dbg_path)) {
            print STDERR "Failed to open debug output file '$planned_dbg_path' for writing: $!\n";
            $fail_count++;
            next;
        }
        print $dbg_fh join("\n", @{$dbg_lines}), "\n";
        if (!close($dbg_fh)) {
            print STDERR "Failed to close debug output file '$planned_dbg_path': $!\n";
            $fail_count++;
            next;
        }
        print STDERR "WROTE '$planned_dbg_path'\n";
    }

    my boolean $pass = result_is_tier_clean($result);
    if ($pass) {
        $ok_count++;
    } else {
        $fail_count++;
    }
}

my string $summary_prefix = ($clean ? 'CLEAN SUMMARY' : ($dry_run ? 'DRY-RUN SUMMARY' : 'SUMMARY'));
print STDERR $summary_prefix . " ok=$ok_count skipped=$skip_count failed=$fail_count\n";

dbg("exit: ok=$ok_count skipped=$skip_count failed=$fail_count");
exit($fail_count ? 1 : 0);
