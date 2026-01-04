#!/usr/bin/env perl
# Copyright © 2026, William N. Braswell, Jr.
# This program is free software; you can redistribute it and/or modify it under
# the same terms as Perl 5 itself.
our $VERSION = 0.008_000;

###############################################################################
# google_ai_chat_extract_html_to_md.pl
#
# OVERVIEW
#   This script extracts a compact, readable Markdown transcript from a locally
#   saved Google AI / Google “AI Mode” chat HTML export (often 10–25MB+ and full
#   of UI/Javascript/embedded assets).
#
#   The output is a simple back-and-forth conversation log:
#
#       **Google User:**
#       <user message>
#
#       **Google AI:**
#       <AI message (with Markdown links preserved)>
#
#       ---
#
# DESIGN GOALS
#   - Preserve the *conversation content* and discard the rest:
#       - Drop non-conversation Google UI text (feedback prompts, “X sites”, etc.)
#       - Drop all embedded images / base64 “data:” payloads
#       - Keep AI-provided URLs as valid Markdown links
#       - Keep the resulting .md file dramatically smaller than the raw HTML
#
#   - Be “low-magic” and robust:
#       - No Javascript execution
#       - Streaming HTML parsing (does not load full 25MB into RAM as one string)
#       - Avoid fragile “global HTML depth” approaches that break on void tags and
#         browser-style implicit closes
#
# HOW IT WORKS (HIGH LEVEL)
#   The parser scans the HTML stream and identifies two message container types:
#
#     1) USER PROMPTS
#        Trigger: <span ... class="... VndcI ... veK2kb ...">
#        Collection: accumulate plain text + links until the matching span closes
#
#     2) GOOGLE AI ANSWERS
#        Trigger: <div data-container-id="main-col">  (fallback: data-subtree="aimfl")
#        Collection: accumulate plain text + links until that container div closes
#
#   The script does NOT assume the user prompt and AI answer are nested under the
#   same parent “turn wrapper”. Instead, it treats prompts and answers as a
#   chronological stream:
#
#     - user prompts are queued as they appear
#     - each AI answer is paired with the earliest queued prompt
#
#   This pairing model matches the structure of Google’s saved HTML in practice
#   and prevents “missing / scrambled” transcripts caused by DOM layout changes.
#
# MARKDOWN OUTPUT DETAILS
#   - Links:
#       HTML: <a href="URL">Text</a>
#       MD:   [Text](<URL>)
#     Angle-bracket destinations are used so parentheses or other characters in
#     URLs do not break Markdown parsing and “eat” the rest of the document.
#
#   - Code:
#       <pre> blocks are emitted as fenced code blocks:
#         ```
#         ...
#         ```
#       Inline <code> is emitted as `inline code`.
#
#   - Lists/Paragraphs:
#       Basic paragraph and list formatting is preserved with newlines/bullets.
#
# SOURCES / “SITES” LINKS (OPTIONAL EXTRACTION)
#   Google often embeds a “sources / sites” panel inside HTML comments beginning
#   with "Sv6Kpe[[1,[[...". These payloads are not reliably valid JSON, so this
#   script extracts http(s) URLs heuristically from those comments and appends a
#   “Sources:” list to the corresponding AI answer (deduped and filtered).
#
# v0.008_000 BEHAVIOR CHANGES (REQUESTED)
#
#   - Web Results handling:
#       - AI responses containing ONLY "Here are the top web results" (and/or the
#         web results listings) are treated as “no real response” and rendered as:
#           [no real response generated, web search results only]
#       - AI responses containing "Here are the top web results" AND additional
#         valid content: web-results portions are stripped and the valid content is kept.
#
#   - AI errors / empty capture:
#       - If the HTML ends with user prompts that have no following AI answer block:
#           [ Google AI error, no response received ]
#       - If an AI answer block exists but no text survives cleanup:
#           [no text captured from HTML block]
#
#   - Strip safe Google artifacts:
#       - "Use code with caution."
#       - "{content: }"
#
#   - IMPORTANT: We no longer truncate the AI answer at "Here are top web results".
#     That truncation caused hidden valid content (present in raw HTML but hidden
#     in the browser UI) to be discarded. Instead we strip web-results selectively.
#
# USAGE
#   google_ai_chat_extract_html_to_md.pl --in file.html      > out.md
#   google_ai_chat_extract_html_to_md.pl --in file.html.gz   > out.md
#   google_ai_chat_extract_html_to_md.pl --in file.html --debug > out.md 2> debug.log
###############################################################################

use strict;
use warnings;
use utf8;

use Getopt::Long qw(GetOptions);
use IO::Uncompress::Gunzip qw($GunzipError);
use Encode ();
use HTML::Entities qw(decode_entities);

BEGIN {
    eval { require HTML::Parser; 1 }
      or die "ERROR: HTML::Parser is required. Install with: cpanm HTML::Parser\n";
}
use HTML::Parser ();

binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# -------------------------------------------------------------------------
# CLI
# -------------------------------------------------------------------------
my %opt = (
    in    => undef,
    debug => 0,
    help  => 0,
);

