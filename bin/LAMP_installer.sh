#!/bin/bash
# Copyright © 2014, 2015, 2016, 2017, 2018, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.24.0.
# LAMP Installer Script
VERSION='0.219_000'


# START HERE: ensure install works, update RPerl installer
# START HERE: ensure install works, update RPerl installer
# START HERE: ensure install works, update RPerl installer


# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!
# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!
# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!

# PRE-PRE-INSTALL: install wget
# sudo apt-get install wget
# OR
# sudo yum install wget

# PRE-INSTALL: download the latest version of this file and make it executable
# wget https://raw.githubusercontent.com/wbraswell/lampuniversity.org/master/bin/LAMP_installer.sh; chmod a+x ./LAMP_installer.sh
# OR
# wget tinyurl.com/lampinstaller; chmod a+x lampinstaller

# enable extended pattern matching in case statements
shopt -s extglob

# global variables
USER_INPUT=''
CURRENT_SECTION=0
OS_CHOICE="UNKNOWN"

# block comment template
: <<'END_COMMENT'
    foo bar bat
END_COMMENT

CURRENT_SECTION_COMPLETE () {
    echo
    echo '[[[ SECTION' $CURRENT_SECTION 'COMPLETE ]]]'
    echo
    CURRENT_SECTION=$((CURRENT_SECTION+1))
    while true; do
        read -p "Continue to section $CURRENT_SECTION, yes or no?  [yes] " -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; exit;;
            y|Y ) echo; echo; break;;
#            ' ' ) echo;;  # NEED FIX: space ' ' should not trigger empty ''
            ''  ) echo; break;;
            *   ) echo;;
        esac
    done
}

SOURCE () {  # source (.) with error check & note
    echo '$ source' $1
    while true; do
        read -p 'Run above command, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

    if [ -f "$1" ]; then
        source $1
        echo '[ NOTE: When This Installer Exits, You Must Then Copy & Re-Run The Above Command, Or Log Out & Log Back In If The File Is ~/.bashrc ]'
    else
        echo 'Cannot source file ' $1 ' because such file does not exist'
    fi
}

CD () {  # _C_hange _D_irectory with error check
    CD_DIR="${1/#\~/$HOME}"  # replace ~/FOO with $HOME/FOO to avoid 'directory not found' error
    echo '$ cd' $CD_DIR
    while true; do
        read -p 'Run above command, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

    if [ -d "$CD_DIR" ]; then
        cd $CD_DIR
    else
        echo 'Cannot change directory to ' $CD_DIR ' because such directory does not exist'
    fi
}

C () {  # _C_onfirm user action
    echo $1
    while true; do
        read -p 'Did you do it, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; echo $1;;
            y|Y ) echo; echo; break;;
#            ' ' ) echo;;  # NEED FIX: space ' ' should not trigger empty ''
            ''  ) echo; break;;
            *   ) echo;;
        esac
    done
}

P () {  # _P_rompt user for input
    if [[ $1 != '__EMPTY__' ]]; then
        USER_INPUT=$1
        return
    fi
    while true; do
            read -p "Please type the $2... " USER_INPUT
        case $USER_INPUT in
            # do not force input to start with lowercase letter or forward slash; do not limit any keyboard characters because of passwords
#            [abcdefghijklmnopqrstuvwxyz/]+([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./]) ) echo; break;;
            +([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\~\!\@\#\$\%\^\&\*\(\)\-\_\=\+\[\]\{\}\\\|\/\?\,\.\<\>]) ) echo; break;;
            * ) echo "Please type the $2! "; echo;;
        esac
    done
}

N () {  # prompt user for _N_umeric input
    if [[ $1 != '__EMPTY__' ]]; then
        USER_INPUT=$1
        return
    fi
    while true; do
            read -p "Please type the $2... " USER_INPUT
        case $USER_INPUT in
            [0123456789]+([0123456789.]) ) echo; break;;
            * ) echo "Please type the $2! "; echo;;
        esac
    done
}

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
    B sudo $@
}

B () {  # _B_ash command
    COMMAND="       ${02} ${03} ${04} ${05} ${06} ${07} ${08} ${09} ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} \
        ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27} ${28} ${29} ${30} ${31} ${32} ${33} ${34} ${35} ${36} ${37} ${38} ${39} \
        ${40} ${41} ${42} ${43} ${44} ${45} ${46} ${47} ${48} ${49} ${50} ${51} ${52} ${53} ${54} ${55} ${56} ${57} ${58} ${59} \
        ${60} ${61} ${62} ${63} ${64} ${65} ${66} ${67} ${68} ${69} ${70} ${71} ${72} ${73} ${74} ${75} ${76} ${77} ${78} ${79} \
        ${80} ${81} ${82} ${83} ${84} ${85} ${86} ${87} ${88} ${89} ${90} ${91} ${92} ${93} ${94} ${95} ${96} ${97} ${98} ${99} "
    if [[ $1 = 'sudo' ]]; then
        COMMAND_FULL="sudo bash -c ' $COMMAND '"
        PROMPT='Run above command AS ROOT, yes or no?  [yes] '
    else
        COMMAND="$1 $COMMAND"
        COMMAND_FULL="bash -c ' $COMMAND '"
        PROMPT='Run above command, yes or no?  [yes] '
    fi
    echo '$' $COMMAND

    while true; do
        read -p "$PROMPT" -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

#    $COMMAND_FULL  # ERROR: -c: line 0: unexpected EOF while looking for matching `''
    if [[ $1 = 'sudo' ]]; then
        sudo bash -c " $COMMAND "
    else
        bash -c " $COMMAND "
    fi
    echo
}

VERIFY_OS_CHOICE() {
    local OS_REQ="$1"
    local CHOICE="$OS_CHOICE"

    local GUESS='UNKNOWN'
    if [[ -f "/etc/redhat-release" ]]; then
        GUESS='CENTOS'
    elif [[ -f "/etc/debian_version" ]]; then
        GUESS='UBUNTU'
    fi

    if [[ "$GUESS" != "$CHOICE" ]]; then
        PROMPT="NOT OK: OS_CHOICE is $CHOICE but I think you are running $GUESS ! Proceed? "
        while true; do
            read -p "$PROMPT" -n 1 PROMPT_INPUT
            case $PROMPT_INPUT in
                n|N ) echo; echo; exit 1;;
                y|Y ) echo; break;;
                * ) echo;;
            esac
        done
    fi

    if [[ "$OS_REQ" != "$CHOICE" ]]; then
        PROMPT="NOT OK: OS must be $OS_REQ but you chose $OS_CHOICE! Proceed Anyway? "
        while true; do
            read -p "$PROMPT" -n 1 PROMPT_INPUT
            case $PROMPT_INPUT in
                n|N ) echo; echo; exit 1;;
                y|Y ) echo; break;;
                * ) echo;;
            esac
        done
        echo
    fi
}

VERIFY_CENTOS() {
    VERIFY_OS_CHOICE 'CENTOS'
}

VERIFY_UBUNTU() {
    VERIFY_OS_CHOICE 'UBUNTU'
}

echo "[[[<<< LAMP Installer Script v$VERSION >>>]]]"
echo
echo '  [[[<<< Tested Using Fresh Installs >>>]]]'
echo
echo 'Xubuntu v14.04.2 (Trusty Tahr)'
echo 'Xubuntu v16.04.4 (Xenial Xerus)'
echo
echo  '          [[[<<< Main Menu >>>]]]'
echo
echo  '        <<< LOCAL CLI SECTIONS >>>'
echo \ '0. [[[        LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
echo \ '1. [[[        LINUX, CONFIGURE CLOUD NETWORKING ]]]'
echo \ '2. [[[ UBUNTU LINUX, USB INSTALL, FIX BROKEN SWAP DEVICE ]]]'
echo \ '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
echo \ '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
echo \ '5. [[[ UBUNTU LINUX, UPGRADE ENTIRE OPERATING SYSTEM OR ALL PACKAGES ]]]'
echo \ '6. [[[        LINUX, INSTALL BASE CLI OPERATING SYSTEM PACKAGES ]]]'
echo \ '7. [[[ UBUNTU LINUX, INSTALL & TEST CLAMAV ANTI-VIRUS ]]]'
echo \ '8. [[[        LINUX, INSTALL LAMP UNIVERSITY TOOLS ]]]'
echo \ '9. [[[ UBUNTU LINUX, INSTALL HEIRLOOM TOOLS (including bdiff) ]]]'
echo  '10. [[[ UBUNTU LINUX, INSTALL BROADCOM B43 WIFI ]]]'
echo  '11. [[[ UBUNTU LINUX, PERFORMANCE BENCHMARKING ]]]'
echo
echo  '        <<< LOCAL GUI SECTIONS >>>'
echo  '12. [[[ UBUNTU LINUX, INSTALL BASE GUI OPERATING SYSTEM PACKAGES ]]]'
echo  '13. [[[ UBUNTU LINUX, INSTALL EXTRA GUI OPERATING SYSTEM PACKAGES ]]]'
echo  '14. [[[ UBUNTU LINUX, INSTALL XPRA ]]]'
echo  '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
echo  '16. [[[ UBUNTU LINUX, UNINSTALL HUD & BLUETOOTH & MODEMMANAGER & GVFS ]]]'
echo  '17. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER ]]]'
echo  '18. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
echo  '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
echo
echo  '         <<< PERL & RPERL SECTIONS >>>'
echo  '20. [[[        LINUX,   INSTALL  PERL DEPENDENCIES ]]]'
echo  '21. [[[        LINUX,   INSTALL SINGLE-USER PERL LOCAL::LIB  & CPANM ]]]'
echo  '22. [[[        LINUX,   INSTALL SINGLE-USER PERLBREW         & CPANM ]]]'
echo  '23. [[[        LINUX,   INSTALL SYSTEM-WIDE PERL FROM SOURCE & CPANM ]]]'
echo  '24. [[[        LINUX,   INSTALL SYSTEM-WIDE SYSTEM PERL      & CPANM ]]]'
echo  '25. [[[        LINUX,   INSTALL RPERL DEPENDENCIES ]]]'
echo  '26. [[[  PERL,          INSTALL RPERL, LATEST   STABLE VIA CPAN ]]]'
echo  '27. [[[  PERL,          INSTALL RPERL, LATEST UNSTABLE VIA GITHUB ]]]'
echo  '28. [[[ RPERL,          RUN COMPILER TESTS ]]]'
echo  '29. [[[ RPERL,          INSTALL RPERL FAMILY & RUN DEMOS ]]]'
echo
echo  '         <<< SERVICE SECTIONS >>>'
echo  '30. [[[ UBUNTU LINUX,   INSTALL NFS ]]]'
echo  '31. [[[ UBUNTU LINUX,   INSTALL APACHE & MOD_PERL ]]]'
echo  '32. [[[ APACHE,         CONFIGURE DOMAIN(S) ]]]'
echo  '33. [[[ UBUNTU LINUX,   INSTALL MYSQL & PHPMYADMIN ]]]'
echo  '34. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
echo  '35. [[[ UBUNTU LINUX,   INSTALL WEBMIN ]]]'
echo  '36. [[[ UBUNTU LINUX,   INSTALL POSTFIX ]]]'
echo  '37. [[[ PERL,           INSTALL     LATEST CATALYST ]]]'
echo  '38. [[[ UBUNTU LINUX,   INSTALL NON-LATEST CATALYST ]]]'
echo  '39. [[[ PERL,           CHECK CATALYST VERSIONS ]]]'
echo  '40. [[[ PERL,           INSTALL RAPIDAPP ]]]'
echo  '41. [[[ UBUNTU LINUX,   INSTALL SHINYCMS DEPENDENCIES ]]]'
echo  '42. [[[ PERL SHINYCMS,  INSTALL SHINYCMS DEPENDENCIES & SHINYCMS ]]]'
echo  '43. [[[ PERL SHINYCMS,  CREATE DATABASE & EDIT MYSHINYTEMPLATE FILES ]]]'
echo  '44. [[[ PERL SHINYCMS,  BUILD DEMO DATA & RUN TESTS ]]]'
echo  '45. [[[ PERL SHINYCMS,  BACKUP & RESTORE DATABASE ]]]'
echo  '46. [[[ PERL SHINYCMS,  CONFIGURE APACHE MOD_FASTCGI ]]]'
echo  '47. [[[ PERL SHINYCMS,  CONFIGURE APACHE MOD_PERL ]]]'
echo  '48. [[[ PERL SHINYCMS,  CREATE    APACHE DIRECTORIES & ENABLE STATIC  PAGE ]]]'
echo  '49. [[[ PERL SHINYCMS,  CONFIGURE APACHE PERMISSIONS & ENABLE DYNAMIC PAGES ]]]'
echo  '50. [[[ PERL SHINYCMS,  CONFIGURE SHINY ]]]'
echo
echo  '51. [[[ PERL CLOUDFORFREE, FOOOOOO ]]]'
echo
echo  '60. [[[ UBUNTU LINUX,   INSTALL MONGODB ]]]'
echo

while true; do
    read -p 'Please type your chosen main menu section number, or press <ENTER> for 0... ' MENU_CHOICE
    case $MENU_CHOICE in
        [0123456789]|[1234][0123456789]|5[01]|60 ) echo; break;;
        '' ) echo; MENU_CHOICE=0; break;;
        * ) echo 'Please choose a section number from the menu!'; echo;;
    esac
done

CURRENT_SECTION=$MENU_CHOICE

echo  '          [[[<<< Machine Menu >>>]]]'
echo
echo \ '0. [[[      NEW MACHINE; SERVER; REMOTE CLOUD HOST ]]]'
echo \ '1. [[[ EXISTING MACHINE; CLIENT; LOCAL USER SYSTEM ]]]'
echo

while true; do
    read -p 'Please type your machine menu choice number, or press <ENTER> for 0... ' MACHINE_CHOICE
    case $MACHINE_CHOICE in
        [01] ) echo; break;;
        '' ) echo; MACHINE_CHOICE=0; break;;
        * ) echo 'Please choose a number from the menu!'; echo;;
    esac
done

echo  '          [[[<<< OS Menu >>>]]]'
echo
echo \ '0. [[[           UBUNTU       ]]]'
echo \ '1. [[[           CENTOS       ]]]'
echo

while true; do
   read -p 'Please type your OS menu choice number, or press <ENTER> for 0... ' OS_CHOICE
   case $OS_CHOICE in
       0 ) echo; OS_CHOICE='UBUNTU'; break;;
       1 ) echo; OS_CHOICE='CENTOS'; break;;
       '' ) echo; OS_CHOICE='UBUNTU'; break;;
       * ) echo 'Please choose a number from the menu!'; echo;;
   esac
done

# SECTION 0 VARIABLES
EDITOR='__EMPTY__'
USERNAME='__EMPTY__'
IP_ADDRESS='__EMPTY__'
DOMAIN_NAME='__EMPTY__'

if [ $MENU_CHOICE -le 0 ]; then
    echo '0. [[[ LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '0. [[[ NEW MACHINE; SERVER; REMOTE CLOUD HOST ]]]'
        echo '[ Reset root Password ]'
        S passwd  # NEED FIX: disable root account???
        echo '[ Remove Default User ]'
        S userdel user
        S rm -Rf /home/user
        echo '[ Create New User ]'
        P $USERNAME 'new username to be created'
        USERNAME=$USER_INPUT
        S useradd $USERNAME
        S passwd $USERNAME
        S cp -a /etc/skel /home/$USERNAME
        S chown -R $USERNAME.$USERNAME /home/$USERNAME
        S chmod -R go-rwx /home/$USERNAME
        S chsh -s /bin/bash $USERNAME
        echo "[ Add $USERNAME To User Group sudo, Allows Running root Commands (Like update-manager) Via sudo In xpra ]"
        S usermod -aG sudo $USERNAME 
        echo '[ Cloud At Cost Only, Delete Installation Template File ]'
        S rm -f linux-ubuntu-template.sh
        echo '[ Take Note Of IP Address For Use On Existing Machine ]'
        B ifconfig
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo '1. [[[ EXISTING MACHINE; CLIENT; LOCAL USER SYSTEM ]]]'
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        N $IP_ADDRESS "new machine's IP address (ex: 123.145.167.189)"
        IP_ADDRESS=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        echo '[ Manually Add New Machine IP Address & Domain Name ]'
        echo '[ Copy Data From The Following Line ]'
        echo $IP_ADDRESS $DOMAIN_NAME
        echo
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        S $EDITOR /etc/hosts
        echo '[ Enable Passwordless SSH ]'
        echo '[ Do Not Re-Run ssh-keygen If Already Done In The Past ]'
        B ssh-keygen
        B ssh-copy-id $USERNAME@$DOMAIN_NAME
        echo '[ You May Be Prompted Once To Unlock Keyring, Passwordless Thereafter ]'
        B ssh $USERNAME@$DOMAIN_NAME
        B ssh $USERNAME@$DOMAIN_NAME
        echo '[ Copy Run Commands & Config Files To New Machine: bash, vi, git ]'
        B scp ~/.bashrc ~/.vimrc ~/.gitconfig $DOMAIN_NAME:~/
    fi
    CURRENT_SECTION_COMPLETE
fi

# START HERE: add non-fully-qualified hostname to 127.0.1.1 entry in /etc/hosts, to allow for gogetspace forcing overwrite of /etc/hostname
# START HERE: add non-fully-qualified hostname to 127.0.1.1 entry in /etc/hosts, to allow for gogetspace forcing overwrite of /etc/hostname
# START HERE: add non-fully-qualified hostname to 127.0.1.1 entry in /etc/hosts, to allow for gogetspace forcing overwrite of /etc/hostname

if [ $MENU_CHOICE -le 1 ]; then
    echo '1. [[[ LINUX, CONFIGURE CLOUD NETWORKING ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine First..."
        S mv /tmp/hosts /etc/hosts
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        echo '[ Manually Modify Hosts File; Update localhost Entry, Disable Public Entry If Present ]'
        echo '[ Example File Content On The Following Lines ]'
        echo "127.0.1.1       $DOMAIN_NAME  # === EDIT THIS LINE TO BE YOUR LOCAL HOSTNAME AKA FULLY-QUALIFIED DOMAIN NAME, AS SHOWN HERE ==="
        echo '# === COMMENT OR REMOVE LOCAL HOSTNAME(S) IF APPEARING BELOW ==='
        echo '...'
        echo '111.222.111.222 foo.com  # ignore this entry'
        echo "#123.123.123.123 $DOMAIN_NAME  # === THIS IS THE ENTRY WHICH NEEDS TO BE DISABLED, AS SHOWN HERE ==="
        echo '100.200.100.200 bar.com  # ignore this entry'
        echo '...'
        echo
        S $EDITOR /etc/hosts
        echo '[ Modify Hostname File ]'
        S "echo $DOMAIN_NAME > /etc/hostname"  # DEV NOTE: must wrap redirects in quotes
        echo '[ Modify Network Interfaces File, Append Google DNS Servers To End Of File ]'
        S 'echo -e "\ndns-nameservers 8.8.8.8 8.8.4.4" >> /etc/network/interfaces'  # DEV NOTE: must wrap redirects in quotes
        echo '[ You MUST Reboot Now To Enable New Hostname ]'
        echo '[ Then Check /etc/resolv.conf File To Confirm The Following Lines Have Been Appended ]'
        echo 'nameserver 8.8.8.8'
        echo 'nameserver 8.8.4.4'
        echo
        S reboot
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        B scp /etc/hosts $DOMAIN_NAME:/tmp/hosts
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now..."
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 2 VARIABLES
SWAP_DEVICE='__EMPTY__'

