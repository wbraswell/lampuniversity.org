#!/bin/bash
# Copyright © 2014, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

find $1 -type f -exec wc -l {} \; | awk '{total += $1} END{print total}'