GetOptions(
    'in=s'   => \$opt{in},
    'debug!' => \$opt{debug},
    'help!'  => \$opt{help},
) or usage_and_exit(2);

usage_and_exit(0) if $opt{help};
usage_and_exit(2) if !defined($opt{in}) || $opt{in} eq '';

my $fh = open_input_handle($opt{in});
debug("Starting parse: $opt{in}");

# -------------------------------------------------------------------------
# Key idea:
#
# DO NOT use a single global HTML depth counter and compare depths.
# That breaks on real-world HTML (void tags, implicit closes, etc.).
#
# Instead:
#   - When we enter a USER message container, we count nested <span> tags only.
#   - When we enter an AI message container, we count nested <div> tags only.
#
# This makes end-detection stable and prevents “missing/scrambled” output.
# -------------------------------------------------------------------------

# Pending prompts (we pair in stream order)
my @pending_users;

# Output separator control
my $printed_any_turn = 0;

# Collection states
my $collect_user      = 0;
my $user_span_depth   = 0;
my $user_buf          = '';

my $collect_ai         = 0;
my $ai_div_depth       = 0;
my $ai_buf             = '';
my @ai_sources_urls    = ();   # URLs collected from Sv6Kpe comments during this AI answer
my %ai_sources_seen    = ();

# Formatting sub-states while collecting AI
my $in_pre             = 0;
my $pre_depth          = 0;
my $inline_code_depth  = 0;

# Table capture sub-state (fixes “Feature Fictional ACIOReal NSA...” run-on text)
my $in_table         = 0;
my $table_depth      = 0;
my $table_has_th     = 0;
my @table_rows       = ();
my @current_row      = ();
my $in_cell          = 0;      # within <td> or <th>
my $cell_depth       = 0;      # nested tags inside a cell; helps robust closing
my $cell_buf         = '';

# Anchor capture stack (works for both user and AI)
# Each entry: { href => "...", text => "" }
my @link_stack;

# -------------------------------------------------------------------------
# HTML::Parser handlers
# -------------------------------------------------------------------------
my $parser = HTML::Parser->new( api_version => 3 );

# Decode entities in text nodes for us (we still decode_entities in comments)
$parser->utf8_mode(1);

$parser->handler( start   => \&on_start,   'tagname, attr' );
$parser->handler( end     => \&on_end,     'tagname' );
$parser->handler( text    => \&on_text,    'dtext' );
$parser->handler( comment => \&on_comment, 'text' );

# Stream parse
while (1) {
    my $chunk = '';
    my $n = read($fh, $chunk, 64 * 1024);
    die "ERROR: read() failed: $!\n" if !defined $n;
    last if $n == 0;
    $parser->parse($chunk);
}
$parser->eof();

# Flush any leftover user prompts at EOF
flush_pending_users();

if (!$printed_any_turn) {
    debug("WARNING: No turns were printed. Selector triggers may be wrong for this HTML export.");
}

exit 0;

# =========================================================================
# Handlers
# =========================================================================