if [ $MENU_CHOICE -le 2 ]; then
    echo '2. [[[ UBUNTU LINUX, USB INSTALL, FIX BROKEN SWAP DEVICE ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: This section only applies to Ubuntu installed from a USB drive! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ During Installation, Swap May Be Created On /dev/sda5 Device, Determine Device ]'
        B ls -l /dev/sd*
        D $SWAP_DEVICE "new machine's USB installation swap device file" '/dev/sda5'
        SWAP_DEVICE=$USER_INPUT
        echo '[ Copy UUID ]'
        B blkid $SWAP_DEVICE
        echo '[ Manually Update UUID Entries In /etc/fstab And/Or /etc/crypttab Files To Reflect New /dev/sd* Drive Letters ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        S $EDITOR /etc/fstab
        S $EDITOR /etc/crypttab
        echo '[ View Current Swap Summary, Turn Current Swap Devices Off, Turn Updated Swap Devices On, View Updated Swap Summary ]'
        S swapon -s
        S swapoff -a
        S swapon -a
        S swapon -s
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
        echo
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 3 ]; then
    echo '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ NOTE: Check For The Following Error When You Run The Next Command... "perl: warning: Setting locale failed." ]'
        B 'perl -e exit'
        echo '[ If You Saw The locale Error, Then Run The Next 2 Commands To Generate & Reconfigure Locales ]'
        S locale-gen en_US.UTF-8
        S dpkg-reconfigure locales
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 4 ]; then
    echo '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: THIS SECTION IS EXPERIMENTAL!  This should NOT be done if you are not sure about what you are doing!!! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install ubuntu-sdk
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list
# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list
# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list

if [ $MENU_CHOICE -le 5 ]; then
    echo '5. [[[ UBUNTU LINUX, UPGRADE ENTIRE OPERATING SYSTEM OR ALL PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: THIS SECTION IS EXPERIMENTAL!  This should NOT be done if you are not sure about what you are doing!!! ]'
        echo '[ WARNING: You should probably not mix do-release-upgrade with the following apt-get & aptitude commands. ]'
        C 'Please read the warnings above.  Seriously.'
        # NEED FIX: gvim AKA vim-gtk3 Has Unmet Dependencies After `apt-get upgrade` In Ubuntu 16.04.1 Xenial
        # https://bugs.launchpad.net/ubuntu/+source/vim/+bug/1613949
        echo '[ Upgrade Entire Operating System Distribution Release ]'
        S apt-get update
        S apt-get install ubuntu-release-upgrader-core
        S do-release-upgrade
        echo '[ Update Package List & Upgrade All Packages ]'
        S apt-get update
        S apt-get upgrade
        echo '[ Check Install, Confirm No Errors, Only Non-Upgraded Packages Allowable ]'
        S apt-get -f install
        echo '[ Review Non-Upgraded (Kept Back) Packages, Confirm Suitability For Safe-Upgrade ]'
        S apt-get upgrade 
        S apt-get install aptitude
        S aptitude safe-upgrade
        echo '[ Check Install, Confirm No Errors & Nothing Remaining To Upgrade ]'
        S apt-get -f install
        S apt-get upgrade
        echo '[ Clean Unneeded Files & Reboot ]'
        S apt-get autoremove
        S reboot
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 6 ]; then
    echo '6. [[[ LINUX, INSTALL BASE CLI OPERATING SYSTEM PACKAGES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get update
            S apt-get -f install
            echo '[ UBUNTU ONLY: General Tools: g++ make ssh perl cpan perl-doc vim git htop linuxlogo lynx traceroute screen ifconfig ]'
            echo '[ UBUNTU ONLY: LAMP University Tools Requirements: zip unzip ]'
            S apt-get install g++ make ssh perl perl-doc vim git htop linuxlogo lynx traceroute screen net-tools zip unzip
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS
            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
            echo '[ CENTOS ONLY: General Tools: g++ make ssh perl cpan perl-doc vim git htop linuxlogo lynx traceroute screen ifconfig ]'
            echo '[ CENTOS ONLY: LAMP University Tools Requirements: zip unzip ]'
            S yum install gcc-c++ make openssh openssh-clients perl perl-core perl-CPAN perl-Pod-Perldoc vim-enhanced git lynx traceroute screen net-tools zip unzip
            S yum install epel-release
            S yum install htop linux_logo
            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
        fi

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 7 ]; then
    echo '7. [[[ UBUNTU LINUX, INSTALL & TEST CLAMAV ANTI-VIRUS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ NOTE: ClamAV should be skipped on low-memory systems. ]'
        C 'Please read the note above.'
        S apt-get install clamav clamav-daemon 
        echo '[ If you see the error below, then freshclam is already running automatically ]'
        echo '[ NOTE: Check For The Following Error When You Run The Next Command, If Present Then freshclam Is Already Running & You May Ignore Error... "ERROR: /var/log/clamav/freshclam.log is locked by another process" ]'
        echo
        S freshclam
        S clamscan -r /home
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        S "cd /home/$USERNAME; wget http://www.eicar.org/download/eicar.com"
        S clamscan -r /home
        S clamscan --infected --remove --recursive /home
        S clamscan -r /home
        S /etc/init.d/clamav-daemon start
        S /etc/init.d/clamav-daemon status
        S /etc/init.d/clamav-freshclam start
        S /etc/init.d/clamav-freshclam status
        S clamdscan -V
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 8 ]; then
    echo '8. [[[ LINUX, INSTALL LAMP UNIVERSITY TOOLS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        B wget https://github.com/wbraswell/lampuniversity.org/archive/master.zip
        B mv master.zip lampuniversity.org-master.zip
        B unzip lampuniversity.org-master.zip
        B mkdir ~/bin
        B cp lampuniversity.org-master/bin/* ~/bin
        B rm -Rf lampuniversity.org*
        B hash -r
        C 'Please Log Out And Log Back In, Which Should Reset The $PATH Environmental Variable To Include The Newly-Created ~/bin Directory, Then Come Back To This Point.'
        echo '[ Test LAMP University Tools, Top Memory Script ]'
        B topmem.sh
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 9 ]; then
    echo '9. [[[ UBUNTU LINUX, INSTALL HEIRLOOM TOOLS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ NOTE: Only install the Heirloom Tools if you specifically need bdiff or one of the other tools. ]'
        C 'Please read the note above.'
        S apt-get install zlib1g-dev libncurses5-dev libssl-dev
        S wget https://github.com/halcyon/ubuntu-heirloom/archive/master.zip
        S mv master.zip ubuntu-heirloom-master.zip
        S unzip ubuntu-heirloom-master.zip
        S 'cd ubuntu-heirloom-master; ./build.sh'
        S rm -Rf ubuntu-heirloom-master*
        echo '[ Test Heirloom Tools, bdiff Script ]'
        B /usr/5bin/bdiff
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 10 ]; then
    echo '10. [[[ UBUNTU LINUX, INSTALL BROADCOM B43 WIFI ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: The following 2 apt-get commands are only for affected machines such as Dell Latitude D430 & D630. ]'
        echo '[ Symptoms include no working wireless support, and the inability to shut down or reboot or suspend. ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get remove bcmwl-kernel-source dkms
        S apt-get install firmware-b43-installer
        echo '[ WARNING: The following 1 apt-get command is only for affected machines with a network card containing the Realtek 8812 chipset such as a D-Link DWA-182. ]'
        S apt-get install rtl8812au-dkms
        S reboot
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 11 VARIABLES
CPUMINER_SERVER='__EMPTY__'
CPUMINER_USERNAME='__EMPTY__'
CPUMINER_PASSWORD='__EMPTY__'

if [ $MENU_CHOICE -le 11 ]; then
    echo '11. [[[ UBUNTU LINUX, PERFORMANCE BENCHMARKING ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Linux Logo Basic Performance Data ]'
        B linuxlogo
        echo '[ CPU Miner Advanced Performance Benchmark ]'
        # NEED UPDATE: does cpuminer still have the same syntax used below?
        S apt-get install libcurl4-openssl-dev libncurses5-dev pkg-config automake yasm
        B git clone https://github.com/pooler/cpuminer.git
        B 'cd cpuminer; ./autogen.sh; ./configure CFLAGS="-O3"; make'
        P $CPUMINER_SERVER "CPU Miner Server Hostname"
        CPUMINER_SERVER=$USER_INPUT
        P $CPUMINER_USERNAME "CPU Miner Username"
        CPUMINER_USERNAME=$USER_INPUT
        P $CPUMINER_PASSWORD "CPU Miner Password"
        CPUMINER_PASSWORD=$USER_INPUT
        B "cd cpuminer; ./minerd --url=http://$CPUMINER_SERVER --userpass=$CPUMINER_USERNAME:$CPUMINER_PASSWORD"
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 12 VARIABLES
UBUNTU_RELEASE_NAME='__EMPTY__'

if [ $MENU_CHOICE -le 12 ]; then
    echo '12. [[[ UBUNTU LINUX, INSTALL BASE GUI OPERATING SYSTEM PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $UBUNTU_RELEASE_NAME 'Ubuntu release name (trusty, xenial, etc.)' 'xenial'
        UBUNTU_RELEASE_NAME=$USER_INPUT
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get update
        S apt-get -f install
        echo '[ X-Windows Installation Triggers: xterm xfce4-terminal ]'
        echo '[ Basic X-Windows Testing: x11-apps (contains xclock) ]'
        echo '[ General Tools: gkrellm hexchat firefox chromium-browser update-manager indicator-multiload unetbootin ]'
        S apt-get install xterm xfce4-terminal x11-apps gkrellm hexchat firefox chromium-browser update-manager indicator-multiload unetbootin
        echo '[ OPTIONAL: Adobe Pepper Flash Plugin, Must Manually Enable Canonical Partner Repository, Then Disable When Done ]'
        echo '[ Copy Data From The Following Lines, Then Paste Into The Apt Config File /etc/apt/sources.list, OR Uncomment Equivalent Existing Lines ]'
        echo "deb http://archive.canonical.com/ubuntu $UBUNTU_RELEASE_NAME partner     # needed for Adobe Pepper Flash Plugin"
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        S apt-get install adobe-flashplugin
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get -f install
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 13 ]; then
    echo '13. [[[ UBUNTU LINUX, INSTALL EXTRA GUI OPERATING SYSTEM PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Google Chrome, Add Package Repository ]'
        S 'wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'
        S 'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get update
        S apt-get -f install
        echo '[ Select Individual Packages To Install ]'
        S apt-get install google-chrome-stable
        S apt-get install libreoffice
        S apt-get install pithos
        S apt-get install gimp
        S apt-get install tesseract-ocr gimagereader
        S apt-get install fuse go-mtpfs
        S apt-get install eclipse-cdt
        echo '[ Eclipse EPIC Perl Plugin ]'
        echo '[ DIRECTIONS: Run Eclipse -> Help -> Install New Software -> Add -> http://www.epic-ide.org/updates -> Install ]'
        echo
        echo '[ Eclipse WTP Web Tools HTML / CSS / JavaScript Plugin ]'
        echo '[ DIRECTIONS: Run Eclipse -> Help -> Install New Software -> Add -> http://download.eclipse.org/webtools/repository/juno/ -> Install ]'
        echo '[ Select Only Eclipse Web Developer Tools, JavaScript Development Tools, Web Page Editor ]'
        echo
        echo '[ Eclipse vi Plugin ]'
        S 'wget http://www.viplugin.com/files/viPlugin_1.20.3.zip; unzip viPlugin_1.20.3.zip; mv features/* ~/.eclipse/org.eclipse.*/features/; mv plugins/* ~/.eclipse/org.eclipse.*/plugins; rm -Rf features plugins'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 14 VARIABLES
LOCAL_HOSTNAME='__EMPTY__'

if [ $MENU_CHOICE -le 14 ]; then
    echo '14. [[[ UBUNTU LINUX, INSTALL XPRA ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine First..."
        echo '[ Test X-Windows Single-Session Connection ]'
        P $LOCAL_HOSTNAME "Existing Machine's Local Hostname"
        LOCAL_HOSTNAME=$USER_INPUT
        B "export DISPLAY=$LOCAL_HOSTNAME:0.0; xclock"
        echo '[ Install, Start, Test xpra Multi-Session Service ]'
        echo '[ NOTE: If You Have xpra Installation Issues, Please See The Directions In This Same Section 14 For Existing Machines ]'
        S apt-get install xpra
        B 'xpra start :100 --start-child=xfce4-terminal'
        echo '[ Test xpra Multi-Session Connection ]'
        echo '[ Please Run The Next Command, Then While xclock Is Running, Go Back To Existing Machine, Connect To xpra, And Close xclock When Visible ]'
        B 'export DISPLAY=:100.0; xclock'
        echo '[ Default Enable Output To xpra Multi-Session Connection ]'
        B 'echo -e "\n# enable output to XPRA persistent X server\nexport DISPLAY=:100.0\n" >> ~/.bashrc'
        echo '[ Optionally Stop xpra Service ]'
        B xpra stop
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        C "Please configure your local firewall to open port 6000 for both UDP & TCP..."
        echo '[ Determine Display Manager, Either gdm OR lightdm ]'
        B 'ps aux | grep gdm'
        B 'ps aux | grep lightdm'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ NOTE: This sub-section is only for machines running the gdm display manager, NOT for those running lightdm! ]'
        echo '[ gdm Only: Manually Edit gdm Config File To Match Following Lines ]'
        echo '...'
        echo '[security]'
        echo 'DisallowTCP=false'
        echo '...'
        echo
        S $EDITOR /etc/gdm/custom.conf
        echo '[ gdm Only: Restart gdm Service ]'
        echo '[ WARNING: The following command will restart your X-Windows GUI system software! Save your work and close all GUI programs! ]'
        C 'Please read the warning above.  Seriously.'
        S /etc/init.d/gdm restart
        echo

        echo '[ NOTE: This sub-section is only for machines running the lightdm display manager, NOT for those running gdm! ]'
        echo '[ lightdm Only: Manually Edit lightdm Config File To Match Following Lines ]'
        echo '...'
        echo '[SeatDefaults]'
#        echo '#greeter-session=unity-greeter'  # NEED ANSWER: is this necessary?
#        echo '#user-session=ubuntu'  # NEED ANSWER: is this necessary?
        echo 'xserver-allow-tcp=true'
        echo '...'
        echo
        S $EDITOR /etc/lightdm/lightdm.conf
        echo '[ lightdm Only: Restart lightdm Service ]'
        echo '[ WARNING: The following command will restart your X-Windows GUI system software! Save your work and close all GUI programs! ]'
        C 'Please read the warning above.  Seriously.'
        S /etc/init.d/lightdm restart
        echo

        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT

        echo '[ Enable X-Windows Single-Session Connection ]'
        B "xhost +$DOMAIN_NAME"
        echo '[ Install xpra Multi-Session Service ]'
        echo '[ NOTE: Only use this if all your Ubuntu installations are the same major version, or if you are on the machine with the oldest version now. ]'
        S apt-get install xpra
        echo '[ NOTE: Use this if you are in Ubuntu v16.04 Xenial now and your older machines are Ubuntu Trusty v14.04 running xpra v0.12.3 ]'
        B wget http://xpra.org/dists/xenial/main/binary-amd64/xpra_0.14.35-1_amd64.deb  # XXXcompatible with xpra v0.12.3, does install on Ubuntu v16.04
        S apt-get install gdebi
        S gdebi-gtk ./xpra_0.12.3-1_amd64.deb
        B rm xpra_0.14.35-1_amd64.deb
        echo
        echo '[ NOTE: If you experienced issues installing xpra via the 2 methods above, then you may have an old machine. ]'
        echo '[ If this is the case, then complete the URL below, download the proper .deb file, and run the gdebi-gtk command (not dpkg) to install the .deb file & dependencies. ]'
        echo 'http://xpra.org/dists/USERDIST/main/USERARCH'
        echo '$ gdebi-gtk ./xpra_SOMEVERSION_USERARCH.deb'
        echo
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now... Then Come Back To This Point."
        echo '[ Test xpra Multi-Session Connection, Try The Following Command Inside The xpra X-Terminal ]'
        echo 'gkrellm > /dev/null 2>&1 &'
        B "xpra attach ssh:$DOMAIN_NAME:100"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 15 VARIABLES
ISO_MOUNT_POINT='__EMPTY__'

if [ $MENU_CHOICE -le 15 ]; then
    echo '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: This sections is only for use with Ubuntu Linux installed inside a VirtualBox VM! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install dkms
        C 'Now Download VBoxGuestAdditions.iso From http://download.virtualbox.org/virtualbox/ And Mount ISO'
        P $ISO_MOUNT_POINT "ISO Mount Point, Directory's Full Path"
        ISO_MOUNT_POINT=$USER_INPUT
        S "cd $ISO_MOUNT_POINT; sh ./VBoxLinuxAdditions.run"
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 16 ]; then
    echo '16. [[[ UBUNTU LINUX, UNINSTALL HUD & BLUETOOTH & MODEMMANAGER & GVFS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Uninstall HUD To Free System Memory ]'
        S apt-get purge hud
        echo '[ Uninstall Bluetooth Support To Free System Memory ]'
        S apt-get purge blueman bluez bluez-obexd
        echo '[ Uninstall Mobile Broadband ModemManager To Free System Memory ]'
        S apt-get purge modemmanager
        echo '[ Uninstall Or Disable GVFS To Speed Up Thunar File Explorer ]'
        echo '[ OPTION 1 ONLY: Uninstall GVFS Completely ]'
        S apt-get purge gvfs-daemons
        echo '[ OPTION 2 ONLY: Disable GVFS Network Mounting ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ OPTION 2 ONLY: Manually Edit GVFS Config File, Copy Config Entry From The Following Line ]'
        echo 'AutoMount=false'
        echo
        S $EDITOR /usr/share/gvfs/mounts/network.mount
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 17 ]; then
    echo '17. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER & CONFIGURE SPACE TELESCOPE IMAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: The following command is only for affected machines. ]'
        echo '[ Symptoms include the mouse cursor disappears after screensaver. (CTRL-ALT-F1 for temporary fix.) ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get remove light-locker
        echo '[ Download & Install Space Telescope Images ]'
#        B 'wget https://www.spacetelescope.org/static/images/zip/top100/top100-large.zip; unzip top100-large.zip'  # disabled due to bad files
        # alternative manual download source:  http://www.jpl.nasa.gov/spaceimages/searchwp.php?category=featured
        B 'wget https://raw.githubusercontent.com/wbraswell/spacetelescope.org-mirror/master/top100_cleaned_scaled.zip; unzip top100_cleaned_scaled.zip'
        B 'mkdir ~/.xscreensaver_glslideshow; mv top100/ ~/.xscreensaver_glslideshow/'
        S apt-get install xscreensaver xscreensaver-data-extra xscreensaver-gl
        echo '[ Configure Screensaver ]'
        echo "Click main Xubuntu app menu -> Settings -> Screensaver -> The XScreenSaver daemon doesn't seem to be running on display \":0.0\"."
        echo '-> Launch it now?  OK -> Blank & Lock After 10 Mins'
        echo '-> Mode, Only One Screensaver -> GLSlideshow -> Settings -> Advanced -> glslideshow -root -delay 46565 -duration 10 -zoom 85 -> Close GLSlideshow Settings'
        echo '-> Advanced Tab -> Image Manipulation -> Choose Random Image -> Browse -> Select Image Folder ~/.xscreensaver_glslideshow/top100'
        echo
        C 'Follow the directions above.'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 18 ]; then
    echo '18. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Configure Window Manager Layout ]'
        echo 'Right-click on top panel -> Panel -> Panel Preferences -> Green Plus Sign -> Select New Panel -> Items Tab -> Add Windows Buttons & Separator & Workspace Switcher'
        echo '-> Windows Buttons Settings -> Sorting Order: None, Allow Drag-and-Drop -> Separator Settings -> Expand -> Workspace Settings -> 4 Workspaces: Browsers, E-Mail, Files & Office, Terminals'
        echo '-> Drag Second Panel Down To Bottom Of Screen'
        echo '-> Display Tab -> Lock Panel & Row Size 20 Pixels & Length 100%'
        echo '-> Select First Panel -> Items -> Remove Workspace Switcher & Window Buttons -> Add Action Buttons'
        echo '-> Close Panel Preferences'
        echo
        C 'Follow the directions above.'
        echo '[ Run & Configure Indicator Multiload & Clock Applets ]'
        B 'indicator-multiload --trayicon &'
        echo 'Left-click on indicator-multiload applet -> Preferences -> Select Processor, Memory, Network, Harddisk, Autostart -> Colors Built-In Schemes Traditional, Cached Color Black'
        echo 'Right-click on indicator-multiload applet -> Move -> Drag to left of indicator plugin icons'
        echo 'Right-click on clock applet -> Properties -> Format -> Custom Format'
        echo '%a %b%d %Y%m%d %Y.%j %H%M.%S'
        echo
        C 'Follow the directions above.'
        echo '[ Remove Unused Directories ]'
        B rm -Rf ~/Videos/ ~/Templates/ ~/Public/ ~/Pictures/ ~/Music/ ~/Documents/
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead
# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead
# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead

