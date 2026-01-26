#!/bin/bash
# Copyright © 2020, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# Text File Line Reversal Script
VERSION='0.001_000'

perl -e 'use strict; use warnings; use Data::Dumper; my @a = (); while (<>) { push @a, $_; } foreach my $s (reverse @a) { print $s; }' < $1