sub on_start {
    my ($tag, $attr) = @_;

    my $class = defined($attr->{class}) ? $attr->{class} : '';

    # ------------------------------------------------------------
    # USER start trigger
    #
    # In your HTML, these look like:
    #   <span class="VndcI veK2kb" ...> ... user prompt ...
    # ------------------------------------------------------------
    if (!$collect_user && !$collect_ai
        && $tag eq 'span'
        && $class =~ /\bVndcI\b/
        && $class =~ /\bveK2kb\b/)
    {
        $collect_user    = 1;
        $user_span_depth = 1;
        $user_buf        = '';
        @link_stack      = ();

        debug("BEGIN USER");
        return;
    }

    # If already collecting user, maintain span nesting depth
    if ($collect_user) {
        if ($tag eq 'span') {
            $user_span_depth++;
        }

        # Minimal formatting inside user prompt
        if ($tag eq 'br') {
            append_to(\$user_buf, "\n");
            return;
        }

        # Anchor handling
        if ($tag eq 'a') {
            my $href = defined($attr->{href}) ? $attr->{href} : '';
            push @link_stack, { href => $href, text => '' };
            return;
        }

        # Ignore images entirely
        return if $tag eq 'img';

        return;
    }

    # ------------------------------------------------------------
    # AI start trigger
    #
    # In your HTML, these look like:
    #   <div data-container-id="main-col" ...> ... answer ...
    #
    # If main-col is missing (rare), fall back to data-subtree="aimfl".
    # ------------------------------------------------------------
    if (!$collect_ai
        && $tag eq 'div'
        && (
            (defined($attr->{'data-container-id'}) && $attr->{'data-container-id'} eq 'main-col')
            || (defined($attr->{'data-subtree'}) && $attr->{'data-subtree'} eq 'aimfl')
        )
    ) {
        $collect_ai    = 1;
        $ai_div_depth  = 1;
        $ai_buf        = '';
        @link_stack    = ();

        @ai_sources_urls = ();
        %ai_sources_seen = ();

        $in_pre             = 0;
        $pre_depth          = 0;
        $inline_code_depth  = 0;

        $in_table        = 0;
        $table_depth     = 0;
        $table_has_th    = 0;
        @table_rows      = ();
        @current_row     = ();
        $in_cell         = 0;
        $cell_depth      = 0;
        $cell_buf        = '';

        debug("BEGIN AI");
        return;
    }

    # If collecting AI, maintain div nesting depth and do basic formatting.
    if ($collect_ai) {
        if ($tag eq 'div') {
            $ai_div_depth++;
        }

        # Ignore images entirely (kills data:image/... base64 bloat)
        return if $tag eq 'img';

        # Anchor handling
        if ($tag eq 'a') {
            my $href = defined($attr->{href}) ? $attr->{href} : '';
            push @link_stack, { href => $href, text => '' };
            return;
        }

        # --------------------------------------------------------
        # Table handling
        # --------------------------------------------------------
        if ($tag eq 'table') {
            begin_table();
            return;
        }
        if ($in_table && $tag eq 'tr') {
            begin_table_row();
            return;
        }
        if ($in_table && ($tag eq 'td' || $tag eq 'th')) {
            begin_table_cell($tag);
            return;
        }
        if ($in_table && $in_cell) {
            # Minimal structure inside cells; don't emit code fences in tables.
            if ($tag eq 'br') {
                append_to(ai_target_ref(), "\n");
                return;
            }
            if ($tag eq 'p') {
                append_to(ai_target_ref(), "\n");
                return;
            }
            if ($tag eq 'li') {
                append_to(ai_target_ref(), "- ");
                return;
            }
            if ($tag eq 'pre') {
                append_to(ai_target_ref(), "\n");
                return;
            }
            if ($tag eq 'code') {
                return;
            }
            return;
        }

        # Block-ish formatting helpers
        if ($tag eq 'br') {
            append_to(ai_target_ref(), "\n");
            return;
        }
        if ($tag eq 'p') {
            ensure_blankline(ai_target_ref());
            return;
        }
        if ($tag eq 'li') {
            ensure_newline(ai_target_ref());
            append_to(ai_target_ref(), "- ");
            return;
        }
        if ($tag =~ /\Ah[1-6]\z/) {
            ensure_blankline(ai_target_ref());
            return;
        }

        # Code blocks: <pre> ... </pre> (outside tables)
        if ($tag eq 'pre' && !$in_table) {
            if (!$in_pre) {
                ensure_blankline(ai_target_ref());
                append_to(ai_target_ref(), "```\n");
                $in_pre    = 1;
                $pre_depth = 1;
            }
            else {
                $pre_depth++;
            }
            return;
        }

        # Inline code: <code> ... </code> (outside pre, outside tables)
        if ($tag eq 'code' && !$in_pre && !$in_table) {
            $inline_code_depth++;
            append_to(ai_target_ref(), "`") if $inline_code_depth == 1;
            return;
        }

        return;
    }

    return;
}

sub on_text {
    my ($text) = @_;
    return if !defined $text || $text eq '';

    # Normalize newlines only.
    #
    # IMPORTANT:
    #   Do NOT convert NBSP here.
    #   If the HTML contains mojibake sequences (e.g. "Â " or "â<80><94>"),
    #   converting NBSP early destroys the byte-pattern we need to repair later.
    $text =~ s/\r\n?/\n/g;

    # While inside an <a>, accumulate as link text (not directly into buf)
    if (@link_stack) {
        $link_stack[-1]->{text} .= $text;
        return;
    }

    if ($collect_user) {
        append_to(\$user_buf, $text);
        return;
    }

    if ($collect_ai) {
        append_to(ai_target_ref(), $text);
        return;
    }

    return;
}

