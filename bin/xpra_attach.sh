#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.24.0.

if [[ $1 == '' ]]; then
    echo 'Missing Command-Line Argument, Need Machine Name, Exiting'
    exit
fi

xpra attach ssh:$1:100
