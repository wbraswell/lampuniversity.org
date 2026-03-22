<!-- no-compare-next-line -->
v0.025

<!-- no-compare-next-line -->
This file is an intentionally malformed regression fixture for chatgpt_markdown_fix.pl. After running --markdownlint --verify on this file, the output should match chatgpt_good.md.

## Verifier anchors and sentinels

- URL: <https://example.com/path?q=1>
- Email: fixtures@example.com
- Module: Foo::Bar
- Path: docs/file_a.md
- Script: bin/chatgpt_markdown_fix.pl
- Version token: v9.876

## Unit regression matrix - one fix per case

### MD001 - heading levels only increment by 1

## Parent heading

#### Skipped heading (was level-4)

This case ensures a jump from H2 to H4 is reduced to H3.

### MD003 - setext heading converted to ATX

Heading should use ATX style after cleanup
-----------------------------------------

This case ensures Setext underline headings are converted to ATX headings.

### MD004 - unordered list marker style uses '-'

* Item one
* Item two

### MD007 - unordered list indentation uses 4-space steps

- Parent item
  - Nested item should be indented by 4 spaces

### MD009 - trailing spaces normalized to 0-or-2

This line should end with 0 trailing spaces after cleanup. 
This line should end with 2 trailing spaces after cleanup.   
This line should end with 0 trailing spaces after cleanup.

### MD012 - multiple consecutive blank lines collapsed

Line above the blank block.


Line below the blank block.

### MD019 - no multiple spaces after '#'

##  Heading should have 1 space after '#' after cleanup

### MD022 - headings surrounded by blank lines

Text above the heading.
## Heading surrounded by blank lines
Text below the heading.

### MD025 - only one H1

# Extra top heading

This extra top heading should be demoted to H2 after cleanup.

### MD026 - strip trailing punctuation from headings

## Heading should have no trailing punctuation after cleanup:

### MD029 - ordered list item prefix and numeric label escaping

#### Case 1 - escape bullet numeric labels

- 7. This bullet starts with a number label but is not an ordered list

#### Case 2 - escape isolated numeric labels

7. This standalone number label is treated as text, not a list.

#### Case 3 - renumber ordered lists

1. Ordered list item one
3. Ordered list item two
9. Ordered list item three

#### Case 4 - nest unordered sublists under the most recent ordered list item

1. Ordered list parent
- Nested unordered child

### MD030 - exactly one space after list markers

-  This list item should have 1 space after its marker after cleanup
1.  This ordered list item should have 1 space after its marker after cleanup

### MD031 - blank lines around fenced code blocks

Text above the fence.
```text
line 1
line 2
```
Text below the fence.

### MD032 - lists surrounded by blank lines

Text above the list.
- Item A
- Item B
Text below the list.

### MD033 - no inline HTML placeholders

<NEED replace this placeholder>

### MD034 - no bare URLs

This URL should be autolinked after cleanup: https://example.com/autolink

This URL stays inside code: `https://example.com/inside-code`

### MD035 - horizontal rule style uses '---'

* * *

### MD036 - emphasis used instead of headings

#### Case 1 - orphan emphasis marker stripped

**
This paragraph is intentionally boring.

#### Case 2 - bold-only line converted to a heading

**This bold-only line should become a heading after cleanup**

#### Case 3 - emphasized quote converted to a blockquote

quote context

_This long italic quote line should become a blockquote after cleanup for readability and linting_

### MD037 - no spaces inside emphasis markers

This emphasis should have no inner spaces after cleanup: ** bold ** and __ bold __ and _ italic _.

This line should not be touched: =item * POD bullet marker

### MD038 - no spaces inside inline code spans

Inline code spans should have no inner spaces after cleanup: ` code ` and ` two words `.

### MD040 - fenced code blocks have a language and stray wrapper fences are removed

#### Case 1 - missing fence language defaults to 'text'

```
This fence should have an explicit language after cleanup.
```

#### Case 2 - stray speaker wrapper fence removed

**ChatGPT**:

```

```perl
my $x = 1;
print $x;
```

### MD041 - first line is an H1

This file should start with an H1 after cleanup.

### MD048 - code fence style uses backticks, not tildes

~~~text
This fence should use backticks after cleanup.
```embedded fence-like line
~~~

### MD049 - emphasis style uses underscores, not single asterisks

This emphasis should use underscores after cleanup: *emph*.

## Verify stress tests

### Strict code sentinel (must remain inside a proper fence)

```perl
# STRICT-CODE-SENTINEL-001
print 'ok';
```

### Loose payload sentinel (may move, but must survive)

<code>LOOSE-CODE-SENTINEL-001
`</pre>

## Messy real-world combined regressions

### Malformed language openers and premature pre-close spill

```diff
--- a/docs/file_a.md
+++ b/docs/file_a.md
@@ -1,2 +1,3 @@
- Title: Example
- Version: v0.001
+ Title: Example
+ Version: v0.002
+ Note: Added line
@@ -10,1 +10,2 @@
 Context line that should still be inside the same diff block
+ Another added line
```

```diff
--- a/src/module.pm
+++ b/src/module.pm
@@ -5,1 +5,1 @@
-my \`literal\` backticks
+my `literal` backticks
```

### Loose unified diff run should become a fenced diff block after cleanup

--- a/config/policy.json
+++ b/config/policy.json
@@ -1,1 +1,1 @@
- "allow": false
+ "allow": true