sub on_end {
    my ($tag) = @_;

    # Close anchor: emit Markdown link
    if (($collect_user || $collect_ai) && $tag eq 'a') {
        my $link = pop @link_stack;
        $link ||= { href => '', text => '' };

        my $href = defined($link->{href}) ? $link->{href} : '';
        my $ltxt = defined($link->{text}) ? $link->{text} : '';

        my $md = anchor_to_markdown($ltxt, $href);

        if ($collect_user) {
            append_to(\$user_buf, $md);
        }
        elsif ($collect_ai) {
            append_to(ai_target_ref(), $md);
        }
        # fallthrough: other end logic still applies
    }

    # End of user: decrement span nesting, end when it reaches 0
    if ($collect_user) {
        if ($tag eq 'span') {
            $user_span_depth--;
            if ($user_span_depth <= 0) {
                $collect_user    = 0;
                $user_span_depth = 0;

                my $msg = clean_message_text($user_buf);
                $user_buf = '';
                @link_stack = ();

                if (defined $msg && $msg ne '') {
                    push @pending_users, $msg;
                }

                debug("END USER (pending_users=" . scalar(@pending_users) . ")");
                return;
            }
        }
        return;
    }

    # End of AI: maintain div nesting, end when it reaches 0
    if ($collect_ai) {

        # Table close handling
        if ($in_table && ($tag eq 'td' || $tag eq 'th')) {
            end_table_cell($tag);
            return;
        }
        if ($in_table && $tag eq 'tr') {
            end_table_row();
            return;
        }
        if ($in_table && $tag eq 'table') {
            end_table();
            return;
        }

        # Inline code close (outside tables)
        if ($tag eq 'code' && !$in_pre && !$in_table) {
            if ($inline_code_depth > 0) {
                $inline_code_depth--;
                append_to(ai_target_ref(), "`") if $inline_code_depth == 0;
            }
            return;
        }

        # Code block close (outside tables)
        if ($tag eq 'pre' && !$in_table) {
            if ($in_pre) {
                $pre_depth--;
                if ($pre_depth <= 0) {
                    $in_pre    = 0;
                    $pre_depth = 0;
                    append_to(ai_target_ref(), "\n```\n");
                    ensure_blankline(ai_target_ref());
                }
            }
            return;
        }

        # Some block ends -> add spacing
        if ($tag eq 'p' || $tag eq 'li' || $tag =~ /\Ah[1-6]\z/) {
            ensure_blankline(ai_target_ref());
        }

        if ($tag eq 'div') {
            $ai_div_depth--;
            if ($ai_div_depth <= 0) {
                $collect_ai   = 0;
                $ai_div_depth = 0;
                @link_stack   = ();

                # If the HTML ended oddly while inside a table, flush it anyway.
                if ($in_table) {
                    end_table();
                }

                # IMPORTANT: AI cleanup is NOT identical to user cleanup.
                # We preserve content beyond the web-results marker, then strip
                # web-results conditionally (web-only vs web+real-answer).
                my $msg = clean_ai_message_text($ai_buf);
                $ai_buf = '';

                emit_turn_pair($msg);

                debug("END AI");
                return;
            }
        }

        return;
    }

    return;
}