if [ $MENU_CHOICE -le 19 ]; then
    echo '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo 'Follow the directions below.'
        echo
        echo 'enable security updates only'
        echo 'check for updates daily'
        echo 'install security updates only'
        echo 'never remind of dist upgrade'
        echo 'enable Ubuntu (main & universe) repositories only, disable other (restricted & multiverse)'  # NEED ANSWER: why disable security updates from restricted & multiverse repos?
        echo
        S update-manager
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 20 ]; then
    echo '20. [[[ LINUX, INSTALL PERL DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Overview Of Perl Dependencies In This Section ]'
        echo '[ CPAN: The Comprehensive Perl Archive Network, Required For Installing Perl Software ]'
        echo '[ Perl Debug: Symbols For The Perl Interpreter, Optional For Perl Core & XS & RPerl Debugging ]'
        echo '[ Git: Source Code Version Control, Required To Install Latest Development & Unstable Software ]'
        echo '[ Make: Program Builder, Required To Build ExtUtils::MakeMaker ]'
        echo '[ cURL: Downloader, Required To Install cpanminus & Perlbrew & Perl-Build ]'
        echo '[ ExtUtils::MakeMaker: Source Code Builder, Required To Build Many Perl Software Suites ]'
        echo

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU
            echo '[ UBUNTU ONLY: Install Perl Debugging Symbols System-Wide ]'
            S apt-get install perl-debug
            echo '[ UBUNTU ONLY: Install git ]'
            S apt-get install git
            echo '[ UBUNTU ONLY: Install make ]'
            S apt-get install make
            echo '[ UBUNTU ONLY: Install cURL ]'
            S apt-get install curl
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS
            echo '[ CENTOS ONLY: Install CPAN ]'
            S yum install perl-core perl-CPAN
            echo '[ CENTOS ONLY: Install Perl Debugging Symbols System-Wide ]'
            echo '[ NOT CURRENTLY AVAILABLE FOR CENTOS ]'
            echo '[ CENTOS ONLY: Install git ]'
            S yum install git
            echo '[ CENTOS ONLY: Install make ]'
            S yum install make
            echo '[ CENTOS ONLY: Install cURL ]'
            S yum install curl
            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
        fi

        echo '[ Check cURL Installation ]'
        B 'curl -L cpanmin.us > /dev/null'
        echo
        echo '[ Look For Any Errors In The Output From The curl Command Above ]'
        echo '[ WARNING: IF AND ONLY IF The Above curl Command Gives The Error On The Following Line, THEN Execute The echo Command In The Next Step ]'
        echo 'curl: (77) error setting certificate verify locations'
        echo
        C 'Please read the warning above.  Seriously.'
        echo
        B "echo 'cacert=/etc/ssl/certs/ca-certificates.crt' >> ~/.curlrc"

        echo '[ Optionally Disable Previous local::lib Or Perlbrew Installations ]'
        echo '[ NOTE: You SHOULD Disable Any Previous Perl Installations, Unless You Know What You Are Doing ]'
        B mv ~/perl5 ~/perl5.old

        echo '[ Install ExtUtils::MakeMaker System-Wide, Check Current System-Wide Version, Must Be v7.04 Or Newer ]'
        S 'perl -MExtUtils::MakeMaker\ 999'  # system-wide v7.04 or newer required by Inline::C & possibly others
        echo '[ Install ExtUtils::MakeMaker System-Wide ]'
        echo '[ NOTE: You MUST Have v7.04 Or Newer Installed System-Wide (And Also Single-User) For RPerl ]'
        # DEV NOTE: create Perl lib dirs due to CentOS bug, dirs should already exist but do not, checked by CPAN::FirstTime::_can_write_to_libdirs()
        echo '[ Ensure Perl Library Directories Exist ]'
        S "perl -e 'use Config; foreach my \$dir_key (qw(installprivlib installarchlib installsitelib installsitearch)) { if (not -e \$Config{\$dir_key}) { my \$success = mkdir \$Config{\$dir_key}; if (\$success) { print q{Created directory: }, \$Config{\$dir_key}, qq{\\n}; } else { print q{Error, could no create directory: }, \$Config{\$dir_key}, qq{\\n}, \$!, qq{\\n}; } } else { print q{Directory already exists: }, \$Config{\$dir_key}, qq{\\n}; } }'"
        echo '[ Choose "yes" For Automatic Configuration & Also "yes" For Automatic CPAN Mirror Selection ]'
        echo '[ Choose "sudo" For Installation Approach If Previous Command Does Not Solve "Warning: You do not have write permission for Perl library directories." ]'
        S cpan ExtUtils::MakeMaker
        echo '[ Install ExtUtils::MakeMaker System-Wide, Check Updated Version, Must Be v7.04 Or Newer ]'
        S 'perl -MExtUtils::MakeMaker\ 999'

        echo '[ Check Perl Version To Determine Which Of The Following Sections To Choose ]'
        B perl -v

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 21 ]; then
    echo '21. [[[ LINUX, INSTALL SINGLE-USER PERL LOCAL::LIB & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD Use This Instead Of Perlbrew Or Perl From Source Or System Perl In Sections 22 & 23 & 24, Unless You Have No Choice ]'
        echo '[ This Option Will Contain All Perl Code In Your Home Directory Under The ~/perl5 Subdirectory ]'
        echo '[ This Option May  Not Work With Older Versions Of Debian GNU/Linux Which Include A Broken Perl v5.14, Use Perlbrew in Section 22 Instead ]'
        echo '[ This Option Will Not Work With Older Versions Of Perl Which Are Not At Least v5.10 Or Newer, Use Perlbrew in Section 22 Instead ]'
        echo '[ WARNING: Do NOT Mix With Perlbrew In Section 22! ]'
        echo '[ WARNING: Do NOT Mix With Perl From Source In Section 23! ]'
        echo '[ WARNING: Do NOT Mix With System Perl In Section 24! ]'
        C 'Please read the warnings above.  Seriously.'
        echo
        echo '[ Install local::lib & CPANM in ~/perl5 ]'
        B 'curl -L cpanmin.us | perl - -l $HOME/perl5 App::cpanminus local::lib'
        echo '[ Enable local::lib In .bashrc Run Commands Startup File ]'
        echo '[ NOTE: Do Not Run The Following Step If You Already Copied Your Own Pre-Existing LAMP University .bashrc File In Section 0 ]'
        # DEV NOTE: pre-munged command for comparison
#       if [ -d $HOME/perl5/lib/perl5 ]; then
#           eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)

# START HERE: need add following 6 lines to munged echo statement below...
# START HERE: need add following 6 lines to munged echo statement below...
# START HERE: need add following   lines to munged echo statement below...

#           if ! [[ ":$PERL5LIB:" == *":$HOME/perl5/lib/perl5:"* ]]; then
#               export PERL5LIB=$HOME/perl5/lib/perl5:$PERL5LIB
#           fi
#           if ! [[ ":$PERL5LIB:" == *":$HOME/perl5/lib/perl5/x86_64-linux:"* ]]; then
#               export PERL5LIB=$HOME/perl5/lib/perl5/x86_64-linux:$PERL5LIB
#           fi


#       fi
        B echo -e '"# enable local::lib, do NOT mix with Perlbrew\nif [ -d"' '\$HOME/perl5/lib/perl5 ]\; then' '"\n  "' "'" eval '$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' "'" '"\nfi\n"' '>> ~/.bashrc'
        SOURCE ~/.bashrc
        echo '[ Ensure The Following 4 Environmental Variables Now Include ~/perl5: PERL_MM_OPT, PERL_MB_OPT, PERL5LIB, PATH ]'
        echo '[ If Not, Please Log Out & Log Back In, Then Return To This Point & Check Again ]'
        B 'set | grep perl5'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 22 ]; then
    echo '22. [[[ LINUX, INSTALL SINGLE-USER PERLBREW & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 21, Unless You Have No Choice ]'
        echo '[ This Option WILL Work With Older Versions Of Debian GNU/Linux Which Include A Broken Perl v5.14 ]'
        echo '[ This Option WILL Work With Older Versions Of Perl Which Are Not At Least v5.10 Or Newer ]'
        echo '[ WARNING: Do NOT Mix With local::lib In Section 21! ]'
        echo '[ WARNING: Do NOT Mix With Perl From Source In Section 23! ]'
        echo '[ WARNING: Do NOT Mix With System Perl In Section 24! ]'
        C 'Please read the warnings above.  Seriously.'

        echo '[ You Should Use Ubuntu Or CentOS Instead Of curl Below, Unless You Are Not In Ubuntu Or CentOS, Or You Have No Choice ]'
        echo '[ WARNING: Use Only ONE Of The Following Three Options, EITHER Ubuntu OR CentOS OR curl, But NOT More Than One! ]'
        C 'Please read the warning above.  Seriously.'

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU

            echo '[ UBUNTU ONLY: Install Perlbrew ]'
            S apt-get install perlbrew

            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS
            echo '[ WARNING: Use Only ONE Of The Following Two CentOS Options, EITHER CPAN OR perlbrew_install.sh, But NOT More Than One! ]'
            C 'Please read the warning above.  Seriously.'

            echo '[ CENTOS & CPAN ONLY: Install Perl & CPAN ]'
            S yum install perl perl-core perl-CPAN perl-CPAN-Meta
            # DEV NOTE: create Perl lib dirs due to CentOS bug, dirs should already exist but do not, checked by CPAN::FirstTime::_can_write_to_libdirs()
            echo '[ CENTOS & CPAN ONLY: Ensure Perl Library Directories Exist ]'
            S "perl -e 'use Config; foreach my \$dir_key (qw(installprivlib installarchlib installsitelib installsitearch)) { if (not -e \$Config{\$dir_key}) { my \$success = mkdir \$Config{\$dir_key}; if (\$success) { print q{Created directory: }, \$Config{\$dir_key}, qq{\\n}; } else { print q{Error, could no create directory: }, \$Config{\$dir_key}, qq{\\n}, \$!, qq{\\n}; } } else { print q{Directory already exists: }, \$Config{\$dir_key}, qq{\\n}; } }'"
            echo '[ CENTOS & CPAN ONLY: Install CPANM ]'
            S cpan App::cpanminus
            echo '[ CENTOS & CPAN ONLY: Install Perlbrew ]'
            S cpanm install App::perlbrew

            # OR

            echo '[ CENTOS & perlbrew_install.sh ONLY: Install GCC Compiler & Other Requirements ]'
            S yum install gcc bzip2 patch 
            echo '[ CENTOS & perlbrew_install.sh ONLY: Download perlbrew_install.sh Script ]'
            B curl -L https://install.perlbrew.pl -o perlbrew_install.sh
            echo '[ CENTOS & perlbrew_install.sh ONLY: Run perlbrew_install.sh Script  ]'
            B chmod a+x ./perlbrew_install.sh && ./perlbrew_install.sh

            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
        fi

        # OR
        echo '[ CURL ONLY: Install Perlbrew; DO NOT USE IF apt-get OR yum WAS SUCCESSFUL! ]'
        S 'curl -L http://install.perlbrew.pl | bash'

        echo '[ Configure Perlbrew ]'
        B perlbrew init
        echo '[ In Texas, The Following Perlbrew Mirror Is Recommended: Arlington, TX #222 http://mirror.uta.edu/CPAN/ ]'
        B perlbrew mirror
        B 'echo "source ~/perl5/perlbrew/etc/bashrc" >> ~/.bashrc'
        SOURCE ~/.bashrc
        echo '[ Ensure The Following 3 Environmental Variables Now Include ~/perl5: PERLBREW_MANPATH, PERLBREW_PATH, PERLBREW_ROOT ]'
        B 'set | grep perl5'
        
        echo '[ Build Perlbrew Perl v5.24.0 ]'
        B perlbrew install perl-5.24.0
        echo '[ Temporaily Enable Perlbrew Perl v5.24.0 ]'
        B perlbrew use perl-5.24.0
        echo '[ Permanently Enable Perlbrew Perl v5.24.0 ]'
        B perlbrew switch perl-5.24.0
        echo '[ Install Perlbrew CPANM ]'
        B perlbrew install-cpanm

        echo '[ ExtUtils::MakeMaker v7.04 Or Newer Is Required By Inline::C, May Need To Re-Install In Single-User Mode ]'
        echo '[ Check Version Of ExtUtils::MakeMaker, Re-Install If Older Than v7.04 ]'
        B 'perl -MExtUtils::MakeMaker\ 999'
        echo '[ Re-Install ExtUtils::MakeMaker Via CPAN, Because Perlbrew Acts As System-Wide Perl In Single-User Mode ]'
        echo '[ NOTE: You MUST Have v7.04 Or Newer Installed System-Wide (And Also Single-User) For RPerl ]'
        B cpanm ExtUtils::MakeMaker
        echo '[ Re-Check Version Of ExtUtils::MakeMaker, Must Be v7.04 Or Newer ]'
        B 'perl -MExtUtils::MakeMaker\ 999'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 23 ]; then
    echo '23. [[[ LINUX, INSTALL SYSTEM-WIDE PERL FROM SOURCE & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 21, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With local::lib In Section 21! ]'
        echo '[ WARNING: Do NOT Mix With Perlbrew In Section 22! ]'
        echo '[ WARNING: Do NOT Mix With System Perl In Section 24! ]'
        C 'Please read the warnings above.  Seriously.'
        echo '[ WARNING: Choose ONLY ONE Of The Following Two Methods: Manual Build, Or Tokuhirom Perl-Build ]'
        C 'Please read the warning above.  Seriously.'
        # NEED ANSWER: does this actually work?
        echo '[ MANUAL BUILD ONLY: Download Perl Source Code ]'
        B 'wget http://www.cpan.org/src/5.0/perl-5.24.0.tar.bz2; tar -xjvf perl-5.24.0.tar.bz2'
        echo '[ MANUAL BUILD ONLY: Build Perl Source Code ]'
        B 'cd perl-5.24.0; ./Configure -des; make; make test'
        echo '[ MANUAL BUILD ONLY: Install Perl Build ]'
        S 'cd perl-5.24.0; make install'
        # OR
        echo '[ TOKUHIROM PERL-BUILD ONLY: Download, Build, Install Perl ]'
        # NEED ANSWER: does this actually work?
        S 'curl https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.24.0 /usr/local/bin/perl-5.24.0/'
        echo '[ EITHER OPTION: Install cpanminus ]'
        S perl -MCPAN -e 'install App::cpanminus'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 24 ]; then
    echo '24. [[[ LINUX, INSTALL SYSTEM-WIDE SYSTEM PERL & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 21, Unless You Have No Choice ]'
        echo '[ This Option Will Install Both Perl & cpanminus System-Wide ]'
        echo '[ Also, All Future CPAN Distributions Will Install System-Wide In A Hard-To Control Manner ]'
        echo '[ WARNING: Do NOT Mix With local::lib In Section 21! ]'
        echo '[ WARNING: Do NOT Mix With Perlbrew In Section 22! ]'
        echo '[ WARNING: Do NOT Mix With Perl From Source In Section 23! ]'
        C 'Please read the warnings above.  Seriously.'

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU
            echo '[ UBUNTU ONLY: Install Perl & CPANM ]'
            S apt-get install perl cpanminus
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS 
            echo '[ CENTOS ONLY: Install Perl & CPANM Dependencies ]'
            S yum install perl-core perl-libs perl-devel perl-CPAN curl
            echo '[ CENTOS ONLY: Install CPANM System-Wide ]'
            S 'curl -L http://cpanmin.us | perl - --sudo App::cpanminus'
            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
        fi

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 25 ]; then
    echo '25. [[[ LINUX, INSTALL RPERL DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Overview Of RPerl Dependencies In This Section ]'
        echo '[ GCC: gcc & g++ Required For Compiling ]'
        echo '[ libc: libcrypt.(a|so) Required For Compiling ]'
        echo '[ libperl: libperl.(a|so) & perl.h etc, Required For Compiling ]'
        echo '[ openssl: err.h Required By RPerl Subdependency Net::SSLeay From IO::Socket::SSL ]'
        echo '[ zlib: zlib.h Required By SDL.pm, Which Is Required For Graphics ]'
        echo '[ GMP: GNU Multiple-Precision Arithmetic Library Required For Math ]'
        echo '[ GSL: GNU Scientific Library Required For Math ]'
        echo '[ Pluto polyCC: polycc Required For Parallel Compiling, Depends On texinfo flex bison ]'
        echo '[ AStyle: Artistic Style C++ Formatter, Required By RPerl Test Suite ]'
        echo '[ pkg-config: Compilation Library Detection Tool, Required By RPerl Support For MongoDB ]'
        echo '[ MongoDB Drivers: Both C & C++, Required By RPerl Support For MongoDB ]'
        echo

        # DEV NOTE: libperl packages in Ubuntu vs CentOS
        # Ubuntu, libperl-dev,  /usr/lib/x86_64-linux-gnu/libperl.so SYMLINK    /usr/lib/x86_64-linux-gnu/libperl.a REAL FILE
        # Ubuntu, libperl5.XX,  /usr/lib/x86_64-linux-gnu/libperl.so.5.XX.Y REAL FILE    /usr/lib/x86_64-linux-gnu/perl/5.26.0/CORE/perl.h  and other *.h *.so *.pm *.ph files
        # CentOS 7, perl-libs,  /usr/lib64/perl5/CORE/libperl.so
        # CentOS 7, perl-devel, /usr/lib64/perl5/CORE/perl.h     /usr/bin/h2xs  and other *.h files

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU
            echo '[ UBUNTU ONLY: Add Non-Base APT Repositories ]'
            S add-apt-repository \"deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe restricted multiverse\"
            echo '[ UBUNTU ONLY: Update APT Repositories ]'
            S apt-get update
            echo '[ UBUNTU ONLY: Install RPerl Dependencies ]'
            S apt-get install g++ libc6-dev libperl-dev libssl-dev zlib1g-dev libgmp-dev libgsl0-dev texinfo flex bison astyle
            echo '[ UBUNTU ONLY: Install RPerl Dependencies, MongoDB C Driver ]'
            S apt-get install pkg-config libmongoc-1.0-0
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS

            echo '[ CENTOS ONLY: Install RPerl Dependencies ]'
            S yum install gcc-c++ make glibc-devel perl-core perl-libs perl-devel openssl-devel zlib zlib-static zlib-devel gmp gmp-static gmp-devel gsl gsl-devel texinfo flex bison
            echo '[ CENTOS ONLY: Install RPerl Dependencies, GCC/G++ GDB Debugging Symbols ]'
