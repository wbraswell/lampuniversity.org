#!/usr/bin/env perl
our $VERSION = 0.100_000;

my $find = shift @ARGV;
my $replace = shift @ARGV;

print 'have $find = ', "\n", $find, "\n\n";
print 'have $replace = ', "\n", $replace, "\n\n";

# BEGIN RAW CODE

foreach $arg (@ARGV) { 
    next if not -f $arg;

    print "opening $arg... ";
    (open my $FH, "<", $arg) or die $!;

    my $s = q{};
    while (<$FH>) { $s .= $_; }
    print "have \$s = $s\n\n";

    print "replacing";
    while ($s =~ m/$find/gxms) {
        $s =~ s/$find/$replace/gxms;
        print ".";
    }
    print "\n";

    (close $FH) or die $!;

    (open $FH, ">", $arg) or die $!;
    print {$FH} $s;
    (close $FH) or die $!;
}

# END RAW CODE