sub on_comment {
    my ($c) = @_;
    return if !$collect_ai;
    return if !defined($c) || $c eq '';

    # Sv6Kpe comments contain the “sites” results / sources blobs.
    # These are *not* reliably valid JSON (sometimes contain “...” etc),
    # so we DO NOT decode_json; we extract URLs heuristically and filter.
    return if $c !~ /\ASv6Kpe\[\[1,\[\[/;

    my $decoded = decode_entities($c);

    # Extract candidate URLs inside quotes (usually)
    while ($decoded =~ m{"(https?://[^"]+)"}g) {
        my $u = $1;
        $u = unescape_jsish($u);
        $u = sanitize_url($u);

        next if !defined($u) || $u eq '';
        next if $u =~ /\Adata:/i;

        # Filter obvious Google UI/proxy/thumb URLs
        next if $u =~ /encrypted-tbn\d*\.gstatic\.com/i;
        next if $u =~ /faviconV2\?url=/i;

        next if $ai_sources_seen{$u}++;
        push @ai_sources_urls, $u;

        # Don’t let this list explode
        last if @ai_sources_urls >= 30;
    }

    return;
}

# =========================================================================
# Output pairing
# =========================================================================

sub emit_turn_pair {
    my ($ai_msg) = @_;
    $ai_msg = '' if !defined $ai_msg;

    my $user_msg = '';
    if (@pending_users) {
        $user_msg = shift @pending_users;
    }

    # Print separator between turns (not at top)
    if ($printed_any_turn) {
        print "\n---\n\n";
    }
    $printed_any_turn = 1;

    if ($user_msg ne '') {
        print "**Google User:**\n\n$user_msg\n\n";
    }

    # v0.008 rule: never output an empty Google AI segment.
    if ($ai_msg eq '') {
        $ai_msg = '[no text captured from HTML block]';
    }
    print "**Google AI:**\n\n$ai_msg\n\n";

    return;
}

sub flush_pending_users {
    return if !@pending_users;

    # v0.008 rule: pending users at EOF imply Google AI error / no response.
    for my $u (@pending_users) {
        next if !defined($u) || $u eq '';

        if ($printed_any_turn) {
            print "\n---\n\n";
        }
        $printed_any_turn = 1;

        print "**Google User:**\n\n$u\n\n";
        print "**Google AI:**\n\n[ Google AI error, no response received ]\n\n";
    }

    @pending_users = ();
    return;
}

# =========================================================================
# Markdown / URL helpers
# =========================================================================

sub anchor_to_markdown {
    my ($label, $href) = @_;
    $label = '' if !defined $label;
    $href  = '' if !defined $href;

    my $url = sanitize_url($href);
    return $label if !defined($url) || $url eq '';
    return $label if $url =~ /\Adata:/i;

    my $t = $label;

    # If the link text is empty (icons, etc), use the URL itself.
    $t =~ s/\s+/ /g;
    $t =~ s/\A\s+//;
    $t =~ s/\s+\z//;
    $t = $url if $t eq '';

    # Escape brackets in link text
    $t =~ s/\[/\\[/g;
    $t =~ s/\]/\\]/g;

    # Use angle brackets in destination so parentheses won’t break Markdown
    $url =~ s/</%3C/g;
    $url =~ s/>/%3E/g;

    return "[$t](<$url>)";
}

sub sanitize_url {
    my ($href) = @_;
    return undef if !defined $href;

    my $u = $href;

    # Decode minimal entity forms that show up in hrefs
    $u =~ s/&amp;/&/g;

    # Drop junk schemes
    return undef if $u =~ /\Ajavascript:/i;
    return undef if $u =~ /\Adata:/i;
    return undef if $u =~ /\A#/;

    # Unwrap /url?q=... redirect forms
    $u = unwrap_google_redirect($u);

    # Ignore relative URLs (Google internal)
    return undef if $u =~ m!\A/!;

    # Normalize scheme-less URLs
    if ($u =~ m!\A//! ) {
        $u = "https:$u";
    }
    elsif ($u !~ m!\Ahttps?://!i) {
        if ($u =~ /\Awww\./i) {
            $u = "https://$u";
        }
        elsif ($u =~ /\A[A-Za-z0-9.-]+\.[A-Za-z]{2,}(?:\/|\z)/) {
            $u = "https://$u";
        }
        else {
            return undef;
        }
    }

    $u =~ s/\A\s+//;
    $u =~ s/\s+\z//;

    # No whitespace inside URL
    $u =~ s/\s+//g;

    return $u;
}

sub unwrap_google_redirect {
    my ($u) = @_;
    return $u if !defined $u;

    my $qs;
    if ($u =~ m!\Ahttps?://(?:www\.)?google\.[^/]+/url\?(.+)\z!i) {
        $qs = $1;
    }
    elsif ($u =~ m!\A/url\?(.+)\z!i) {
        $qs = $1;
    }
    else {
        return $u;
    }

    my %p = parse_query_string($qs);
    my $target = $p{q} // $p{url};
    return $u if !defined($target) || $target eq '';
    return $target;
}

sub parse_query_string {
    my ($qs) = @_;
    my %p;
    return %p if !defined $qs;

    for my $pair (split /[&;]/, $qs) {
        next if $pair eq '';
        my ($k, $v) = split /=/, $pair, 2;
        $k = '' if !defined $k;
        $v = '' if !defined $v;

        $k = percent_decode($k);
        $v = percent_decode($v);

        $p{$k} = $v;
    }

    return %p;
}

sub percent_decode {
    my ($s) = @_;
    return '' if !defined $s;

    $s =~ tr/+/ /;
    $s =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;

    # Best-effort UTF-8 decode
    my $decoded = $s;
    eval {
        $decoded = Encode::decode('UTF-8', $s, Encode::FB_CROAK);
        1;
    } or return $s;

    return $decoded;
}

sub unescape_jsish {
    my ($s) = @_;
    return '' if !defined $s;

    # Convert \uXXXX sequences
    $s =~ s/\\u([0-9A-Fa-f]{4})/chr(hex($1))/eg;

    # Convert escaped slashes
    $s =~ s!\\\/!/!g;

    return $s;
}

sub sources_urls_to_md {
    return '' if !@ai_sources_urls;

    my @lines;
    for my $u (@ai_sources_urls) {
        next if !defined($u) || $u eq '';
        push @lines, "- [$u](<$u>)";
    }
    return join("\n", @lines) . "\n";
}

# =========================================================================
# Table handling
# =========================================================================

sub begin_table {
    if (!$in_table) {
        $in_table      = 1;
        $table_depth   = 1;
        $table_has_th  = 0;
        @table_rows    = ();
        @current_row   = ();
        $in_cell       = 0;
        $cell_depth    = 0;
        $cell_buf      = '';
        debug("TABLE: begin");
    }
    else {
        $table_depth++;
    }
}

sub begin_table_row {
    end_table_row() if @current_row;
    @current_row = ();
    debug("TABLE: row begin");
}

sub begin_table_cell {
    my ($tag) = @_;
    $table_has_th = 1 if $tag eq 'th';

    $in_cell    = 1;
    $cell_depth = 1;
    $cell_buf   = '';
    debug("TABLE: cell begin ($tag)");
}

sub end_table_cell {
    my ($tag) = @_;
    return if !$in_cell;

    my $txt = clean_table_cell_text($cell_buf);
    push @current_row, $txt;

    $in_cell    = 0;
    $cell_depth = 0;
    $cell_buf   = '';
    debug("TABLE: cell end ($tag)");
}

sub end_table_row {
    if (@current_row) {
        push @table_rows, [ @current_row ];
    }
    @current_row = ();
    debug("TABLE: row end");
}

sub end_table {
    return if !$in_table;

    $table_depth--;
    if ($table_depth > 0) {
        return;
    }

    end_table_cell('td') if $in_cell;
    end_table_row()      if @current_row;

    my $md = render_table_markdown(\@table_rows, $table_has_th);

    if (defined $md && $md ne '') {
        ensure_blankline(\$ai_buf);
        append_to(\$ai_buf, $md);
        ensure_blankline(\$ai_buf);
    }

    $in_table      = 0;
    $table_depth   = 0;
    $table_has_th  = 0;
    @table_rows    = ();
    @current_row   = ();
    $in_cell       = 0;
    $cell_depth    = 0;
    $cell_buf      = '';

    debug("TABLE: end");
}

sub render_table_markdown {
    my ($rows, $has_header) = @_;
    return '' if !defined $rows || ref($rows) ne 'ARRAY' || !@$rows;

    my $max_cols = 0;
    for my $r (@$rows) {
        next if !defined $r || ref($r) ne 'ARRAY';
        $max_cols = @$r if @$r > $max_cols;
    }
    return '' if $max_cols == 0;

    my @norm;
    for my $r (@$rows) {
        my @cells = ();
        @cells = @$r if defined($r) && ref($r) eq 'ARRAY';

        push @cells, ('') while @cells < $max_cols;

        for my $c (@cells) {
            $c = '' if !defined $c;
            $c =~ s/\r\n?/\n/g;
            $c =~ s/\n/<br>/g;
            $c =~ s/\|/\\|/g;
            $c =~ s/\s+\z//;
            $c =~ s/\A\s+//;
        }

        push @norm, \@cells;
    }

    my $use_header = 0;
    $use_header = 1 if $has_header;
    $use_header = 1 if !$has_header && @norm >= 2;

    my @out;
    if ($use_header) {
        my $hdr = shift @norm;
        push @out, '| ' . join(' | ', @$hdr) . ' |';
        push @out, '| ' . join(' | ', (('---') x $max_cols)) . ' |';
    }

    for my $r (@norm) {
        push @out, '| ' . join(' | ', @$r) . ' |';
    }

    return join("\n", @out) . "\n";
}

sub clean_table_cell_text {
    my ($t) = @_;
    $t = '' if !defined $t;

    $t =~ s/\r\n?/\n/g;
    $t = repair_text_encoding($t);

    $t =~ s/[ \t]{2,}/ /g;
    $t =~ s/\A\s+//;
    $t =~ s/\s+\z//;

    return $t;
}

# =========================================================================
# Text cleanup
# =========================================================================

sub clean_message_text {
    my ($t) = @_;
    return '' if !defined $t;

    $t =~ s/\r\n?/\n/g;

    # Remove zero-width and BOM
    $t =~ s/[\x{200B}-\x{200D}\x{FEFF}]//g;

    # Remove ASCII control chars except \n and \t
    # NOTE: we intentionally do NOT remove C1 controls here (U+0080..U+009F)
    # because those are often part of mojibake sequences we want to repair first.
    $t =~ s/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]//g;

    # Repair common encoding damage, then normalize NBSP.
    $t = repair_text_encoding($t);

    # Remove literal data:image base64 blobs if any survived as text
    $t =~ s/data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+\/=]+/[image omitted]/g;

    # Remove/truncate Google UI footer junk (but DO NOT truncate at "web results")
    $t = remove_google_ui_footer_scraps($t);

    # Normalize whitespace OUTSIDE fenced code blocks only
    $t = normalize_whitespace_outside_fences($t);

    # Final trim
    $t =~ s/\A[ \t\n]+//;
    $t =~ s/[ \t\n]+\z//;

    return $t;
}

sub clean_ai_message_text {
    my ($raw) = @_;
    $raw = '' if !defined $raw;

    my $t = clean_message_text($raw);

    # Strip safe Google artifacts as standalone lines.
    $t = strip_google_artifact_lines($t);

    # Strip web results selectively (web-only vs web+valid-content).
    my ($t2, $saw_web, $web_only) = strip_web_results_panel($t);
    if ($saw_web) {
        if ($web_only) {
            $t = '[no real response generated, web search results only]';
        }
        else {
            $t = $t2;
            $t = strip_google_artifact_lines($t);
            $t = normalize_whitespace_outside_fences($t);
            $t =~ s/\A[ \t\n]+//;
            $t =~ s/[ \t\n]+\z//;
        }
    }

    # Attach sources collected from Sv6Kpe comments (URL-only, filtered/deduped)
    my $sources_md = sources_urls_to_md();
    if ($sources_md ne '') {
        $t =~ s/\s+\z//;
        $t .= "\n\nSources:\n$sources_md";
    }

    # If the AI block existed but nothing survived, emit placeholder.
    # (This is distinct from the EOF "no AI response received" case.)
    if (!defined($t) || $t !~ /\S/) {
        $t = '[no text captured from HTML block]';
    }

    return $t;
}

sub strip_google_artifact_lines {
    my ($t) = @_;
    return '' if !defined $t;

    my @lines = split /\n/, $t;
    my @keep;

    for my $ln (@lines) {
        my $x = $ln;
        $x =~ s/\A\s+//;
        $x =~ s/\s+\z//;

        next if $x =~ /\AUse\s+code\s+with\s+caution\.?\z/i;
        next if $x =~ /\A\{content:\s*\}\z/;

        push @keep, $ln;
    }

    return join("\n", @keep);
}

sub strip_web_results_panel {
    my ($t) = @_;
    return ($t, 0, 0) if !defined($t) || $t eq '';

    my $lc = lc($t);

    # We only treat it as a “web results” response if the marker appears near the start.
    my $p1 = index($lc, 'here are top web results');
    my $p2 = index($lc, 'here are the top web results');
    my $pos = -1;

    if ($p1 >= 0 && $p2 >= 0) {
        $pos = ($p1 < $p2) ? $p1 : $p2;
    }
    elsif ($p1 >= 0) {
        $pos = $p1;
    }
    elsif ($p2 >= 0) {
        $pos = $p2;
    }

    return ($t, 0, 0) if $pos < 0;
    return ($t, 0, 0) if $pos > 200;  # don’t strip if mentioned deep in prose

    my $after = substr($t, $pos);

    # Drop the header phrase itself.
    $after =~ s/\A.*?\bHere\s+are\s+(?:the\s+)?top\s+web\s+results\b[:\s]*//is;

    # Remove a leading “X sites” if present.
    $after =~ s/\A\s*\d+\s+sites\s*//i;

    # Remove common glued tokens from the web-results widget.
    $after =~ s/\bClose\s*\d+\s*sites\b//gi;

    # Try to find where the “real answer” starts.
    #
    # We look for distinctive prose markers you explicitly identified in your
    # problematic turns (e.g. “When I previously said…”, “Based on…”, etc.).
    my @markers = (
        qr/\bWhen I previously said\b/i,
        qr/\bSo the situation is\b/i,
        qr/\bIf you want\b/i,
        qr/\bBased on\b/i,
        qr/\bIn summary\b/i,
        qr/\bBottom line\b/i,
        qr/\bSome sources to consider\b/i,
        qr/\bIf the AI responses are\b/i,
        qr/\bFor official information\b/i,
        qr/\bFor research on\b/i,
        qr/\bHowever,\b/i,
    );

    my $best = undef;
    for my $re (@markers) {
        if ($after =~ /$re/) {
            my $p = $-[0];
            $best = $p if !defined($best) || $p < $best;
        }
    }

    if (defined $best) {
        my $ans = substr($after, $best);
        $ans =~ s/\A[ \t\n]+//;
        $ans =~ s/[ \t\n]+\z//;

        # If the “answer” is still empty, treat as web-only.
        return ('', 1, 1) if $ans !~ /\S/;

        return ($ans, 1, 0);
    }

    # Fallback: keep the last 1–2 paragraphs if they look like prose.
    my @paras = grep { $_ =~ /\S/ } split /\n{2,}/, $after;
    if (@paras) {
        my $cand = $paras[-1];
        if (@paras >= 2) {
            my $two = $paras[-2] . "\n\n" . $paras[-1];
            $cand = $two if looks_like_real_answer($two);
        }

        $cand =~ s/\A[ \t\n]+//;
        $cand =~ s/[ \t\n]+\z//;

        return ($cand, 1, 0) if looks_like_real_answer($cand);
    }

    # No reliable prose found: treat as web-results-only.
    return ('', 1, 1);
}

sub looks_like_real_answer {
    my ($s) = @_;
    return 0 if !defined($s);
    my $x = $s;

    $x =~ s/\[[^\]]+\]\(<https?:\/\/[^>]+>\)//g; # remove markdown links for word counting
    $x =~ s/https?:\/\/\S+//g;

    my @w = grep { $_ ne '' } split /\s+/, $x;
    my $wc = scalar(@w);

    return 0 if length($s) < 40;
    return 0 if $wc < 8;

    return 1;
}