#            S debuginfo-install cracklib-2.9.0-11.el7.x86_64 cyrus-sasl-lib-2.1.26-21.el7.x86_64 glibc-2.17-196.el7_4.2.x86_64 keyutils-libs-1.5.8-3.el7.x86_64 krb5-libs-1.15.1-8.el7.x86_64 libcom_err-1.42.9-10.el7.x86_64 libgcc-4.8.5-16.el7_4.2.x86_64 libselinux-2.5-11.el7.x86_64 libstdc++-4.8.5-16.el7_4.2.x86_64 nspr-4.13.1-1.0.el7_3.x86_64 nss-3.28.4-15.el7_4.x86_64 nss-softokn-freebl-3.28.3-8.el7_4.x86_64 nss-util-3.28.4-3.el7.x86_64 openldap-2.4.44-5.el7.x86_64 openssl-libs-1.0.2k-8.el7.x86_64 pcre-8.32-17.el7.x86_64 postgresql96-libs-9.6.8-1PGDG.rhel7.x86_64 zlib-1.2.7-17.el7.x86_64
            S debuginfo-install cracklib cyrus-sasl-lib glibc keyutils-libs krb5-libs libcom_err libgcc libselinux libstdc++ nspr nss nss-softokn-freebl nss-util openldap openssl-libs pcre postgresql96-libs zlib
            echo '[ CENTOS ONLY: Download & Install RPerl Dependency AStyle ]'
            B wget https://github.com/wbraswell/astyle-mirror/raw/master/backup/astyle-2.05.1-1.el7.centos.x86_64.rpm
            S rpm -v -i ./astyle-2.05.1-1.el7.centos.x86_64.rpm
            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, pkg-config ]'
            S yum install pkgconfig

            # OLD VERSIONS, DO NOT USE!  libbson v1.3.5-5.el7, mongo-c-driver-libs v1.3.6-1.el7, mongo-c-driver v1.3.6-1.el7
            # must have new versions for MongoDB C++ driver compatibility
            # "For mongocxx-3.2.x, libmongoc 1.8.2 or later is required."    https://mongodb.github.io/mongo-cxx-driver/mongocxx-v3/installation/
#            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, MongoDB C Driver ]'
#            S yum install pkgconfig mongo-c-driver

            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, libbson ]'

            # perl-interpreter is a dummy package for CentOS 7 compatibility with Fedora source packages libbson & mongo-c-driver
            S yum install rpm-build libtool cyrus-sasl-lib cyrus-sasl-devel snappy-devel perl-interpreter python-sphinx

#            # DEV NOTE: prefer pre-built RPMs below
##            B wget http://dl.fedoraproject.org/pub/fedora/linux/updates/27/SRPMS/Packages/l/libbson-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer GitHub mirror below
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer our own GitHub mirror for uniformity
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.src.rpm  # DEV NOTE: prefer our own re-built source RPMs for uniformity
#            S rpm -i -vv ./libbson-1.9.3-1.fc27.src.rpm
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson.spec
#            S mv ./libbson.spec /root/rpmbuild/SPECS/libbson.spec
#            S rpmbuild -ba /root/rpmbuild/SPECS/libbson.spec
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/libbson-1.9.3-1.el7.centos.x86_64.rpm
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/libbson-devel-1.9.3-1.el7.centos.x86_64.rpm  # provides pkgconfig(libbson-1.0) to satisfy mongodb-c-driver requirements
#            # OR
            # DEV NOTE: prefer our own pre-built RPMs from GitHub mirror, for speed & reliability & convenience
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-devel-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./libbson-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./libbson-devel-1.9.3-1.el7.centos.x86_64.rpm  # provides pkgconfig(libbson-1.0) to satisfy mongodb-c-driver requirements
            B rm ./libbson-1.9.3-1.el7.centos.x86_64.rpm
            B rm ./libbson-devel-1.9.3-1.el7.centos.x86_64.rpm  

            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, MongoDB C Driver ]'

#            # DEV NOTE: prefer pre-built RPMs below
##            B wget http://dl.fedoraproject.org/pub/fedora/linux/updates/27/SRPMS/Packages/m/mongo-c-driver-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer GitHub mirror below
##            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer our own GitHub mirror for uniformity
#            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.el7.centos.src.rpm  # DEV NOTE: prefer our own re-built source RPMs for uniformity
#            S rpm -i -vv mongo-c-driver-1.9.3-1.fc27.src.rpm
#            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver.spec
#            S mv ./mongo-c-driver.spec /root/rpmbuild/SPECS/mongo-c-driver.spec
#            S systemctl stop mongodb.service
#            S rpmbuild -ba /root/rpmbuild/SPECS/mongo-c-driver.spec
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm
#            S systemctl start mongodb.service
#            # OR
            # DEV NOTE: prefer our own pre-built RPMs from GitHub mirror, for speed & reliability & convenience
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm
            S systemctl stop mongodb.service
            S rpm -i -vv ./mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm
            S systemctl start mongodb.service
            B rm ./mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
            B rm ./mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
            B rm ./mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm

#            # DEV NOTE: prefer pre-built RPMs below
#            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, Fix Broken CMake Files ]'
#            # NEED ANSWER: can we fix this CMake error permanently by including --enable-static in configure for both libbson & mongo-c-driver above???
#            # CMake Error at /lib64/cmake/libbson-1.0/libbson-1.0-config.cmake:28 (message): File or directory //include/libbson-1.0 referenced by variable BSON_INCLUDE_DIRS does not exist !
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.0-config.cmake
#            S mv ./libbson-1.0-config.cmake /lib64/cmake/libbson-1.0/libbson-1.0-config.cmake
#            # CMake Error at /lib64/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake:30 (message): File or directory //include/libmongoc-1.0 referenced by variable MONGOC_INCLUDE_DIRS does not exist !
#            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/libmongoc-1.0-config.cmake
#            S mv ./libmongoc-1.0-config.cmake /lib64/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake

            echo '[ CENTOS ONLY: Install RPerl Dependencies, MongoDB C++ Driver ]'

            S yum install cmake3

#            # DEV NOTE: prefer pre-built RPMs below
##            # DEV NOTE: prefer already-fixed tarball below
##            B wget https://github.com/mongodb/mongo-cxx-driver/archive/r3.2.0.tar.gz
##            S mv ./r3.2.0.tar.gz /root/rpmbuild/SOURCES/mongo-cxx-driver-3.2.0.tar.gz
##            CD /root/rpmbuild/SOURCES
##            S tar -xzvf mongo-cxx-driver-3.2.0.tar.gz
##            S mv mongo-cxx-driver-r3.2.0 mongo-cxx-driver-3.2.0
##            S rm mongo-cxx-driver-3.2.0.tar.gz
##            S tar -czvf mongo-cxx-driver-3.2.0.tar.gz ./mongo-cxx-driver-3.2.0
#            # DEV NOTE: prefer our own already-fixed tarball below, for convenience
#            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0.tar.gz
#            S mv ./mongo-cxx-driver-3.2.0.tar.gz /root/rpmbuild/SOURCES/mongo-cxx-driver-3.2.0.tar.gz
#            CD /root/rpmbuild/SPECS
#            S wget https://raw.githubusercontent.com/wbraswell/mongo-cxx-driver-mirror/master/mongo-cxx-driver.spec
#            S rpmbuild -ba /root/rpmbuild/SPECS/mongo-cxx-driver.spec
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
#            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm
#            # OR
            # DEV NOTE: prefer our own pre-built RPMs from GitHub mirror, for speed & reliability & convenience
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm
            B rm ./mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
            B rm ./mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
            B rm ./mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm

            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
            S yum check
        fi

        echo '[ Check GCC Version, Must Be v4.7 Or Newer, Use Manual Build Option If Automatic Install Options Fail Or Are Too Old ]'
        B g++ --version

        echo '[ Check AStyle Version, Must Be v2.05.1 Or Newer, Use Manual Build Option If Automatic Install Options Fail Or Are Too Old ]'
        B astyle -V

        # OR
        echo '[ WARNING: Do NOT Use Manual Build Options Below, Unless You Are Not In Ubuntu Or CentOS, Or You Have No Choice! ]'
        C 'Please read the warnings above.  Seriously.'
        echo '[ MANUAL BUILD ONLY: Install RPerl Dependency GCC, Download ]'
        B 'wget http://www.netgull.com/gcc/releases/gcc-5.2.0/gcc-5.2.0.tar.bz2; tar -xjvf gcc-5.2.0.tar.bz2'
        echo '[ MANUAL BUILD ONLY: Install RPerl Dependency GCC, Build ]'
        B 'cd gcc-5.2.0; ./configure; make; make test'
        echo '[ MANUAL BUILD ONLY: Install RPerl Dependency GCC, Install ]'
        S 'cd gcc-5.2.0; make install'
        echo '[ MANUAL BUILD ONLY: Install RPerl Dependency GMP, Visit The Following URL For Installation Instructions ]'
        echo 'https://gmplib.org'
        echo
        echo '[ MANUAL BUILD ONLY: Install RPerl Dependency AStyle, Visit The Following URL For Installation Instructions ]'
        echo 'http://astyle.sourceforge.net'
        echo



        # START HERE: need add non-centos install of mongodb c++ driver; correlate with Section 60 below
        # START HERE: need add non-centos install of mongodb c++ driver; correlate with Section 60 below
        # START HERE: need add non-centos install of mongodb c++ driver; correlate with Section 60 below

        echo '[ Install RPerl Dependency MongoDB C++ Driver, Download/Build/Install, NOT YET ENABLED!!! ]'



        echo '[ Install RPerl Dependency Pluto PolyCC, Download ]'
        # B 'wget https://github.com/wbraswell/pluto-mirror/raw/master/backup/pluto-0.11.4.tar.gz; tar -xzvf pluto-0.11.4.tar.gz'  # prefer official repo below
        B 'wget https://github.com/bondhugula/pluto/files/737550/pluto-0.11.4.tar.gz; tar -xzvf pluto-0.11.4.tar.gz'
        echo '[ Install RPerl Dependency Pluto PolyCC, Build ]'
        B 'cd pluto-0.11.4; ./configure; make; make test'
        echo '[ Install RPerl Dependency Pluto PolyCC, Install ]'
        S 'cd pluto-0.11.4; make install'

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 26 ]; then
    echo '26. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPAN ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You Should Use This Instead Of Unstable Via GitHub In Section 27, Unless You Are An RPerl System Developer ]'
        echo '[ This Option Will Install The Latest Stable Public Release Of RPerl ]'
        echo '[ WARNING: Do NOT Mix With Unstable Via GitHub In Section 27! ]'
        C 'Please read the warning above.  Seriously.'
        echo
        echo '[ You Should Use Single-User Instead Of System-Wide Below, Unless local::lib Or Perlbrew Is Not Installed Or You Have No Choice ]'
        echo '[ WARNING: Use Only ONE Of The Following Two Options, EITHER Single-User OR System-Wide, But NOT Both! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ SINGLE-USER ONLY: Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
        B cpanm -v --notest IO::Socket::SSL
        echo '[ SINGLE-USER ONLY: Install RPerl ]'
        B cpanm -v RPerl
        # OR
        echo '[ SYSTEM-WIDE ONLY: Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
        S cpanm -v --notest IO::Socket::SSL
        echo '[ SYSTEM-WIDE ONLY: Install RPerl ]'
        S cpanm -v RPerl

        echo '[ EITHER OPTION: If cpanm Is Not Installed, Exit This Installer & Manually Try cpan Instead ]'
        echo '[ Copy The Command From The Following Line For Single-User Option ]'
        echo '$ cpan RPerl'
        echo
        echo '[ Copy The Command From The Following Line For System-Wide Option ]'
        echo '$ sudo cpan RPerl'
        echo
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 27 VARIABLES
GITHUB_EMAIL='__EMPTY__'
GITHUB_FIRST_NAME='__EMPTY__'
GITHUB_LAST_NAME='__EMPTY__'
RPERL_REPO_DIRECTORY='__EMPTY__'

if [ $MENU_CHOICE -le 27 ]; then
    echo '27. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of Stable Via CPAN In Section 26, Unless You Are An RPerl System Developer ]'
        echo '[ This Option Will Install The Latest Unstable Development Release Of RPerl ]'
        echo '[ WARNING: Do NOT Mix With Stable Via CPAN In Section 26! ]'
        C 'Please read the warning above.  Seriously.'
        echo
        echo '[ If You Want To Upload Code To GitHub, Then You Must Use Secure Git Instead Of Public Git Or Public Zip Below ]'
        echo '[ WARNING: Use Only ONE Of The Following Three Options, EITHER Secure OR Public Git OR Public Zip, But NOT More Than One! ]'
        C 'Please read the warning above.  Seriously.'

        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        P $GITHUB_EMAIL "e-mail address used for GitHub account (any value if not using Secure Git option)"
        GITHUB_EMAIL=$USER_INPUT
        P $GITHUB_FIRST_NAME "first name used for GitHub account (any value if not using Secure Git option)"
        GITHUB_FIRST_NAME=$USER_INPUT
        P $GITHUB_LAST_NAME "last name used for GitHub account (any value if not using Secure Git option)"
        GITHUB_LAST_NAME=$USER_INPUT
        D $RPERL_REPO_DIRECTORY 'directory where the RPerl repository should be downloaded (different than final RPerl installation directory)' "~/rperl-latest"
        RPERL_REPO_DIRECTORY=$USER_INPUT

        # DEV NOTE: for more info, see  https://help.github.com/articles/generating-ssh-keys
        #if [ ! -f ~/.ssh/id_rsa.pub ] && [ ! -f ~/.ssh/id_dsa.pub ]; then  # NEED ANSWER: do we need id_dsa.pub???
        if [ ! -f ~/.ssh/id_rsa.pub ]; then
            echo '[ SECURE GIT ONLY: Generate SSH Keys, Do Create Secure Key Passphrase When Prompted ]'
            echo '[ WARNING: Be Sure To Record Your Secure Key Passphrase & Store It In A Safe Place ]'
            C 'Please read the warning above.  Seriously.'
            B "ssh-keygen -t rsa -C '$GITHUB_EMAIL'; eval `ssh-agent -s` ssh-add ~/.ssh/id_rsa; ssh-agent -k"
        else
            echo '[ SECURE GIT ONLY: SSH Key File(s) Already Exist, Skipping Key Generation ]'
        fi

        if [[ "$OS_CHOICE" == "UBUNTU" ]]; then
            VERIFY_UBUNTU
            echo '[ SECURE GIT ON UBUNTU ONLY: Install Keychain Key Manager For OpenSSH ]'
            S apt-get install keychain
            echo '[ UBUNTU ONLY: Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "CENTOS" ]]; then
            VERIFY_CENTOS 
            C '[ SECURE GIT ON NON-CENTOS ONLY: Not Currently Supported ]'
#            echo '[ SECURE GIT ON CENTOS ONLY: Install Keychain Key Manager For OpenSSH ]'
#            S rpm --import http://mirror.ghettoforge.org/distributions/gf/RPM-GPG-KEY-gf.el7
#            S rpm -Uvh http://mirror.ghettoforge.org/distributions/gf/gf-release-latest.gf.el7.noarch.rpm 
#            S yum clean all
#            S yum install keychain
#            echo '[ CENTOS ONLY: Check Install, Confirm No Errors; WARNING! MAKE TAKE HOURS TO RUN! ]'
#            S yum check
        else
            C '[ SECURE GIT ON NON-UBUNTU AND NON-CENTOS ONLY: Please See Your Operating System Documentation To Install Keychain Key Manager For OpenSSH ]'
        fi

        echo '[ SECURE GIT ONLY: Enable Keychain ]'
        echo '[ NOTE: Do Not Run The Following Step If You Already Copied Your Own Pre-Existing LAMP University .bashrc File In Section 0 ]'
        B 'echo -e "\n# SSH Keys; for GitHub, etc.\nif [ -f /usr/bin/keychain ] && [ -f \$HOME/.ssh/id_rsa ]; then\n    /usr/bin/keychain \$HOME/.ssh/id_rsa\n    source \$HOME/.keychain/\$HOSTNAME-sh\nfi\n" >> ~/.bashrc;'
        SOURCE ~/.bashrc
        echo '[ SECURE GIT ONLY: How To Enable SSH Key On GitHub... ]'
        echo '[ SECURE GIT ONLY: Copy Data Produced By The Next Command ]'
        echo '[ SECURE GIT ONLY: Then Browse To https://github.com/settings/ssh ]'
        echo "[ SECURE GIT ONLY: Then Click 'Add SSH Key', Paste Copied Key Data, Title '$USERNAME@$HOSTNAME', Click 'Save' ]"
        echo
        B 'cat ~/.ssh/id_rsa.pub'
        echo
        C '[ SECURE GIT ONLY: Please Follow The Instructions Above ]'
        echo '[ SECURE GIT ONLY: Test SSH Key On GitHub, Enter Passphrase When Prompted, Confirm Automatic Reply Greeting From GitHub Server ]'
        B ssh -T git@github.com
        echo '[ SECURE GIT ONLY: Configure GitHub Account Setting On Local Machine ]'
        echo '[ NOTE: Do Not Repeat The 3 Following git config Steps If You Already Copied Your Own Pre-Existing .gitconfig File In Section 0 ]'
        B git config --global user.email "$GITHUB_EMAIL"
        B git config --global user.name "$GITHUB_FIRST_NAME $GITHUB_LAST_NAME"
        B git config --global core.editor "$EDITOR"
        echo '[ SECURE GIT ONLY: Clone (Download) RPerl Repository Onto New Machine ]'
        B git clone git@github.com:wbraswell/rperl.git $RPERL_REPO_DIRECTORY
        # OR
        echo '[ PUBLIC GIT ONLY: Clone (Download) RPerl Repository Onto New Machine ]'
        B git clone https://github.com/wbraswell/rperl.git $RPERL_REPO_DIRECTORY
        # OR
        echo '[ PUBLIC ZIP ONLY: Download RPerl Repository Onto New Machine ]'
        B "wget https://github.com/wbraswell/rperl/archive/master.zip; unzip master.zip; mv rperl-master $RPERL_REPO_DIRECTORY; rm master.zip"

        echo '[ ALL OPTIONS: Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
        B cpanm -v --notest IO::Socket::SSL
        echo '[ ALL OPTIONS: Install RPerl Dependencies Via CPAN ]'
        CD $RPERL_REPO_DIRECTORY
        B 'perl Makefile.PL; cpanm --installdeps .'
        echo '[ ALL OPTIONS: Build & Test RPerl ]'
        B 'make; make test'
        echo '[ ALL OPTIONS: Build & Test RPerl, Optional Verbose Output ]'
        B 'make; make test TEST_VERBOSE=1'
        echo '[ ALL OPTIONS: Install RPerl ]'
        B 'make install'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 28 VARIABLES
RPERL_VERBOSE='__EMPTY__'
RPERL_DEBUG='__EMPTY__'
RPERL_WARNINGS='__EMPTY__'
RPERL_INSTALL_DIRECTORY='__EMPTY__'

