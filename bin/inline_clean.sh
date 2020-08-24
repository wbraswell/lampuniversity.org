#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

# NEED TEST: is there any reason to prefer this line over the ones below?
# find . -name "_Inline" -type d -exec rm -rf {} +

find . -type d -name _Inline
rm -Rf `find . -type d -name _Inline`