sub repair_text_encoding {
    my ($t) = @_;
    return '' if !defined $t;
    return $t  if $t eq '';

    # Phase 1: targeted fixes for common “â<80><94>” style artifacts
    $t =~ s/\x{00E2}\x{0080}\x{0094}/—/g;  # em dash
    $t =~ s/\x{00E2}\x{0080}\x{0093}/–/g;  # en dash
    $t =~ s/\x{00E2}\x{0080}\x{0098}/‘/g;  # left single quote
    $t =~ s/\x{00E2}\x{0080}\x{0099}/’/g;  # right single quote
    $t =~ s/\x{00E2}\x{0080}\x{009C}/“/g;  # left double quote
    $t =~ s/\x{00E2}\x{0080}\x{009D}/”/g;  # right double quote
    $t =~ s/\x{00E2}\x{0080}\x{00A6}/…/g;  # ellipsis (sometimes)

    # NBSP mojibake: "Â " => NBSP
    $t =~ s/\x{00C2}\x{00A0}/\x{00A0}/g;

    # Phase 2: conservative latin1->utf8 repair if it improves “badness”
    if (looks_like_mojibake($t) && $t !~ /[^\x00-\xFF]/) {
        my $before = mojibake_score($t);

        my $bytes = Encode::encode('latin1', $t, Encode::FB_CROAK);
        my $fixed;
        eval {
            $fixed = Encode::decode('UTF-8', $bytes, Encode::FB_CROAK);
            1;
        } or $fixed = undef;

        if (defined $fixed) {
            my $after = mojibake_score($fixed);
            $t = $fixed if $after < $before;
        }
    }

    # Phase 3: normalize whitespace-ish chars and remove leftovers
    $t =~ s/\x{00A0}/ /g;                 # NBSP -> space
    $t =~ s/[\x{0080}-\x{009F}]//g;       # remove C1 controls
    $t =~ s/\x{00C2}(?=(?:\s|$|[[:punct:]]))//g;  # stray Â

    return $t;
}