if [ $MENU_CHOICE -le 28 ]; then
    echo '28. [[[ RPERL, RUN COMPILER TESTS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $RPERL_VERBOSE 'RPERL_VERBOSE additional user output, 0 for off, 1 for on' '1'
        export RPERL_VERBOSE=$USER_INPUT
        D $RPERL_DEBUG 'RPERL_DEBUG additional system output, 0 for off, 1 for on' '1'
        export RPERL_DEBUG=$USER_INPUT
        D $RPERL_WARNINGS 'RPERL_WARNINGS additional user & system warnings, 0 for off, 1 for on' '0'
        export RPERL_WARNINGS=$USER_INPUT
        D $RPERL_INSTALL_DIRECTORY 'directory where RPerl is currently installed' "~/perl5/lib/perl5"
        RPERL_INSTALL_DIRECTORY=$USER_INPUT

        echo '[ These RPerl Test Commands Must Be Executed From Within The RPerl Installation Directory ]'
        CD $RPERL_INSTALL_DIRECTORY

        echo '[ Display RPerl Command Usage, Ensure RPerl Command Is Properly Functioning ]'
        B rperl -?

        echo '[ Test Command Sequence #1, OO Inheritance Test: Clean Pre-Existing Compiled Files ]'
        B rm -Rf _Inline RPerl/Algorithm.pmc RPerl/Algorithm.h RPerl/Algorithm.cpp RPerl/Algorithm/Sort.pmc RPerl/Algorithm/Sort.h RPerl/Algorithm/Sort.cpp RPerl/Algorithm/Sort/Bubble.pmc RPerl/Algorithm/Sort/Bubble.h RPerl/Algorithm/Sort/Bubble.cpp

        RPERL_CODE='use RPerl::Algorithm::Sort::Bubble; my $o = RPerl::Algorithm::Sort::Bubble->new(); $o->inherited_Bubble("logan"); $o->inherited_Sort("wolvie"); $o->inherited_Algorithm("claws");'

        echo '[ Test Command Sequence #1, OO Inheritance Test: Zero Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, PERLOPS_PERLTYPES, PERLOPS_PERLTYPES ]'
        B "perl -e '$RPERL_CODE'"
    
        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile First Of Three Files ]'
        B rperl -V -nop RPerl/Algorithm.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: One Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, PERLOPS_PERLTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile Second Of Three Files ]'
        B rperl -V -nop RPerl/Algorithm/Sort.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: Two Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, CPPOPS_CPPTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile Third Of Three Files ]'
        B rperl -V -nop RPerl/Algorithm/Sort/Bubble.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: All Three Files Are Compiled, Output Should Be CPPOPS_CPPTYPES, CPPOPS_CPPTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #1, OO Inheritance Test: Clean New Compiled Files ]'
        B rm -Rf _Inline RPerl/Algorithm.pmc RPerl/Algorithm.h RPerl/Algorithm.cpp RPerl/Algorithm/Sort.pmc RPerl/Algorithm/Sort.h RPerl/Algorithm/Sort.cpp RPerl/Algorithm/Sort/Bubble.pmc RPerl/Algorithm/Sort/Bubble.h RPerl/Algorithm/Sort/Bubble.cpp

        # NEED FIX: sequence 1 & sequence 2 directories don't match, also installed vs uninstalled directories don't match

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Clean Pre-Existing Compiled Files ]'
        B ../script/demo/unlink_bubble.sh

        RPERL_CODE='use RPerl::Algorithm::Sort::Bubble; my $a = [reverse 0 .. 5000]; use Time::HiRes qw(time); my $start = time; my $s = RPerl::Algorithm::Sort::Bubble::integer_bubblesort($a); my $elapsed = time - $start; print Dumper($s); print "elapsed: " . $elapsed . "\n";'

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Slow Uncompiled PERLOPS_PERLTYPES Mode, ~15 Seconds For 5_000 Elements, ~60 Seconds For 10_000 Elements ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Fast Manually Compiled CPPOPS_PERLTYPES Mode, Link Files ]'
        B ../script/demo/link_bubble_CPPOPS_PERLTYPES.sh
        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Fast Manually Compiled CPPOPS_PERLTYPES Mode, ~2.36 Seconds For 5_000 Elements, ~9.4 Seconds For 10_000 Elements ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Clean New Compiled Files ]'
        B ../script/demo/unlink_bubble.sh
        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, Compile Files ]'


# START HERE: call to rperl command below fails to find dependencies
# START HERE: call to rperl command below fails to find dependencies
# START HERE: call to rperl command below fails to find dependencies


        B rperl -V -nop RPerl/Algorithm/Sort/Bubble.pm
        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, ~0.04 Seconds For 5_000 Elements, ~0.18 Seconds For 10_000 Elements ]'
        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Clean New Compiled Files ]'
        B ../script/demo/unlink_bubble.sh
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 29 VARIABLES
PHYSICSPERL_ENABLE_GRAPHICS='__EMPTY__'
PHYSICSPERL_NBODY_STEPS='__EMPTY__'

if [ $MENU_CHOICE -le 29 ]; then
    echo '29. [[[ RPERL, INSTALL RPERL FAMILY & RUN DEMOS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $RPERL_VERBOSE 'RPERL_VERBOSE additional user output, 0 for off, 1 for on' '1'
        export RPERL_VERBOSE=$USER_INPUT
        D $RPERL_DEBUG 'RPERL_DEBUG additional system output, 0 for off, 1 for on' '1'
        export RPERL_DEBUG=$USER_INPUT
        D $RPERL_WARNINGS 'RPERL_WARNINGS additional user & system warnings, 0 for off, 1 for on' '0'
        export RPERL_WARNINGS=$USER_INPUT
        D $PHYSICSPERL_ENABLE_GRAPHICS 'enabling of PhysicsPerl graphics, 0 for off, 1 for on' '0'
        PHYSICSPERL_ENABLE_GRAPHICS=$USER_INPUT
        D $PHYSICSPERL_NBODY_STEPS 'number of PhysicsPerl N-Body steps to complete (more steps is longer runtime)' '1_000_000'
        PHYSICSPERL_NBODY_STEPS=$USER_INPUT

        # DEV NOTE: PATH & PERL5LIB may already be set via LAMP University Run Commands .bashrc, but temporarily modify anyway just in case
        PATH=script:$PATH
        PERL5LIB=lib:$PATH

        # NEED UPDATE: add option to install PhysicsPerl via CPAN
        echo '[ Install Latest Unstable PhysicsPerl Via Public Github ]'
        B 'wget https://github.com/wbraswell/physicsperl/archive/master.zip; unzip master.zip; my physicsperl-master ~/physicsperl-latest; rm -rf master.zip'
        CD ~/physicsperl-latest
        echo '[ Install PhysicsPerl Dependencies Via CPAN ]'
        B cpanm --installdeps .

        # NEED UPDATE: add timings for all modes at 1M steps instead of only 50M steps

        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Clean Pre-Existing Compiled Files ]'
        B script/demo/unlink_astro.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Super Slow Uncompiled PERLOPS_PERLTYPES_SSE Mode, Link Files ]'
        B script/demo/link_astro_PERLOPS_PERLTYPES_SSE.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Super Slow Uncompiled PERLOPS_PERLTYPES_SSE Mode, Several Days For 50M Steps Without Graphics ]'
        echo '[ NOTE: This Test Could Take SEVERAL HOURS OR DAYS To Run!!! ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS

        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Clean Pre-Existing Compiled Files ]'
        B script/demo/unlink_astro.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Slow Uncompiled PERLOPS_PERLTYPES Mode, Link Files ]'
        B script/demo/link_astro_PERLOPS_PERLTYPES.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Slow Uncompiled PERLOPS_PERLTYPES Mode, Over 9 Hours For 50M Steps Without Graphics ]'
        echo '[ NOTE: This Test Could Take SEVERAL MINUTES OR HOURS To Run!!! ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS

        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B script/demo/unlink_astro.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Super Fast Manually Compiled CPPOPS_CPPTYPES Mode, Link Files ]'
        B script/demo/link_astro_CPPOPS_CPPTYPES.sh
        # NEED UPDATE: add 50M steps timing value for CPPOPS_CPPTYPES (non-SSE)
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Super Fast Manually Compiled CPPOPS_CPPTYPES Mode, ~XYZ Seconds For 50M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS

        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B script/demo/unlink_astro.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Ultra Fast Manually Compiled CPPOPS_CPPTYPES_SSE Mode, Link Files ]'
        B script/demo/link_astro_CPPOPS_CPPTYPES_SSE.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Ultra Fast Manually Compiled CPPOPS_CPPTYPES_SSE Mode, ~13 Seconds For 50M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS

        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B script/demo/unlink_astro.sh
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Ultra Fast Automatically Compiled CPPOPS_CPPTYPES_SSE Mode, Compile Files ]'
        B rperl -V -nop lib/PhysicsPerl/Astro/System.pm
        echo '[ Test Command Sequence #0, PhysicsPerl N-Body Timing Test: Ultra Fast Automatically Compiled CPPOPS_CPPTYPES_SSE Mode, ~13 Seconds For 50M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 30 ]; then
    echo '30. [[[ UBUNTU LINUX, INSTALL NFS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Install NFS Service ]'
        S apt-get install nfs-kernel-server nfs-common
        S mkdir /nfs_exported
        S chmod a+rwX /nfs_exported
        echo '[ Manually Edit NFS Service Export Config File /etc/exports ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ Copy NFS Export Entries From The Following Lines ]'
        echo '/nfs_exported *(rw,sync,no_root_squash,no_subtree_check)'
        echo '/home         *(rw,sync,no_root_squash,no_subtree_check)'
        echo
        S $EDITOR /etc/exports
        echo '[ Start NFS Service ]'
        S service nfs-kernel-server start
        echo '[ Test NFS Service, Part 1, Create "hello" & "delete_me" ]'
        S "echo 'hello world' > /nfs_exported/hello.txt"
        S "echo 'nonsense' > /nfs_exported/delete_me.txt"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now... Then Come Back To This Point."
        echo '[ Test NFS Service, Part 2, Check & Delete "hello" ]'
        S cat /nfs_exported/hello.txt
        S rm /nfs_exported/hello.txt
        echo '[ Test NFS Service, Part 2, Check & Delete "howdy" ]'
        S cat /nfs_exported/howdy.txt
        S rm /nfs_exported/howdy.txt
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        echo '[ Install NFS Client (Via Service Package) ]'
        S apt-get install nfs-kernel-server nfs-common
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        echo '[ Create NFS Import Directory & Mount NFS Share ]'
        S mkdir -p /nfs_imported/$DOMAIN_NAME
        S chmod a+rwX /nfs_imported/$DOMAIN_NAME
        S mount $DOMAIN_NAME:/nfs_exported /nfs_imported/$DOMAIN_NAME  # manual test
        echo '[ Manually Edit NFS Service Import Config File /etc/fstab ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        # NEED UPDATE: include "noauto" option in /etc/fstab entry below?
        echo '[ Copy NFS Import Entry From The Following Line ]'
        echo "$DOMAIN_NAME:/nfs_exported /nfs_imported/$DOMAIN_NAME nfs rsize=8192,wsize=8192,timeo=14,intr"
        echo
        S $EDITOR /etc/fstab
        echo '[ Test NFS Service, Part 1, Check & Update "hello" ]'
        S cat /nfs_imported/$DOMAIN_NAME/hello.txt
        S "echo \"right back atcha\" >> /nfs_imported/$DOMAIN_NAME/hello.txt"
        echo '[ Test NFS Service, Part 2, Check & Delete "delete_me" ]'
        S cat /nfs_imported/$DOMAIN_NAME/delete_me.txt
        S rm /nfs_imported/$DOMAIN_NAME/delete_me.txt
        echo '[ Test NFS Service, Part 3, Create "howdy" ]'
        S "echo \"howdy y'all\" > /nfs_imported/$DOMAIN_NAME/howdy.txt"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 31 ]; then
    echo '31. [[[ UBUNTU LINUX, INSTALL APACHE & MOD_PERL ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT

        echo '[ Install Apache & mod_perl Packages ]'
        S apt-get install apache2 libapache2-mod-perl2

        echo "[ Add $USERNAME To User Group www-data, Allows Web Content To Be Served From /home/$USERNAME ]"
        S usermod -aG www-data $USERNAME 

        echo '[ Subdomain Support ]'
        echo "If you plan to serve a subdomain (ex: foo.bar.com), then please ensure the following CNAME alias entry is set in your hosting provider's DNS zone file:"
        echo ' * @ '
        echo
        C 'Follow the directions above.'

        echo "[ Fix Error \"Could not reliably determine the server's fully qualified domain name\" ]"
        echo '[ Copy Data From The Following Line, Then Paste Into Apache Config File apache2.conf ]'
        echo 'ServerName localhost'
        echo
        
        # NEED ANSWER: IGNORE THIS SECTION??? not present in Ubuntu v14.04.pre, what about v16.xx???
        #<IfModule mpm_prefork_module>
        #    StartServers          2  # 5 in Ubuntu v12.04.4
        #    MinSpareServers       5
        #    MaxSpareServers      10
        #    MaxClients          150
        #    MaxRequestsPerChild   3000  # 0 in Ubuntu v12.04.4
        #</IfModule>
        
        S $EDITOR /etc/apache2/apache2.conf
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 32 VARIABLES
ADMIN_EMAIL='__EMPTY__'

if [ $MENU_CHOICE -le 32 ]; then
    echo '32. [[[ APACHE, CONFIGURE DOMAIN(S) ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's PUBLIC e-mail address"
        ADMIN_EMAIL=$USER_INPUT
        echo "[ REPEAT THIS ENTIRE SECTION ONCE PER DOMAIN OR SUBDOMAIN ]"
        echo
        echo "[ Manually Edit Apache Domain Config File /etc/apache2/sites-available/$DOMAIN_NAME.conf ]"
        echo '[ Select Domain Or Subdomain Config Below, Copy Data From The Following Lines, Then Paste Into Apache Domain Config File ]'
        echo
        echo '[ DOMAIN USE ONLY (Not Subdomain) ]'
        echo
        echo "<VirtualHost *:80>"
        echo "    ServerName $DOMAIN_NAME"
        echo "    ServerAlias www.$DOMAIN_NAME"
        echo "    ServerAdmin $ADMIN_EMAIL"
        echo "    DocumentRoot /srv/www/$DOMAIN_NAME/public_html/"
        echo "    <Directory />  # required for Apache v2.4 in Ubuntu v14.04.pre"
        echo "        Require all granted"
        echo "    </Directory>"
        echo "    # ENABLE FOLLOWING LINE If Using Google Webmaster Tools, Robots Testing Tool; Assumes Github Repo In /home/$USERNAME/public_html/$DOMAIN_NAME-latest"
        echo "#    Alias    /googleSOMELONGNUMBER.html    /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/googleSOMELONGNUMBER.html"
        echo "    ErrorLog /srv/www/$DOMAIN_NAME/logs/error.log"
        echo "    CustomLog /srv/www/$DOMAIN_NAME/logs/access.log combined"
        echo "</VirtualHost>"
        echo
        echo '...OR...'
        echo
        echo '[ SUBDOMAIN USE ONLY (Not Domain) ]'
        echo '[ Disable DOMAIN_NAME_ONLY Line, If Also Installing phpMyAdmin ]'
        echo '[ OR ]'
        echo '[ Change DOMAIN_NAME_ONLY To bar.com Portion Of foo.bar.com Subdomain ]'
        echo
        echo "<VirtualHost *:80>"
        echo "    ServerName $DOMAIN_NAME"
        echo "    # DISABLE FOLLOWING LINE If Also Enabling phpmyadmin.$DOMAIN_NAME"
        echo "    ServerAlias $DOMAIN_NAME *.DOMAIN_NAME_ONLY"
        echo "    ServerAdmin $ADMIN_EMAIL"
        echo "    DocumentRoot /srv/www/$DOMAIN_NAME/public_html/"
        echo "    <Directory />  # required for Apache v2.4 in Ubuntu v14.04.pre"
        echo "        Require all granted"
        echo "    </Directory>"
        echo "    # ENABLE FOLLOWING LINE If Using Google Webmaster Tools, Robots Testing Tool; Assumes Github Repo In /home/$USERNAME/public_html/$DOMAIN_NAME-latest"
        echo "#    Alias    /googleSOMELONGNUMBER.html    /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/googleSOMELONGNUMBER.html"
        echo "    ErrorLog /srv/www/$DOMAIN_NAME/logs/error.log"
        echo "    CustomLog /srv/www/$DOMAIN_NAME/logs/access.log combined"
        echo "</VirtualHost>"
        echo
        S "$EDITOR /etc/apache2/sites-available/$DOMAIN_NAME.conf"
 
        echo '[ Create Test HTML Page ]'
        S mkdir -p /srv/www/$DOMAIN_NAME/public_html
        S mkdir /srv/www/$DOMAIN_NAME/logs
        S "echo '$DOMAIN_NAME lives!' > /srv/www/$DOMAIN_NAME/public_html/index.html"  # DEV NOTE: must wrap redirects in quotes
        echo '[ Disable Default Placeholder "It Works" Page, May Be Required For Other Domains To Work Properly ]'
        S a2dissite 000-default
        echo '[ Enable Domain ]'
        S a2ensite $DOMAIN_NAME
        S service apache2 reload
        echo '[ Ensure Correct User & Group & Permissions ]'
        S chown -R www-data.www-data /srv/www
        S chmod -R g+rwX /srv/www
        S chmod -R o-w /srv/www
        echo '[ Check If Apache Is Running & You Can Successfully Load The Live Page ]'
        echo
        echo " http://$DOMAIN_NAME"
        echo
        C 'Please load the URL above in your web browser.'

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 33 ]; then
    echo '33. [[[ UBUNTU LINUX, INSTALL MYSQL & PHPMYADMIN ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Do NOT configure Apache automatically ]'
        echo '[ DO     configure database with dbconfig-common ]'
        echo
        S apt-get install mysql-server mysql-client libmysqlclient-dev phpmyadmin
        echo '[ UBUNTU v16.04 OR NEWER ONLY: Install Additional PHP Package ]'
        S apt-get install php-mbstring
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 34 VARIABLES
MCRYPT_INI='__EMPTY__'
MCRYPT_SO='__EMPTY__'

