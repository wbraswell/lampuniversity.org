#!/bin/bash
# Copyright © 2020, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

# sudo apt-get install xsltproc

# parser error : internal error: Huge input lookup
# Segmentation fault (core dumped)
# xsltproc $1 -o $1.html

# look Mom, I created a new --parsehuge command-line argument!
# xsltproc --parsehuge $1 -o $1.html
~/repos_gitlab/libxslt-fork-latest/xsltproc/xsltproc --parsehuge $1 -o $1.html
