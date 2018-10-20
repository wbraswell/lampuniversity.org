#!/usr/bin/env perl
# Copyright © 2014, 2015, 2016, 2017, 2018, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.26.0.
our $VERSION = 0.100_000;

my $input_module = $ARGV[0];
#print 'have $input_module = ' . $input_module . "\n";

# METHOD 1, does NOT work with Inline::*
# hard-coded example
# perl -e 'use ExtUtils::MakeMaker; print q{$ExtUtils::MakeMaker::VERSION = } . $ExtUtils::MakeMaker::VERSION . qq{\n};'
my $eval_string =<< "EOF";
use $input_module;
print '\$$input_module\:\:VERSION = ' . \$$input_module\:\:VERSION . qq{\\n};
EOF

print '[[[ METHOD 1 ]]]' . "\n";
#print "have \$eval_string = \n" . $eval_string . "\n";
eval($eval_string);
print "\n";


# METHOD 2, does work with Inline::*, does work with Win32
# perl -e "use Inline::CPP 999;"
my $exec_string = q{perl -e "use } . $input_module . q{ 999;"};
print '[[[ METHOD 2 ]]]' . "\n";
#print "have \$exec_string = \n" . $exec_string . "\n";
exec($exec_string);



# METHOD 3, does work with Inline::*, does NOT work with Win32, unrecoverable compiler error
# hard-coded example
# perl -MInline::CPP\ 999
=DISABLE
my $exec_string = q{perl -M} . $input_module . q{\ 999};
print '[[[ METHOD 3 ]]]' . "\n";
print "have \$exec_string = \n" . $exec_string . "\n";
exec($exec_string);
print "\n";
=cut

