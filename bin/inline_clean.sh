#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.20.0.

find . -type d -name _Inline
rm -Rf `find . -type d -name _Inline`