if [ $MENU_CHOICE -le 34 ]; then
    echo '34. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's PUBLIC e-mail address"
        ADMIN_EMAIL=$USER_INPUT

        echo '[ Check MySQL Version Number, For Use In Next Steps ]'
        B mysql -V
        echo '[ MYSQL VERSION 5.5 OR OLDER ONLY: Ensure MySQL Setting have_innodb Is Set To YES ]'
        echo '[ MYSQL VERSION 5.5 OR OLDER ONLY: Copy Command From The Following Line, Check Return Value As Shown Below ]'
        echo
        echo "mysql> SHOW VARIABLES LIKE 'have_innodb';"
        echo "+---------------+-------+"
        echo "| Variable_name | Value |"
        echo "+---------------+-------+"
        echo "| have_innodb   | YES   |"
        echo "+---------------+-------+"
        echo "mysql> QUIT"
        echo
        echo

        echo '[ MYSQL VERSION 5.6 OR NEWER ONLY: Ensure MySQL InnoDB Engine Support Column Is Set To YES Or DEFAULT ]'
        echo '[ MYSQL VERSION 5.6 OR NEWER ONLY: Copy Command From The Following Line, Check Return Value As Shown Below ]'
        echo
        echo "mysql> SHOW ENGINES;"
        echo "+--------------------+---------+----------------------------------------------------------------+--------------+------+------------+"
        echo "| Engine             | Support | Comment                                                        | Transactions | XA   | Savepoints |"
        echo "+--------------------+---------+----------------------------------------------------------------+--------------+------+------------+"
        echo "| ...                | ...     | ...                                                            | ...          | ...  | ...        |"
        echo "| InnoDB             | DEFAULT | Supports transactions, row-level locking, and foreign keys     | YES          | YES  | YES        |"
        echo "| ...                | ...     | ...                                                            | ...          | ...  | ...        |"
        echo "+--------------------+---------+----------------------------------------------------------------+--------------+------+------------+"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password

        echo "[ Manually Edit Apache Domain Config File /etc/apache2/sites-available/phpmyadmin.$DOMAIN_NAME.conf ]"
        echo '[ Automatically Using Subdomain Configuration ]'
        echo '[ Copy Data From The Following Lines, Then Paste Into Apache Domain Config File ]'
        echo
        echo "<VirtualHost *:80>"
        echo "     ServerName phpmyadmin.$DOMAIN_NAME"
        echo "     ServerAdmin $ADMIN_EMAIL"
        echo "     DocumentRoot /srv/www/phpmyadmin.$DOMAIN_NAME/public_html/"
        echo "     <Directory />  # required for Apache v2.4 in Ubuntu v14.04.pre"
        echo "        Require all granted"
        echo "     </Directory>"
        echo "     ErrorLog /srv/www/phpmyadmin.$DOMAIN_NAME/logs/error.log"
        echo "     CustomLog /srv/www/phpmyadmin.$DOMAIN_NAME/logs/access.log combined"
        echo "</VirtualHost>"
        echo
        S $EDITOR /etc/apache2/sites-available/phpmyadmin.$DOMAIN_NAME.conf

        echo '[ Create phpMyAdmin Directories, Start phpMyAdmin Service ]'
        S mkdir -p /srv/www/phpmyadmin.$DOMAIN_NAME/logs
        S ln -s /usr/share/phpmyadmin/ /srv/www/phpmyadmin.$DOMAIN_NAME/public_html
        S a2ensite phpmyadmin.$DOMAIN_NAME
        S service apache2 reload

        echo '[ Fix Error, "The mcrypt extension is missing." ]'
        echo '[ NOTE: updatedb Command May Take A Long Time ]'
        S updatedb
        S locate mcrypt.ini
        P $MCRYPT_INI "full path to the 'mcrypt.ini' file as returned by the locate command above (not '20-mcrypt.ini' or other similar files)"
        MCRYPT_INI=$USER_INPUT
        S locate mcrypt.so
        P $MCRYPT_SO "full path to the 'mcrypt.so' file as returned by the locate command above (not 'libmcrypt.so.4.4.8' or other similar files)"
        MCRYPT_SO=$USER_INPUT
        echo "[ Copy Data From The Following Line, Then Paste Into mcrypt Config File $MCRYPT_INI, Replacing Existing Line ]"
        echo "extension=$MCRYPT_SO"
        echo
        S $EDITOR $MCRYPT_INI
        S php5enmod mcrypt
        S service apache2 reload

        echo '[ Check If phpMyAdmin Is Running & You Can Successfully Log In ]'
        echo
        echo " http://phpmyadmin.$DOMAIN_NAME"
        echo
        C "Please load the URL above in your web browser, and log in using the 'root' mysql user & password."
        echo '[ If Your Browser Received The Subdomain Apache Page Instead Of phpMyAdmin, Then Disable DOMAIN_NAME_ONLY Line In Apache Site Config File ]'
        S "$EDITOR /etc/apache2/sites-available/$DOMAIN_NAME.conf"
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 35 ]; then
    echo '35. [[[ UBUNTU LINUX, INSTALL WEBMIN ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        echo "[ Copy Data From The Following Line, Then Paste Into Apt Config File /etc/apt/sources.list ]"
        echo 'deb http://download.webmin.com/download/repository sarge contrib'
        echo
        S $EDITOR /etc/apt/sources.list
        S 'wget -q http://www.webmin.com/jcameron-key.asc -O- | sudo apt-key add -'
        S apt-get update
        S apt-get install webmin
        C "Please Visit https://$DOMAIN_NAME:10000 To Ensure Webmin Is Enabled."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 36 ]; then
    echo '36. [[[ UBUNTU LINUX, INSTALL POSTFIX ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT

        echo '[ Enable Outgoing E-Mail ]'
        echo "[ For Internet Site Config Option, Use Fully-Qualified Domain Name $DOMAIN_NAME ]"
        S apt-get install postfix

        echo '[ Copy Data From The Following Line, Then Paste Into Postfix Config File /etc/postfix/main.cf, Replacing Existing Line ]'
        echo "myhostname = $DOMAIN_NAME"
        echo
        S $EDITOR /etc/postfix/main.cf

        echo '[ Update Postfix Config File /etc/postfix/main.cf, Allow For Greylisting Delivery Delay Times ]'
        S 'echo -e "\n# only try to deliver for 2 hours, wait 6 mins between attempts due to common 5-min greylisting delay\nmaximal_queue_lifetime = 2h\nmaximal_backoff_time = 15m\nminimal_backoff_time = 6m\nqueue_run_delay = 6m" >> /etc/postfix/main.cf'  # DEV NOTE: must wrap redirects in quotes

        echo '[ Start Postfix Service ]'
        S service postfix restart

        echo '[ Test Postfix Service, Outgoing Mail ]'
        echo '[ Copy SMTP Mail Commands One-By-One From The Following Lines, Then Paste Into telnet; Use Real E-Mail Address In RCPT Mail Command ]'
        echo "HELO $USERNAME"
        echo "MAIL FROM:$USERNAME@$DOMAIN_NAME"
        echo "RCPT TO:real@external.email.com"
        echo "DATA"
        echo "Subject:Postfix Mail Server Test"
        echo "howdy howdy howdy"
        echo "."
        echo "QUIT"
        echo
        B telnet localhost 25
        echo '[ Check Postfix Queue For Test Postfix Message In Previous Step, Delivery May Be Delayed Due To Greylisting ]'
        S postqueue -p

        echo '[ Test Postfix Service, Incoming Mail ]'
        # NEED FIX: Incoming E-Mail Not Yet Verified
        echo "If you plan to receive incoming e-mail, then please ensure the MX mail exchange record is set in your hosting provider's DNS coniguration."
        echo "Then, send a test message from your external e-mail account to the new $USERNAME@$DOMAIN_NAME e-mail account, which should show up via mail below."
        echo
        C 'Follow the directions above.'
        S apt-get install mailutils
        B mail
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 37 ]; then
    echo '37. [[[ PERL, INSTALL LATEST CATALYST ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: Do NOT Mix With Non-Latest Catalyst Via apt In Section 38! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ NOTE: Installing Latest Catalyst Via CPAN May Take Over An Hour To Complete ]'
        B cpanm Task::Catalyst Catalyst::Devel
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 38 ]; then
    echo '38. [[[ UBUNTU LINUX, INSTALL NON-LATEST CATALYST ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: Do NOT Mix With Latest Catalyst Via CPAN In Section 37! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install libmodule-install-perl libcatalyst-engine-apache-perl
        S service apache2 restart
        S apt-get install libcatalyst-devel-perl libcatalyst-modules-perl
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 39 ]; then
    echo '39. [[[ PERL, CHECK CATALYST VERSIONS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        B dpkg -p libcatalyst-perl
        # NEED ANSWER: why do we have the following step for creating missing @INC directories???
        echo
        echo '[ Please Look For All Directories In @INC, In The Output Of The perl -V Command Below ]'
        echo '[ Then, For Each Directory In @INC, Perform The Following ]'
        echo '$ ls -ld /PATH/TO/DIRECTORY'
        echo
        echo '[ Finally, For Each Directory In @INC Which Does Not Already Exist, Perform The Following ]'
        echo '$ sudo mkdir -p /PATH/TO/DIRECTORY'
        B perl -V

        echo '[ View Versions Of Catalyst & Related Perl Modules ]'
        B 'perl -MCatalyst::Runtime\ 999'
        B 'perl -MCatalyst::Devel\ 999'
        B 'perl -MDBIx::Class\ 999'
        B 'perl -MCatalyst::Model::DBIC::Schema\ 999'
        B 'perl -MHTML::FormFu\ 999'
        B 'perl -MTemplate\ 999'
        B 'perl -MDBD::mysql\ 999'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 40 VARIABLES
MYSQL_ROOTPASS='__EMPTY__'

