# Chat Export Sample (Good)

This file is the expected corrected output for the paired bad sample.

## Inline code examples (correct)

- Path: `docs/file_a.md`
- Command: `tool --flag value`

## Example 1: Correct diff fence, spill repaired

```diff
--- a/docs/file_a.md
+++ b/docs/file_a.md
@@ -1,3 +1,4 @@
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
@@ -5,2 +5,2 @@
-my `literal` backticks
+my `literal` backticks
```

## Example 2: Correct code block fence (no language)

```
for i in 1..3:
    print(i)
```

## Example 3: Correct language code block fence

```perl
my $x = 1;
print $x;
```

## Example 4: Correct unified diff structure

```diff
--- a/docs/file_b.md
+++ b/docs/file_b.md
@@ -2,2 +2,3 @@
 line missing the required diff prefix
- old line
+ 
+ new line
```
