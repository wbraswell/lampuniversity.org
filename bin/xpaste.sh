#!/bin/bash
# Copyright © 2020, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

#sudo apt-get install xclip

if [ -z "$1" ]
then
    echo "Usage: xpaste.sh SOME_SERVER"
    exit
fi

# must have ` &> /dev/null` to avoid xclip hanging
# https://emacs.stackexchange.com/questions/39019/xclip-hangs-shell-command#comment61607_39023
xclip -o -selection clipboard | ssh $1 'DISPLAY=:0 xclip -i -selection clipboard &> /dev/null'
