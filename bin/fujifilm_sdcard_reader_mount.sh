#!/bin/bash
# Copyright © 2018, 2019, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# FujiFilm SD Card Reader Mounting Script
VERSION='0.010_000'

# global variables
USER_INPUT=''

DEVICE_LABEL='FujiFilm SD Card Reader'
MOUNT_POINT='/mnt/fujifilm_xp'
USB_DEVICE='__EMPTY__'


# [[[ BEGIN CODE COPIED FROM LAMP_installer.sh ]]]
# [[[ BEGIN CODE COPIED FROM LAMP_installer.sh ]]]
# [[[ BEGIN CODE COPIED FROM LAMP_installer.sh ]]]

# enable extended pattern matching in case statements
shopt -s extglob

D () {  # prompt user for input w/ _D_efault value
    if [[ $1 != '__EMPTY__' ]]; then
        USER_INPUT=$1
        return
    fi
    while true; do
            read -p "Please type the $2, or press <ENTER> for $3... " USER_INPUT
        case $USER_INPUT in
            +([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\~\!\@\#\$\%\^\&\*\(\)\-\_\=\+\[\]\{\}\\\|\/\?\,\.\<\>]) ) echo; break;;
            '' ) echo; USER_INPUT=$3; break;;
            * ) echo "Please type the $2, or press <ENTER> for $3! "; echo;;
        esac
    done
}

S () {  # _S_udo command
# DEV NOTE: attempting to use S() as a shortcut to B() does not work, adds unnecessary logic to B() and incorrectly strips newline characters from commands
# B sudo $@  # WRONG

# DEV NOTE: using just plain $@ works for commands wrapped all in double-quotes such as redirected echo commands (presumably all stored as a single word in only ${01});
# but $@ does NOT work for normal multi-word commands (not just stored in ${01}), must use $COMMAND to handle both cases
    COMMAND=" ${01} ${02} ${03} ${04} ${05} ${06} ${07} ${08} ${09} ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} \
        ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27} ${28} ${29} ${30} ${31} ${32} ${33} ${34} ${35} ${36} ${37} ${38} ${39} \
        ${40} ${41} ${42} ${43} ${44} ${45} ${46} ${47} ${48} ${49} ${50} ${51} ${52} ${53} ${54} ${55} ${56} ${57} ${58} ${59} \
        ${60} ${61} ${62} ${63} ${64} ${65} ${66} ${67} ${68} ${69} ${70} ${71} ${72} ${73} ${74} ${75} ${76} ${77} ${78} ${79} \
        ${80} ${81} ${82} ${83} ${84} ${85} ${86} ${87} ${88} ${89} ${90} ${91} ${92} ${93} ${94} ${95} ${96} ${97} ${98} ${99} "

#    echo '$' $@  # WRONG
    echo '$' $COMMAND

    while true; do
        read -p 'Run above command AS ROOT, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

#    sudo bash -c " $@ "  # WRONG
    sudo bash -c " $COMMAND "
    echo
}

# [[[ END CODE COPIED FROM LAMP_installer.sh ]]]
# [[[ END CODE COPIED FROM LAMP_installer.sh ]]]
# [[[ END CODE COPIED FROM LAMP_installer.sh ]]]


echo
echo
echo '[ Install Utilities, Run Only Once ]'
S apt-get install exfat-fuse exfat-utils expect

echo
echo
echo "[ Unmount Possibly-Existing $DEVICE_LABEL ]"
S umount $MOUNT_POINT

echo
echo
echo '[ List Most Recent Devices ]'
unbuffer dmesg | tail

echo
echo
echo "Find latest block device added in dmesg output above, enter when prompted"

D $USB_DEVICE "$DEVICE_LABEL" '/dev/sdb1'
USB_DEVICE=$USER_INPUT

echo
echo
echo "[ Mount $DEVICE_LABEL ]"
S mount -t exfat $USB_DEVICE $MOUNT_POINT

echo
echo
echo "[ List Files In Mounted $DEVICE_LABEL ]"
find $MOUNT_POINT