sub looks_like_mojibake {
    my ($t) = @_;
    return 0 if !defined $t || $t eq '';

    return 1 if $t =~ /[\x{0080}-\x{009F}]/;
    return 1 if $t =~ /\x{00E2}[\x{0080}-\x{009F}]/;
    return 1 if $t =~ /[\x{00C2}\x{00C3}]/;

    return 0;
}

sub mojibake_score {
    my ($t) = @_;
    return 0 if !defined $t || $t eq '';

    my $score = 0;

    $score += () = ($t =~ /[\x{0080}-\x{009F}]/g);
    $score += () = ($t =~ /\x{00C2}/g);   # Â
    $score += () = ($t =~ /\x{00C3}/g);   # Ã
    $score += () = ($t =~ /\x{00E2}/g);   # â
    $score += () = ($t =~ /\x{FFFD}/g);   # replacement char

    return $score;
}

sub normalize_whitespace_outside_fences {
    my ($t) = @_;
    return '' if !defined $t;

    my @lines = split /\n/, $t;
    my @out;
    my $in_fence = 0;

    for my $line (@lines) {
        if ($line =~ /\A```/) {
            $in_fence = !$in_fence;
            push @out, $line;
            next;
        }

        if ($in_fence) {
            push @out, $line;
            next;
        }

        $line =~ s/[ \t]{2,}/ /g;
        $line =~ s/[ \t]+\z//;

        push @out, $line;
    }

    my $out = join("\n", @out);
    $out =~ s/\n{3,}/\n\n/g;

    return $out;
}

sub remove_google_ui_footer_scraps {
    my ($t) = @_;
    return '' if !defined $t;

    # Truncate at the FIRST sign of Google’s feedback/footer UI (end-of-answer),
    # but do NOT truncate at “web results” markers (handled separately).
    my $lower = lc($t);

    my @cut_needles = (
        'your feedback helps google improve',
        'share more feedback',
        'report a problem',
        'creating a public link...',
        'ai responses may include mistakes',
        'see our privacy policy',
    );

    my $cut = undef;
    for my $n (@cut_needles) {
        my $pos = index($lower, $n);
        next if $pos < 0;
        $cut = $pos if !defined($cut) || $pos < $cut;
    }

    if (defined $cut) {
        $t = substr($t, 0, $cut);
        $t =~ s/\bThank you\s*\z//i;
    }

    # Remove a few boilerplate fragments if they appear as standalone lines.
    my @lines = split /\n/, $t;
    my @keep;
    for my $ln (@lines) {
        my $x = $ln;
        $x =~ s/\A\s+//;
        $x =~ s/\s+\z//;

        next if $x =~ /\A\d+\s+sites\z/i;
        next if $x =~ /\AClose\z/i;
        next if $x =~ /\AThank you\z/i;

        push @keep, $ln;
    }

    return join("\n", @keep);
}

# =========================================================================
# Tiny formatting helpers
# =========================================================================

sub ai_target_ref {
    return $in_cell ? \$cell_buf : \$ai_buf;
}

sub append_to {
    my ($ref, $s) = @_;
    return if !defined $ref || ref($ref) ne 'SCALAR';
    return if !defined $s || $s eq '';
    $$ref .= $s;
}

sub ensure_newline {
    my ($ref) = @_;
    return if !defined $ref || ref($ref) ne 'SCALAR';
    return if $$ref eq '';
    return if $$ref =~ /\n\z/;
    $$ref .= "\n";
}

sub ensure_blankline {
    my ($ref) = @_;
    return if !defined $ref || ref($ref) ne 'SCALAR';
    return if $$ref eq '';
    $$ref .= "\n" if $$ref !~ /\n\z/;
    $$ref .= "\n" if $$ref !~ /\n\n\z/;
}

# =========================================================================
# IO / CLI
# =========================================================================

sub open_input_handle {
    my ($path) = @_;
    die "ERROR: --in is required\n" if !defined $path || $path eq '';

    if ($path eq '-') {
        binmode(STDIN, ':raw');
        return *STDIN;
    }

    open my $raw, '<:raw', $path
        or die "ERROR: cannot open '$path' for reading: $!\n";

    # Sniff gzip magic bytes (1F 8B)
    my $magic = '';
    read($raw, $magic, 2);
    seek($raw, 0, 0);

    if ($path =~ /\.gz\z/i || $magic eq "\x1F\x8B") {
        close $raw;

        my $gz = IO::Uncompress::Gunzip->new($path)
            or die "ERROR: Gunzip failed for '$path': $GunzipError\n";

        binmode($gz, ':raw');
        return $gz;
    }

    return $raw;
}

sub usage_and_exit {
    my ($code) = @_;
    print STDERR <<"USAGE";
Usage:
  google_ai_chat_extract_html_to_md.pl --in <file.html|file.html.gz> [--debug] > out.md

Options:
  --in     Input HTML file (optionally gzipped). Use '-' for STDIN.
  --debug  Verbose diagnostics to STDERR.
  --help   Show this help.

Example:
  google_ai_chat_extract_html_to_md.pl --in googleai_20260101-master_plan_conversation_P1.html.gz > out.md
USAGE
    exit($code);
}

sub debug {
    my ($msg) = @_;
    return if !$opt{debug};
    print STDERR "[debug] $msg\n";
}
