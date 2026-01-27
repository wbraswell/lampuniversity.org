# Chat Export Sample (Bad)

This file is intentionally malformed. It contains examples of export corruption.

## Inline code examples (incorrect escaping)

- Path: \`docs/file_a.md\`
- Command: \`tool --flag value\`

## Example 1: Malformed diff fence + premature close spill

diff`--- a/docs/file_a.md
+++ b/docs/file_a.md
@@ -1,3 +1,4 @@
- Title: Example
- Version: v0.001
+ Title: Example
+ Version: v0.002
+ Note: Added line
`</pre>
@@ -10,1 +10,2 @@
 Context line that should still be inside the same diff block
+ Another added line

diff`--- a/src/module.pm
+++ b/src/module.pm
@@ -5,2 +5,2 @@
-my \`literal\` backticks
+my `literal` backticks
`</pre>

## Example 2: Non-language code block with <code> opener

<code>for i in 1..3:
    print(i)
```

## Example 3: Language opener with missing newline

perl`my $x = 1;
print $x;
`</pre>

## Example 4: Diff with missing headers, bare @@ separator, and hunk line missing prefix

diff`@@ -2,2 +2,3 @@
 line missing the required diff prefix
- old line
+
+ new line
@@
`</pre>
