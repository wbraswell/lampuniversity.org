#!/bin/bash
# Copyright © 2020, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

#sudo apt-get install xclip


if [ -z "$1" ]
then
    echo "Usage: xcopy.sh SOME_SERVER"
    exit
fi

ssh $1 'DISPLAY=:0 xclip -o -selection clipboard' | xclip -i -selection clipboard
