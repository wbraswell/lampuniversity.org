#!/bin/bash
# Copyright © 2014, 2017, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
VERSION='0.010_000'

USERNAME=`whoami`

#cd /home/$USERNAME/github_repos/rperl-latest
#pwd
#echo "1 " $1 > /tmp/perlcritic_args.out
#echo "2 " $2 >> /tmp/perlcritic_args.out
#echo "3 " $3 >> /tmp/perlcritic_args.out
#echo "4 " $4 >> /tmp/perlcritic_args.out
#echo "5 " $5 >> /tmp/perlcritic_args.out
#echo "6 " $6 >> /tmp/perlcritic_args.out
#/home/$USERNAME/perl5/bin/perlcritic $1 --verbose "$3" > /tmp/perlcritic.out
#/home/$USERNAME/perl5/bin/perlcritic $1 --verbose "$3"
/home/$USERNAME/perl5/bin/perlcritic $1 $2 "$3"
