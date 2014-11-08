#!/usr/bin/perl
# Copyright © 2014, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

my $input_module = $ARGV[0];
#print 'have $input_module = ' . $input_module . "\n";

# METHOD 1, does not work with Inline::*
my $eval_string =<< "EOF";
use $input_module;
print '\$$input_module\:\:VERSION = ' . \$$input_module\:\:VERSION . qq{\\n};
EOF

#print "have \$eval_string = \n" . $eval_string . "\n";
eval($eval_string);


# METHOD 2
my $exec_string = q{perl -M} . $input_module . q{\ 999};
#print "have \$exec_string = \n" . $exec_string . "\n";
exec($exec_string);

