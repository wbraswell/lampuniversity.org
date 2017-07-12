#!/bin/bash
# Copyright © 2016 2017, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.22.0.

# pre-munged example
# perl -e 'use ExtUtils::MakeMaker; my $s = q{ExtUtils::MakeMaker}; $s =~ s/::/\//g; $s .= q{.pm}; print $INC{$s}, "\n";'

perl -e "use ${1}; my \$s = q{${1}}; \$s =~ s/::/\//g; \$s .= q{.pm}; print \$INC{\$s}, qq{\n};"