if [ $MENU_CHOICE -le 40 ]; then
    echo '40. [[[ PERL, INSTALL RAPIDAPP ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        echo '[ You Should Use mysql & cpanm Instead Of git clone Below, Unless You Want The Experimental Version Or Have No Choice ]'
        echo '[ WARNING: Use Only ONE Of The Following Two Sets Of Commands, EITHER mysql & cpanm OR git clone, But NOT Both! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ MYSQL & CPANM ONLY: Ensure MySQL Configured To Support Perl Distribution DBD::mysql `make test` Command ]'
        echo '[ MYSQL & CPANM ONLY: Copy Command From The Following Line ]'
        echo "mysql> CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '';"
        echo "mysql> GRANT ALL PRIVILEGES ON test.* TO '$USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password
        echo '[ MYSQL & CPANM ONLY: Install RapidApp via CPAN ]'
        B cpanm DBD::mysql MooseX::NonMoose RapidApp
        # OR
        echo '[ GIT ONLY: Install RapidApp via GitHub ]'
        B git clone https://github.com/vanstyn/RapidApp.git ~/RapidApp-latest  # DEV NOTE: no makefile on github, can't make or install

        P $MYSQL_ROOTPASS "MySQL root Password"
        MYSQL_ROOTPASS=$USER_INPUT
        echo "[ EITHER OPTION: phpMyAdmin Demo App, Username 'admin', Password 'pass' ]"
        B "mkdir -p ~/public_html; cd ~/public_html; rapidapp.pl --helpers RapidDbic,Templates,TabGui,AuthCore,NavCore RapidApp_phpmyadmin_database -- --dsn dbi:mysql:database=phpmyadmin,root,'$MYSQL_ROOTPASS'"
        B 'cd ~/public_html/RapidApp_phpmyadmin_database; perl Makefile.PL; make; make test'
        B ~/public_html/RapidApp_phpmyadmin_database/script/rapidapp_phpmyadmin_database_server.pl

        echo "[ EITHER OPTION: BlueBox Demo App, Username 'admin', Password 'pass' ]"
        B git clone https://github.com/vanstyn/BlueBox.git ~/BlueBox-latest
        B 'cd ~/BlueBox-latest; perl Makefile.PL; cpanm --installdeps .'  # DEV NOTE: no make or test here, either
        B script/bluebox_server.pl
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 41 ]; then
    echo '41. [[[ UBUNTU LINUX, INSTALL SHINYCMS DEPENDENCIES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $UBUNTU_RELEASE_NAME 'Ubuntu release name (trusty, xenial, etc.)' 'xenial'
        UBUNTU_RELEASE_NAME=$USER_INPUT
        echo '[ WARNING: Prerequisite Dependencies Include Full LAMP Stack (Sections 0 - 11, 21 - 24); mod_perl (Section 31) OR mod_fastcgi (This Section); Postfix (Section 36); And Expat, etc (This Section). ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ Install Expat, etc ]'
        S sudo apt-get install expat libexpat1-dev libxml2-dev zlib1g-dev
        echo '[ Install FastCGI ]'
        echo '[ Copy Data From The Following Lines, Then Paste Into The Apt Config File /etc/apt/sources.list, OR Uncomment Equivalent Existing Lines ]'
        echo "deb http://us.archive.ubuntu.com/ubuntu/ $UBUNTU_RELEASE_NAME multiverse      # needed for FastCGI"
        echo "deb-src http://us.archive.ubuntu.com/ubuntu/ $UBUNTU_RELEASE_NAME multiverse  # needed for FastCGI"
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        S apt-get -f install
        S apt-get install libapache2-mod-fastcgi
        echo '[ Now Comment Or Delete The Same 2 Lines You Just Added To The Apt Config File /etc/apt/sources.list ]'
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        S apt-get -f install
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 42 ]; then
    echo  '42. [[[ PERL SHINYCMS, INSTALL SHINYCMS DEPENDENCIES & SHINYCMS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        echo '[ Ensure MySQL Configured To Support Perl Distribution DBD::mysql `make test` Command ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '';"
        echo "mysql> GRANT ALL PRIVILEGES ON test.* TO '$USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password
        echo '[ Install ShinyCMS Dependencies Via CPAN ]'
        B cpanm DBD::mysql Devel::Declare::MethodInstaller::Simple Text::CSV_XS inc::Module::Install Module::Install::Catalyst Test::Pod Test::Pod::Coverage
        B mkdir -p ~/public_html
        echo '[ Install MyShinyTemplate (ShinyCMS Fork) Via Github ]'
        B "wget https://github.com/wbraswell/myshinytemplate.com/archive/master.zip; unzip master.zip; mv myshinytemplate.com-master ~/public_html/$DOMAIN_NAME-latest; rm master.zip"
        B "cd ~/public_html/$DOMAIN_NAME-latest; perl Makefile.PL; cpanm --installdeps .; cpanm --installdeps ."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 43 VARIABLES
DOMAIN_NAME_UNDERSCORES='__EMPTY__'
DOMAIN_NAME_NO_USER='__EMPTY__'
MYSQL_USERNAME='__EMPTY__'
MYSQL_USERNAME_DEFAULT='__EMPTY__'
MYSQL_PASSWORD='__EMPTY__'
SITE_NAME='__EMPTY__'
SITE_NAME_DEFAULT='__EMPTY__'
ADMIN_FIRST_NAME='__EMPTY__'
ADMIN_LAST_NAME='__EMPTY__'

if [ $MENU_CHOICE -le 43 ]; then
    echo  '43. [[[ PERL SHINYCMS, CREATE DATABASE & EDIT MYSHINYTEMPLATE FILES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME_UNDERSCORES//-/_}  # replace hyphens with underscores
        DOMAIN_NAME_NO_USER=$DOMAIN_NAME
        DOMAIN_NAME_NO_USER+='__no_user'
        MYSQL_USERNAME_DEFAULT=`expr match "$DOMAIN_NAME" '\([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*\)'`  # extract lowest-level hostname
        SITE_NAME_DEFAULT=$MYSQL_USERNAME_DEFAULT
        D $SITE_NAME "optional 'CamelCase' version of hostname $SITE_NAME_DEFAULT to be used as descriptive site name, NO SPACES, MAKE IT MATCH YOUR HOSTNAME" $SITE_NAME_DEFAULT
        SITE_NAME=$USER_INPUT
        MYSQL_USERNAME_DEFAULT+='_user'
        D $MYSQL_USERNAME "new mysql username to be created, 16 characters maximum length (different than new machine's OS username)" $MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME=$USER_INPUT
        P $MYSQL_PASSWORD "new mysql password"
        MYSQL_PASSWORD=$USER_INPUT
        P $ADMIN_FIRST_NAME "website administrator's first name"
        ADMIN_FIRST_NAME=$USER_INPUT
        P $ADMIN_LAST_NAME "website administrator's last name"
        ADMIN_LAST_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's PUBLIC e-mail address"
        ADMIN_EMAIL=$USER_INPUT

        echo '[ Create ShinyCMS Database In MySQL ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE DATABASE $DOMAIN_NAME_UNDERSCORES;"
        echo "mysql> CREATE USER '$MYSQL_USERNAME'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
        echo "mysql> GRANT ALL PRIVILEGES ON $DOMAIN_NAME_UNDERSCORES.* TO '$MYSQL_USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password

        echo '[ Create ShinyCMS Config File ]'
        CD ~/public_html/$DOMAIN_NAME-latest
        B 'rm modified/shinycms.conf; mv shinycms.conf.redacted modified/shinycms.conf; ln -s modified/shinycms.conf ./shinycms.conf'
        B sed -ri -e "s/NEED_USERNAME/$USERNAME/g" shinycms.conf
        B sed -ri -e "s/NEED_DOMAIN_NAME/$DOMAIN_NAME/g" shinycms.conf
        B sed -ri -e "s/NEED_ADMIN_FIRST_NAME/$ADMIN_FIRST_NAME/g" shinycms.conf
        B sed -ri -e "s/NEED_ADMIN_LAST_NAME/$ADMIN_LAST_NAME/g" shinycms.conf
        B sed -ri -e "s/NEED_ADMIN_EMAIL/$ADMIN_EMAIL/g" shinycms.conf
        B sed -ri -e "s/MyShinyTemplate/$SITE_NAME/g" shinycms.conf
        B sed -ri -e "s/myshinytemplate_com/$DOMAIN_NAME_UNDERSCORES/g" shinycms.conf
        B sed -ri -e "s/myshinytemplate\.com/$DOMAIN_NAME/g" shinycms.conf
        B sed -ri -e "s/template_user/$MYSQL_USERNAME/g" shinycms.conf
        B sed -ri -e "s/REDACTED/$MYSQL_PASSWORD/g" shinycms.conf

        echo '[ Create ShinyCMS Appendant Files ]'
        B make clean
        MYSHINY_FILES=$(grep -Elr --binary-files=without-match myshiny ./*)
        B sed -ri -e "s/NEED_USERNAME/$USERNAME/g" $MYSHINY_FILES
        B sed -ri -e "s/NEED_DOMAIN_NAME/$DOMAIN_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/NEED_ADMIN_FIRST_NAME/$ADMIN_FIRST_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/NEED_ADMIN_LAST_NAME/$ADMIN_LAST_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/NEED_ADMIN_EMAIL/$ADMIN_EMAIL/g" $MYSHINY_FILES
        B sed -ri -e "s/MyShinyTemplate/$SITE_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/myshinytemplate_com/$DOMAIN_NAME_UNDERSCORES/g" $MYSHINY_FILES
        B sed -ri -e "s/myshinytemplate\.com/$DOMAIN_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/template_user/$MYSQL_USERNAME/g" $MYSHINY_FILES
        
        CD ~/public_html/$DOMAIN_NAME-latest/modified
        B mv fastcgi_start__myshinytemplate.com.sh fastcgi_start__$DOMAIN_NAME.sh
        B mv fastcgi_myshinytemplate.com.conf fastcgi_$DOMAIN_NAME.conf
        B mv fastcgi_myshinytemplate.com-init.d fastcgi_$DOMAIN_NAME-init.d
        B mv git_backup__myshinytemplate.com.sh git_backup__$DOMAIN_NAME.sh
        B mv git_merge_modified__myshinytemplate.com.sh git_merge_modified__$DOMAIN_NAME.sh
        B "mv mysqldump__myshinytemplate.com__no_user.sh.redacted mysqldump__$DOMAIN_NAME_NO_USER.sh.redacted"  # DO NOT ADD PASSWORD HERE
        B mkdir -p ~/bin
        B cp mysqldump__$DOMAIN_NAME_NO_USER.sh.redacted ~/bin/mysqldump__$DOMAIN_NAME_NO_USER.sh
        B sed -ri -e "s/REDACTED/'$MYSQL_PASSWORD'/g" ~/bin/mysqldump__$DOMAIN_NAME_NO_USER.sh  # ADD PASSWORD, USE SINGLE QUOTES IN CASE OF SPECIAL CHARACTERS
        B ln -s ~/public_html/$DOMAIN_NAME-latest/modified/*.sh ~/bin
        echo "[ Ensure Only User $USERNAME Can Read Files Which May Contain Passwords ]"
        B chmod -R go-rwx ~/bin

        echo '[ Ensure No ShinyCMS Appendant File Templates Remain ]'
        CD ~/public_html/$DOMAIN_NAME-latest
        B rm backup/*.bz2
        B 'grep -nr myshiny ./*'
        B 'grep -nr MyShiny ./*'
        B 'find | grep myshiny'
        B 'find | grep MyShiny'
        B 'find | grep template_user'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 44 ]; then
    echo  '44. [[[ PERL SHINYCMS, BUILD DEMO DATABASE & RUN TESTS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        CD ~/public_html/$DOMAIN_NAME-latest
        echo '[ WARNING: Only Utilize ONE Of The Following Build Commands, Either With Or Without Demo Data ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ Build Database WITHOUT Demo Data ]'
        B ./bin/database/build
        echo '[ Build Database WITH Demo Data ]'
        B ./bin/database/build-with-demo-data
        TEST_POD=1
        echo '[ Run Test Suite ]'
        B 'perl Makefile.PL; make; make test'
        echo '[ Run Stand-Alone (Non-Apache) Testing Web Server ]'
        echo '[ WARNING: Log In To Testing Web Server, To Change All ShinyCMS User Passwords Now! ]'
        C 'Please read the warning above.  Seriously.'
        echo "[ Username 'admin', Password 'changeme' ]"
        echo "[ Click Admin area -> Users -> List users -> Change passwords for 'admin' & 'trevor' & 'w1n5t0n' ]"
        echo '[ Log Out Then Log Back In To Test New Passwords ]'
        echo '[ End Testing Web Server When Passwords Have Been Successfully Changed ]'
        echo
        B ./script/shinycms_server.pl
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 45 VARIABLES
DOMAIN_NAME_UNDERSCORES_NO_USER='__EMPTY__'

if [ $MENU_CHOICE -le 45 ]; then
    echo  '45. [[[ PERL SHINYCMS, BACKUP & RESTORE DATABASE ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_UNDERSCORES_NO_USER=$DOMAIN_NAME_UNDERSCORES
        DOMAIN_NAME_UNDERSCORES_NO_USER+='__no_user'
        MYSQL_USERNAME_DEFAULT=`expr match "$DOMAIN_NAME" '\([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*\)'`  # extract lowest-level hostname
        MYSQL_USERNAME_DEFAULT+='_user'
        D $MYSQL_USERNAME "mysql username (different than new machine's OS username)" $MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME=$USER_INPUT
        P $MYSQL_PASSWORD "mysql password"
        MYSQL_PASSWORD=$USER_INPUT
        echo '[ WARNING: Use Only One Of The Following Backup Commands, No Need To Use Both ]'
        C 'Please read the warning above.  Seriously.'

        echo '[ Backup Database, Do NOT Include ShinyCMS User & Password Data, Export Raw sql File ]'
        B "mysqldump --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES --lock-tables --ignore-table=$DOMAIN_NAME_UNDERSCORES.user > $DOMAIN_NAME_UNDERSCORES_NO_USER.sql"

        echo '[ Backup Database, DO Include ShinyCMS User & Password Data, Export Raw sql File ]'
        B "mysqldump --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES --lock-tables > $DOMAIN_NAME_UNDERSCORES.sql"

        echo '[ Restore Database, Create Empty Database To Receive Restoration ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE DATABASE $DOMAIN_NAME_UNDERSCORES;"
        echo "mysql> CREATE USER '$MYSQL_USERNAME'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
        echo "mysql> GRANT ALL PRIVILEGES ON $DOMAIN_NAME_UNDERSCORES.* TO '$MYSQL_USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password

        echo '[ WARNING: Use Only One Of The Following Restore Commands, Do NOT Use Both ]'
        C 'Please read the warning above.  Seriously.'

        echo '[ Restore Database, Do NOT Include ShinyCMS User & Password Data, Import Raw sql File ]'
        B "mysql --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES < $DOMAIN_NAME_UNDERSCORES_NO_USER.sql"

        echo '[ Restore Database, DO Include ShinyCMS User & Password Data, Import Raw sql File ]'
        B "mysql --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES < $DOMAIN_NAME_UNDERSCORES.sql"
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 46 ]; then
    echo  '46. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_FASTCGI ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD Use This Section Instead Of Apache mod_perl In Section 47, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With Apache mod_perl In Section 47! ]'
        C 'Please read the warning above.  Seriously.'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        P $ADMIN_FIRST_NAME "website administrator's first name"
        ADMIN_FIRST_NAME=$USER_INPUT
        P $ADMIN_LAST_NAME "website administrator's last name"
        ADMIN_LAST_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's PUBLIC e-mail address"
        ADMIN_EMAIL=$USER_INPUT
        echo '[ Install FastCGI Via CPAN, Enable FastCGI Module In Apache ]'
        B cpanm FCGI FCGI::ProcManager
        S a2enmod fastcgi

        # NEED UPDATE: add support for Google Webmaster Tools
        echo '[ Create Apache Config File ]'

APACHE_CONFIG_OUTPUT=$(cat <<END_HEREDOC
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    ServerAdmin $ADMIN_EMAIL
#    DocumentRoot /srv/www/$DOMAIN_NAME/public_html/  # mod_fastcgi overrides below
    <Directory />  # required for Apache v2.4 in Ubuntu v14.04.pre
        Require all granted
    </Directory>
    ErrorLog /srv/www/$DOMAIN_NAME/logs/error.log
    CustomLog /srv/www/$DOMAIN_NAME/logs/access.log combined
# MOD_FASTCGI
    DocumentRoot    /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root
    <Location />
        Order allow,deny
        Allow from all
    </Location>
    # ENABLE FOLLOWING LINE If Using Google Webmaster Tools, Robots Testing Tool; Assumes Github Repo In /home/$USERNAME/public_html/$DOMAIN_NAME-latest
#    Alias    /googleSOMELONGNUMBER.html    /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/googleSOMELONGNUMBER.html
    # Allow Apache to serve static content.
    Alias       /static     /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/static
    <Location /static>  # NEED ANSWER: is this line necessary?
        SetHandler          default-handler
    </Location>
    # Display friendly error page if the FastCGI process is not running.
    ErrorDocument   502     /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/offline.html
    # Connect to the external server.
    FastCgiExternalServer   /tmp/$DOMAIN_NAME.fcgi -socket /tmp/$DOMAIN_NAME.socket -idle-timeout 900
    Alias           /       /tmp/$DOMAIN_NAME.fcgi/
</VirtualHost>
END_HEREDOC
)

        echo "[ Copy Data From The Following Lines, Then Paste Into The Apache Site Config File /etc/apache2/sites-available/$DOMAIN_NAME.conf, Replacing Existing Content ]"
        echo
        echo "$APACHE_CONFIG_OUTPUT"
        echo
#        S "echo '$APACHE_CONFIG_OUTPUT' > /etc/apache2/sites-available/$DOMAIN_NAME.conf"  # DEV NOTE: content too long to fit inside a variable?
        S $EDITOR /etc/apache2/sites-available/$DOMAIN_NAME.conf
        S "echo \"<b>ERROR 502:</b> FastCGI Process Not Running, Please Inform Site Administrator <a href='mailto:$ADMIN_EMAIL'>$ADMIN_FIRST_NAME $ADMIN_LAST_NAME</a>\" > /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/offline.html"

        echo '[ WARNING: Choose ONLY ONE Of The Following Options To Start FastCGI Service! ]'
        echo '[ 4 Options Include: Manual local::lib; Manual Perlbrew; Automatic Upstart; Automatic SysVinit ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ Start FastCGI Service, Manual, local::lib ]'
        echo "[ Run As Non-Root User $USERNAME By User $USERNAME, Must Have Created Symlinks In Section 43 (EDIT MYSHINYTEMPLATE FILES) ]"
        B ~/bin/fastcgi_start__$DOMAIN_NAME.sh

        # OR

        echo '[ Start FastCGI Service, Manual, Perlbrew ]'
        echo "[ Run As Non-Root User $USERNAME By User root ]"
        S -Eu $USERNAME /home/$USERNAME/public_html/$DOMAIN_NAME-latest/bin/external-fastcgi-server  
        B cat /tmp/$DOMAIN_NAME.pid

        # OR

        echo '[ Start FastCGI Service, Automatic, Upstart (Most Modern Linux Distributions) ]'
        S ln -s /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME.conf /etc/init
        S initctl reload-configuration  # OR    $ reboot
        S "initctl list | grep $DOMAIN_NAME"
        S service fastcgi_$DOMAIN_NAME start
        S service fastcgi_$DOMAIN_NAME status

        # OR

        echo '[ Start FastCGI Service, Automatic, SysVinit (Older Linux Distributions) ]'
        S ln -s /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME-init.d /etc/init.d
        S reboot

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 47 ]; then
    echo  '47. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_PERL ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You Should NOT Use This Section Instead Of Apache mod_fastcgi In Section 46, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With Apache mod_fastcgi In Section 46! ]'
        C 'Please read the warning above.  Seriously.'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        P $ADMIN_FIRST_NAME "website administrator's first name"
        ADMIN_FIRST_NAME=$USER_INPUT
        P $ADMIN_LAST_NAME "website administrator's last name"
        ADMIN_LAST_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's PUBLIC e-mail address"
        ADMIN_EMAIL=$USER_INPUT

        # NEED UPDATE: add support for Google Webmaster Tools
        echo '[ Create Apache Config File ]'

APACHE_CONFIG_OUTPUT=$(cat <<END_HEREDOC
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    ServerAdmin $ADMIN_EMAIL
    DocumentRoot /srv/www/$DOMAIN_NAME/public_html/
    <Directory />  # required for Apache v2.4 in Ubuntu v14.04.pre
        Require all granted
    </Directory>
    # ENABLE FOLLOWING LINE If Using Google Webmaster Tools, Robots Testing Tool; Assumes Github Repo In /home/$USERNAME/public_html/$DOMAIN_NAME-latest
#    Alias    /googleSOMELONGNUMBER.html    /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/googleSOMELONGNUMBER.html
    ErrorLog /srv/www/$DOMAIN_NAME/logs/error.log
    CustomLog /srv/www/$DOMAIN_NAME/logs/access.log combined
    <Perl>
        use lib '/home/$USERNAME/public_html/$DOMAIN_NAME-latest/lib';  # ShinyCMS
        use lib '/home/$USERNAME/perl5/lib/perl5';  # local::lib
    </Perl>
#   PerlRequire     /home/$USERNAME/public_html/$DOMAIN_NAME/.../startup.pl  # handled by 'use lib' code above 
    PerlModule      ShinyCMS
    Alias   /static     /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/static
    <Location />
        SetHandler          modperl 
        PerlResponseHandler +ShinyCMS
    </Location>
    <Location /static>  # NEED ANSWER: is this line necessary?
        SetHandler  default-handler
    </Location>
</VirtualHost>
END_HEREDOC
)

        echo "[ Copy Data From The Following Lines, Then Paste Into The Apache Site Config File /etc/apache2/sites-available/$DOMAIN_NAME.conf, Replacing Existing Content ]"
        echo
        echo "$APACHE_CONFIG_OUTPUT"
        echo
#        S "echo '$APACHE_CONFIG_OUTPUT' > /etc/apache2/sites-available/$DOMAIN_NAME.conf"  # DEV NOTE: content too long to fit inside a variable?
        S $EDITOR /etc/apache2/sites-available/$DOMAIN_NAME.conf
        S "echo \"<b>ERROR 502:</b> mod_perl Process Not Running, Please Inform Site Administrator <a href='mailto:$ADMIN_EMAIL'>$ADMIN_FIRST_NAME $ADMIN_LAST_NAME</a>\" > /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/offline.html"
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 48 ]; then
    echo  '48. [[[ PERL SHINYCMS, CREATE APACHE DIRECTORIES & ENABLE STATIC PAGE ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        S mkdir -p /srv/www/$DOMAIN_NAME/public_html
        S mkdir /srv/www/$DOMAIN_NAME/logs
        S "echo '$DOMAIN_NAME lives!' > /srv/www/$DOMAIN_NAME/public_html/index.html"
        S a2ensite $DOMAIN_NAME
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 49 ]; then
    echo  '49. [[[ PERL SHINYCMS, CONFIGURE APACHE PERMISSIONS & ENABLE DYNAMIC PAGES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT

        echo "[ Add $USERNAME To User Group www-data, Allows Web Content To Be Served From /home/$USERNAME ]"
        S usermod -aG www-data $USERNAME

        echo '[ Configure Operating System User/Group/Other Permissions ]'
#        S chown -R $USERNAME:www-data /home/$USERNAME/
        S chown -R $USERNAME:$USERNAME /home/$USERNAME/
        S chown $USERNAME:www-data /home/$USERNAME/
        S chown -R $USERNAME:www-data /home/$USERNAME/perl5
        S chown -R $USERNAME:www-data /home/$USERNAME/github_repos
        S chown -R $USERNAME:www-data /home/$USERNAME/public_html
        S chmod -R g+rX /home/$USERNAME/perl5
        S chmod -R g+rX /home/$USERNAME/github_repos
        S chmod -R u+rwX,o+rX,o-w /home/$USERNAME/public_html/$DOMAIN_NAME-latest
        S chmod -R g+rwX /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/static/cms-uploads/
        S chmod -R g+rX /home/$USERNAME/public_html
        S chmod g+rX /home/$USERNAME/

#        echo "[ Ensure Only User $USERNAME Can Read Files Which May Contain Passwords ]"
#        B chmod -R go-rwx ~/.:100-fakexinerama ~/.bash_logout ~/bin ~/.config ~/.dbus ~/.gitconfig ~/LAMP_installer.sh ~/.local ~/perl5 ~/.viminfo ~/.Xauthority ~/.xsession-errors ~/.bash_history ~/.bashrc ~/.cache ~/.cpanm ~/.fakexinerama ~/.gkrellm2 ~/.lesshst ~/.mysql_history ~/.profile ~/.ssh ~/.vimrc ~/.xpra
        S service apache2 reload
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 50 ]; then
    echo  '50. [[[ PERL SHINYCMS, CONFIGURE SHINY ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores

        echo '[ Change ShinyCMS Usernames In Database Via phpMyAdmin Web Interface ]'
        echo "http://phpmyadmin.$DOMAIN_NAME"
        echo "Database '$DOMAIN_NAME_UNDERSCORES' -> Table 'user' -> Change Usernames 'admin', 'trevor' & 'w1n5t0n'"
        echo
        C "Please follow the directions above..."

        echo '[ Configure ShinyCMS Settings via ShinyCMS Web Interface ]'
        echo "http://$DOMAIN_NAME"
        echo 'Login To ShinyCMS Web Interface As New Admin User From Database Update In Previous Step'
        echo 'Admin area -> Users -> List Users -> Change Passwords For All 3 Users (DOUBLE CHECK, SHOULD ALREADY BE DONE IN SECTION 37)'
        echo 'Admin area -> Users -> List Users -> Edit All 3 Users -> Update E-Mail, etc.'
        echo 'Admin area -> Pages -> List Form Handlers -> Edit Contact Form -> Update "E-mail To" Field'
        echo 'Admin area -> Pages -> List Pages -> Edit Home -> Add Image "/static/cms-uploads/images/homepage_added.png" Aligned Left & "Lorem Ipsum Dolor" Text'
        echo 'Admin area -> Pages -> List Templates -> Edit Homepage -> Delete "video_url" Element -> Update'
        echo
        C "Please follow the directions above..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#    CURRENT_SECTION_COMPLETE  # final section!
fi







if [ $MENU_CHOICE -le 51 ]; then
    echo  '51. [[[ PERL CLOUDFORFREE, FOOOOOO ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT

# [[[ PERL CLOUDFORFREE, PREREQUISITES ]]]

S apt-get install aptitude
S aptitude install apache2-dev
    # accept solution w/ downgrades only
S apt-get install libapache2-mod-perl2-dev

# download cloudforfree code

# `unbuffer` required by cloudforfree.org Code.pm
# Ubuntu v14.04
S vi /etc/apt/sources.list
    deb http://archive.ubuntu.com/ubuntu trusty-updates main universe
S apt-get update
S apt-get install expect-dev
# OR
# Ubuntu v16.04
S apt-get install expect


S apt-get install cpanm

S apt-get install libapreq2-3
S a2enmod apreq2


# [[[ GVIM, FIX ]]]

# NEED MOVE UP INTO SECTION 5
# BUG https://bugs.launchpad.net/bugs/1613949
vi /etc/apt/sources.list
    copy all "xenial" lines, paste as new "xenial-update" lines
apt-get update
apt-get install vim-gtk3  # example affected by 16.04.1 apt-get upgrade


# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, PREREQUISITES ]]]

# NON-CRITICAL BUG: Apache2::Request & Apache2::Upload, part of libapreq2
#In this file:
#libapreq2-2.13/module/t/conf/extra.conf
#generated by
#https://metacpan.org/source/ISAAC/libapreq2-2.13/module/t/conf/extra.conf.in
#The line which currently reads:
#LockFile @ServerRoot@/logs/accept.lock
#Should be changed to:
#Mutex file:@ServerRoot@/logs default

#Also, in the auto-generated file:
#libapreq2-2.13/module/t/conf/httpd.conf
#generated by ???
#The following 2 lines need to be added:
#Include /etc/apache2/mods-enabled/mpm*.load
#Include /etc/apache2/mods-enabled/mpm*.conf


# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER ]]]

#S cpanm Apache2::Request  # unnecessary, dependency of A2::FM below
S cpanm Apache2::FileManager
# installs in /usr/local/lib/x86_64-linux-gnu/perl/5.22.1 among other places?

# CRITICAL BUG: Apache2::FileManager
#In this file:
#https://metacpan.org/source/DAVVID/Apache2-FileManager-0.21/test.pl
#The line which currently reads:
#use Apache::FileManager;
#Should be changed to:
#use Apache2::FileManager;


# [[[ PERL CLOUDFORFREE, APACHE CONFIG ]]]

S ln -s /home/wbraswell/public_html/cloudforfree.org-latest/modified/user_files /srv/www/starman.autoparallel.com/public_html/user_files

S vi /etc/apache2/sites-enabled/FOO.conf

#...
#    DocumentRoot /home/wbraswell/public_html/cloudforfree.org-latest/root
#...
#<Location /FileManager>
#    SetHandler           perl-script
#    PerlHandler          Apache2::FileManager
#    PerlSetVar           DOCUMENT_ROOT /home/wbraswell/public_html/cloudforfree.org-latest/root/user_files
#</Location>


S service apache2 restart
# http://starman.autoparallel.com/FileManager

S chgrp www-data /home/wbraswell/
S chmod g+rX /home/wbraswell/




# [[[ PERL CLOUDFORFREE, PREREQUISITES, SYNTAX HIGHLIGHTERS ]]]

# ALL SYNTAX HIGHLIGHTERS
S apt-get install npm nodejs-legacy

# SyntaxHighlighter, Alex Gorbatchev
# https://github.com/syntaxhighlighter/syntaxhighlighter/wiki/Building
CD ~/github_repos
B git clone https://github.com/syntaxhighlighter/syntaxhighlighter.git syntaxhighlighter-latest
CD syntaxhighlighter-latest
B npm install
B ./node_modules/.bin/gulp setup-project
B ./node_modules/.bin/gulp build --brushes=perl --theme=default


# CodeMirror, Marijn Haverbeke
CD ~/github_repos
B git clone https://github.com/codemirror/CodeMirror.git codemirror-latest
CD codemirror-latest
B npm install
B npm run build
# browse to index.html
B npm test


# Ace, Ajax.org Cloud9 Editor
# https://github.com/ajaxorg/ace
B git clone https://github.com/ajaxorg/ace.git ace-latest
CD ace-latest
B node ./static.js
# browse to http://localhost:8888/kitchen-sink.html
# optional extra build
B npm install
B node ./Makefile.dryice.js
# OR
B node ./Makefile.dryice.js full --target ../ace-builds
B node lib/ace/test/all.js
# browse to http://localhost:8888/lib/ace/test/tests.html

# Ace Builds
B git clone https://github.com/ajaxorg/ace-builds/ ace-builds-latest
# browse to editor.html
# browse to kitchen-sink.html


# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, COMPILE PERL & MODPERL ]]]

# non-threaded Perl, libperl.a
# B wget NEED_URL
# B NEED UNZIP COMMAND
# CD NEED_DIRECTORY
B "./Configure -des -Uusethreads -Doptimize='-g' -Dusedevel -Accflags=-fPIC"
B make
B make test
S make install

# non-threaded Perl, libperl.so
B "./Configure -des -Uusethreads -Doptimize='-g' -Dusedevel -Duseshrplib"
B make
B make test
S make install

# MOD_PERL, SYSTEM TO BUILD, UNTHREADED
# NEED DOWNLOAD & UNZIP
B perl Makefile.PL MP_APXS=/usr/bin/apxs MP_NO_THREADS=1
B make
B make test
S make install


# PERL, BUILD TO SYSTEM
S mv /usr/bin/perl /usr/bin/perl.BUILD_PERL_DISABLED
S mv /usr/bin/perl.SYSTEM_PERL_DISABLED /usr/bin/perl

# LIBPERL, BUILD TO SYSTEM
S rm /usr/lib/x86_64-linux-gnu/libperl.a 
S cp /home/wbraswell/perl_build/libperl.a.SYSTEM_PERL_DISABLED /usr/lib/x86_64-linux-gnu/libperl.a 
S rm /usr/lib/x86_64-linux-gnu/libperl.so.5.22.1
S cp /home/wbraswell/perl_build/libperl.so.5.22.1.SYSTEM_PERL_DISABLED /usr/lib/x86_64-linux-gnu/libperl.so.5.22.1

# PERL INSTALL DIRS, NOT DISABLED
# /usr/local/lib/x86_64-linux-gnu/perl/5.22.1  Apache2::FileManager, APR::Request, Apache2::Request, Apache2::Upload 

# PERL INSTALL DIRS, BUILD TO SYSTEM
S mv /usr/lib/x86_64-linux-gnu/perl5/5.22 /usr/lib/x86_64-linux-gnu/perl5/5.22.BUILD_PERL_DISABLED
S mv /usr/lib/x86_64-linux-gnu/perl5/5.22.SYSTEM_PERL_DISABLED /usr/lib/x86_64-linux-gnu/perl5/5.22
S mv /usr/lib/x86_64-linux-gnu/perl/5.22.1 /usr/lib/x86_64-linux-gnu/perl/5.22.1.BUILD_PERL_DISABLED
S mv /usr/lib/x86_64-linux-gnu/perl/5.22.1.SYSTEM_PERL_DISABLED /usr/lib/x86_64-linux-gnu/perl/5.22.1
S mv /usr/lib/x86_64-linux-gnu/perl-base /usr/lib/x86_64-linux-gnu/perl-base.BUILD_PERL_DISABLED
S mv /usr/lib/x86_64-linux-gnu/perl-base.SYSTEM_PERL_DISABLED /usr/lib/x86_64-linux-gnu/perl-base
S mv /usr/local/lib/perl5/site_perl/5.22.1/x86_64-linux /usr/local/lib/perl5/site_perl/5.22.1/x86_64-linux.BUILD_PERL_DISABLED
S mv /usr/local/lib/perl5/site_perl/5.22.1/x86_64-linux.SYSTEM_PERL_DISABLED /usr/local/lib/perl5/site_perl/5.22.1/x86_64-linux
S mv /usr/local/lib/perl5/5.22.1 /usr/local/lib/perl5/5.22.1.BUILD_PERL_DISABLED
S mv /usr/local/lib/perl5/5.22.1.SYSTEM_PERL_DISABLED /usr/local/lib/perl5/5.22.1

S mv /home/$USERNAME/perl5 /home/$USERNAME/perl5.BUILD_PERL_DISABLED
S mv /home/$USERNAME/perl5.SYSTEM_PERL_DISABLED /home/$USERNAME/perl5

# PERL CODE, DISABLE BAD MODULE
S mv /usr/lib/x86_64-linux-gnu/perl5/5.22/Data/Alias.pm /usr/lib/x86_64-linux-gnu/perl5/5.22/Data/Alias.pm.SEGFAULT_DISABLED


# MOD_PERL, UBUNTU SYSTEM TO CPAN SYSTEM
S apt-get remove libapache2-mod-perl2
S apt-get install aptitude
S aptitude install apache2-dev
CD /usr/lib/x86_64-linux-gnu/
S ln -s ./libgdbm.so.3 ./libgdbm.so
source /etc/apache2/envvars
S cpan mod_perl2



# MOD_PERL, SYSTEM TO BUILD
S apt-get remove libapache2-mod-perl2
B wget https://cpan.metacpan.org/authors/id/P/PH/PHRED/mod_perl-2.0.5.tar.gz
B tar -xzvf mod_perl-2.0.5.tar.gz
CD mod_perl-2.0.5
B perl Makefile.PL
B make
B make test
B make install

# MOD_PERL, BUILD TO SYSTEM
S mod_perl_uninstall.sh
S apt-get install libapache2-mod-perl2
#S apt-get install libapache2-mod-perl2-dev  # UNNECESSARY


# METHOD::SIGNATURES::SIMPLE & DEVEL::DECLARE & B::HOOKS::OP::CHECK, SYSTEM TO BUILD
B method_signatures_simple_uninstall.sh
B wget https://cpan.metacpan.org/authors/id/R/RH/RHESA/Method-Signatures-Simple-1.00.tar.gz
B tar -xzvf Method-Signatures-Simple-1.00.tar.gz
CD Method-Signatures-Simple-1.00
B perl Makefile.PL
B make
B make test
B make install

B devel_declare_uninstall.sh
B wget https://cpan.metacpan.org/authors/id/F/FL/FLORA/Devel-Declare-0.006006.tar.gz
B tar -xzvf Devel-Declare-0.006006.tar.gz
CD Devel-Declare-0.006006
B perl Makefile.PL
B make
B make test
B make install

S mv /usr/lib/x86_64-linux-gnu/perl5/5.22/B /usr/lib/x86_64-linux-gnu/perl5/5.22/B.SYSTEM_PERL_DISABLED
S mv /usr/lib/x86_64-linux-gnu/perl5/5.22/auto/B /usr/lib/x86_64-linux-gnu/perl5/5.22/auto/B.SYSTEM_PERL_DISABLED
#B wget https://cpan.metacpan.org/authors/id/Z/ZE/ZEFRAM/B-Hooks-OP-Check-0.19.tar.gz
B wget https://cpan.metacpan.org/authors/id/F/FL/FLORA/B-Hooks-OP-Check-0.18.tar.gz
B tar -xzvf B-Hooks-OP-Check-0.18.tar.gz
CD B-Hooks-OP-Check-0.18
B perl Makefile.PL
B make
B make test
B make install


# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, DEBUG MODPERL SEGFAULT ]]]

S gdb /usr/sbin/apache2
#(gdb) break perl_parse
#(gdb) run -k start -X
# RUNNING...
#<<< DEBUG >>>: in ShinyCMS.pm, returned from setup()
#<<< DEBUG >>>: in ShinyCMS.pm, about to return 1
#warning: Temporarily disabling breakpoints for unloaded shared library "/home/foo_user/perl5/lib/perl5/x86_64-linux/auto/B/Hooks/OP/Check/Check.so"
#Program received signal SIGSEGV, Segmentation fault.
#0x00007fffef697bd8 in ?? ()

#(gdb) up
##1  0x00007ffff400fc3f in Perl_newUNOP (type=17, flags=8192, first=0x55555cb18d38) at op.c:4811
#4811        unop = (UNOP*) CHECKOP(type, unop);

#(gdb) info threads
#  Id   Target Id         Frame 
#* 1    Thread 0x7ffff7fd1780 (LWP 10198) "/usr/sbin/apach" 0x00007ffff400fc3f in Perl_newUNOP (type=17, flags=8192, first=0x55555cb18d38) at op.c:4811

#(gdb) print PL_check[17]
#$1 = (Perl_check_t) 0x7fffef697bd8




#[[[ BEGIN GDB SESSION ]]]

#user@cloud-comp0-00:/$ sudo -i
#...
#root@cloud-comp0-00:~# source /etc/apache2/envvars
#root@cloud-comp0-00:~# gdb /usr/sbin/apache2
#...
#Reading symbols from /usr/sbin/apache2...(no debugging symbols found)...done.

#(gdb) run -k start -X
#Starting program: /usr/sbin/apache2 -k start -X
#[Thread debugging using libthread_db enabled]
#Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".
#<<< DEBUG >>>: top of ShinyCMS.pm
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Moose
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst::Runtime
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst
#<<< DEBUG >>>: in ShinyCMS.pm, about to use CatalystX::RoleApplicator
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Method::Signatures::Simple
#<<< DEBUG >>>: in ShinyCMS.pm, about to call config()
#<<< DEBUG >>>: in ShinyCMS.pm, have __PACKAGE__ = ShinyCMS
#<<< DEBUG >>>: in ShinyCMS.pm, about to call setup()...
#<<< DEBUG >>>: in ShinyCMS.pm, returned from setup()
#<<< DEBUG >>>: in ShinyCMS.pm, about to return 1

#Program received signal SIGSEGV, Segmentation fault.
#0x00007fffebabcb10 in ?? ()
#(gdb) bt
#0 0x00007fffebabcb10 in ?? ()
#1 0x00007ffff3e5302b in Perl_newUNOP (my_perl=my_perl@entry=0x5555577ddde0, type=type@entry=17, flags=<optimized out>, flags@entry=8192, first=0x5555562141b8) at op.c:4811
#2 0x00007ffff3e54a1d in Perl_newCVREF (my_perl=my_perl@entry=0x5555577ddde0, flags=flags@entry=8192, o=<optimized out>) at op.c:9367
#3 0x00007ffff3e8b686 in Perl_yylex (my_perl=my_perl@entry=0x5555577ddde0) at toke.c:6693
#4 0x00007ffff3e97228 in Perl_yyparse (my_perl=my_perl@entry=0x5555577ddde0, gramtype=gramtype@entry=258) at perly.c:322
#...
#44 0x000055555558709f in main ()

#(gdb) start
#The program being debugged has been started already.
#Start it from the beginning? (y or n) y
#Temporary breakpoint 1 at 0x5555555867b0
#Starting program: /usr/sbin/apache2 -k start -X
#[Thread debugging using libthread_db enabled]
#Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".

#Temporary breakpoint 1, 0x00005555555867b0 in main ()

#(gdb) break perl_parse
#Function "perl_parse" not defined.
#Make breakpoint pending on future shared library load? (y or [n]) y
#Breakpoint 2 (perl_parse) pending.

#(gdb) continue
#Continuing.

#Breakpoint 2, perl_parse (my_perl=0x55555581ae50, xsinit=0x7ffff420a280, argc=2, argv=0x7ffff7f88070, env=0x0) at perl.c:1473
#1473    perl.c: No such file or directory.

#(gdb) watch -l PL_check[17]
#Hardware watchpoint 3: -location PL_check[17]

#(gdb) continue
#Continuing.

#Hardware watchpoint 3: -location PL_check[17]

#Old value = (OP *(*)(PerlInterpreter *, OP *)) 0x7ffff3e4d9e0 <Perl_ck_rvconst>
#New value = (OP *(*)(PerlInterpreter *, OP *)) 0x7fffebabcb10 <check_cb>
#0x00007fffebabcd0e in hook_op_check (type=type@entry=OP_RV2CV, cb=cb@entry=0x7fffeb8b6d30 <dd_ck_rv2cv>, user_data=user_data@entry=0x0) at Check.xs:66
#66  PL_check[type] = check_cb;

#(gdb) info threads
#Id Target Id Frame 
#* 1 Thread 0x7ffff7fe2780 (LWP 6196) "/usr/sbin/apach" 0x00007fffebabcd0e in hook_op_check (type=type@entry=OP_RV2CV, cb=cb@entry=0x7fffeb8b6d30 <dd_ck_rv2cv>, user_data=user_data@entry=0x0)
#at Check.xs:66

#(gdb) info source
#Current source file is Check.xs
#Compilation directory is /home/wbraswell/.cpanm/work/1479735542.24787/B-Hooks-OP-Check-0.19
#Located in /home/wbraswell/.cpanm/work/1479735542.24787/B-Hooks-OP-Check-0.19/Check.xs
#Contains 106 lines.
#Source language is c.
#Producer is GNU C11 5.4.0 20160609 -mtune=generic -march=x86-64 -g -O2 -fwrapv -fno-strict-aliasing -fPIC -fstack-protector-strong.
#Compiled with DWARF 2 debugging format.
#Does not include preprocessor macro info.

#(gdb) continue
#Continuing.
#<<< DEBUG >>>: top of ShinyCMS.pm
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Moose
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst::Runtime
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Catalyst
#<<< DEBUG >>>: in ShinyCMS.pm, about to use CatalystX::RoleApplicator
#<<< DEBUG >>>: in ShinyCMS.pm, about to use Method::Signatures::Simple
#<<< DEBUG >>>: in ShinyCMS.pm, about to call config()
#<<< DEBUG >>>: in ShinyCMS.pm, have __PACKAGE__ = ShinyCMS
#<<< DEBUG >>>: in ShinyCMS.pm, about to call setup()...
#<<< DEBUG >>>: in ShinyCMS.pm, returned from setup()
#<<< DEBUG >>>: in ShinyCMS.pm, about to return 1

#...

#Program received signal SIGSEGV, Segmentation fault.
#0x00007fffebabcb10 in ?? ()
#(gdb) bt
#0 0x00007fffebabcb10 in ?? ()
#1 0x00007ffff3e5302b in Perl_newUNOP (my_perl=my_perl@entry=0x555559dd8ed0, type=type@entry=17, flags=<optimized out>, flags@entry=8192, first=0x55555824eb98) at op.c:4811
#2 0x00007ffff3e54a1d in Perl_newCVREF (my_perl=my_perl@entry=0x555559dd8ed0, flags=flags@entry=8192, o=<optimized out>) at op.c:9367
#...
#44 0x000055555558709f in main ()

#(gdb) print PL_check[17]
#$1 = (Perl_check_t) 0x7fffebabcb10

#(gdb) quit

#[[[ END GDB SESSION ]]]


# [[[ PERL CLOUDFORFREE, RUN PLACK SERVER ]]]

# === BEGIN CURRENT STEPS ===
screen -R;
sudo -i;
source /home/wbraswell/.bashrc; 
export PATH=/home/wbraswell/github_repos/rperl-latest/script/:$PATH; 
export PERL5LIB=/home/wbraswell/github_repos/apache2filemanager-latest/lib/:/home/wbraswell/github_repos/rperl-latest/lib/:/home/wbraswell/perl5:/home/wbraswell/perl5/lib/perl5:$PERL5LIB; 
set | grep PERL
cd /home/wbraswell/github_repos/cloudforfree.org-latest/;
./script/shinycms_server.pl -p 800 --fork
# === END CURRENT STEPS ===
 
# run plack manually
screen -R;
sudo -i;
source /home/wbraswell/.bashrc; 
export PATH=/home/wbraswell/github_repos/rperl-latest/script/:$PATH; 
export PERL5LIB=/home/wbraswell/github_repos/apache2filemanager-latest/lib/:/home/wbraswell/github_repos/rperl-latest/lib/:/home/wbraswell/perl5:/home/wbraswell/perl5/lib/perl5:$PERL5LIB; 
set | grep PERL

OR Apache2 FastCGI:
paste above lines into cloudforfree.org-latest/modified/fastcgi_start__cloudforfree.org.sh


vi /etc/apache2/sites-available/phpmyadmin.cloud-web2.autoparallel.com.conf
    Listen 800
    <VirtualHost *:800>
        ...
    </VirtualHost>
a2dissite cloud-web2.autoparallel.com
service apache2 reload


./script/shinycms_server.pl -p 80 -r  # Shiny
plackup --port 3000 app.psgi  # A2::FM

cpanm Starman
./script/shinycms_server.pl -p 80 --fork

cpanm Starman PORT FORWARDING
./script/shinycms_server.pl -p 800 --fork
a2enmod proxy
a2enmod proxy_http
vi /etc/apache2/sites-available/cloudforfree.org.conf
    <VirtualHost *:80>
        ServerAdmin william.braswell@NOSPAM.autoparallel.com
        DocumentRoot /srv/www/cloudforfree.org/public_html
        ServerName cloudforfree.org
        ErrorLog /srv/www/cloudforfree.org/logs/error.log
        CustomLog /srv/www/cloudforfree.org/logs/custom.log common

        ProxyPreserveHost On
        ProxyPass / http://0:800/
        ProxyPassReverse / http://0:800/
    </VirtualHost>



    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#    CURRENT_SECTION_COMPLETE  # final section!
fi


# [[[ PERL CLOUDFORFREE, PREREQUISITES, TERMINAL EMULATION ]]]

# terminal emulation
B cpanm Term::VT102
B cpanm Term::VT102::Boundless
B cpanm Term::VT102::Incremental

# DEV NOTE, CORRELATION #cff01: screen logfile max path length is 70, must use OS symlink to shorten path
S ln -s /home/wbraswell/github_repos/cloudforfree.org-latest/root/user_jobs /srv/cloudff_user_jobs


# [[[ SECURITY!  MYSQL, REMOVE ROOT PASSWORD ]]]

# SECURITY: mysql root password stored in DB.pm.new, must delete!!!
# update database schema
B bin/dev-tools/regenerate-dbic-modules
B rm lib/ShinyCMS/Model/DB.pm.new


# [[[ PHPMYADMIN, INCREASE TIMEOUT ]]]

# phpmyadmin increase timeout
# NEED FIX: DOES NOT APPEAR TO WORK?!?
S vi /etc/phpmyadmin/config.inc.php
   # $cfg['LoginCookieValidity'] = 14400;
   # ini_set('session.gc_maxlifetime', 14400);
S service apache2 reload






if [ $MENU_CHOICE -le 60 ]; then
    echo '60. [[[ UBUNTU LINUX, INSTALL MONGODB ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then

        clear
        echo 'Installing MongoDB Enterprise Edition on Ubuntu 16.04 Xenial'

        # source website for this installer:
        # https://docs.mongodb.com/manual/tutorial/install-mongodb-enterprise-on-ubuntu/

        echo 'Import The Public Key Used By The Package Management System'
        S apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6

        echo 'Create APT Source Entry For Downloading & Installing MongoDB'
        S echo "deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-enterprise.list

        echo 'Reload Local Package Database'
        S apt-get update

        echo 'Install MongoDB Enterprise Edition'
        S apt-get install mongodb-enterprise

        echo 'Start MongoDB Enterprise Service'
        echo "Starting MongoDB..."
        S service mongod start

        echo 'Verify That MongoDB Has Started Successfully By Checking The Contents Of The Log File'
        echo 'At /var/log/mongodb/mongod.log for a line (TYPICALLY THE LAST LINE) reading:'
        echo '    [initandlisten] waiting for connections on port <port>'
        echo 'Where <port> Is The Port Configured In /etc/mongod.conf, 27017 By Default.'
        B less /var/log/mongodb/mongod.log

        # Stop MongoDB
        #   S service mongod stop

        # Restart MongoDB
        #   S service mongod restart

    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#   CURRENT_SECTION_COMPLETE  # NEED UN-COMMENT WHEN THIS IS NO LONGER THE FINAL SECTION
fi


echo
echo '[[[ ALL DONE!!! ]]]'
echo
