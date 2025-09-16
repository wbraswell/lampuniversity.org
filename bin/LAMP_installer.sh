#!/bin/bash
# Copyright © 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024, 2025, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.
# LAMP Installer Script
VERSION='0.525_000'


# START HERE: sync w/ rperl_installer.sh
# START HERE: sync w/ rperl_installer.sh
# START HERE: sync w/ rperl_installer.sh


# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!
# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!
# IMPORTANT DEV NOTE: do not edit anything in this file without making the exact same changes to rperl_installer.sh!!!

# PRE-PRE-INSTALL: install wget
# sudo apt-get install wget
# OR
# sudo yum install wget

# PRE-INSTALL: download the latest version of this file and make it executable
# rm ./LAMP_installer.sh; wget https://raw.githubusercontent.com/wbraswell/lampuniversity.org/master/bin/LAMP_installer.sh; chmod a+x ./LAMP_installer.sh
# OR
# rm ./lampinstaller; wget tinyurl.com/lampinstaller; chmod a+x ./lampinstaller

# [[[ UNINDENT REGEX, USE WHEN PASTING INDENTED CONTENT FROM THIS FILE INTO OTHER FILES ]]]
#:%s/^\ \ \ \ //g

# enable extended pattern matching in case statements
shopt -s extglob

# global variables
USER_INPUT=''
CURRENT_SECTION=0

# command-line arguments
HELP_CHOICE="no"       # DEFAULT NO
DEVELOPER_CHOICE="no"  # DEFAULT NO
SECTION_CHOICE="__EMPTY__"
MACHINE_CHOICE="__EMPTY__"
OS_CHOICE="__EMPTY__"
PERL_INSTALL_CHOICE="__EMPTY__"
RPERL_INSTALL_CHOICE="__EMPTY__"

# block comment template
: <<'END_COMMENT'
    foo bar bat
END_COMMENT

# command-line arguments AKA options
for i in "$@"
do
case $i in
    -?|-h|--help)
    HELP_CHOICE="yes"
    shift
    ;;
    -d=*|--developer=*)
    DEVELOPER_CHOICE="${i#*=}"
    shift
    ;;
    -s=*|--section=*)
    SECTION_CHOICE="${i#*=}"
    shift
    ;;
    -m=*|--machine=*)
    MACHINE_CHOICE="${i#*=}"
    shift
    ;;
    -os=*|--operating-system=*)
    OS_CHOICE="${i#*=}"
    shift
    ;;
    -pi=*|--perl-install=*)
    PERL_INSTALL_CHOICE="${i#*=}"
    shift
    ;;
    -ri=*|--rperl-install=*)
    RPERL_INSTALL_CHOICE="${i#*=}"
    shift
    ;;
    *)
          # unknown argument, ignore
    ;;
esac
done

echo 'Received the following command-line arguments AKA options:'
echo "HELP_CHOICE               = ${HELP_CHOICE}"
echo "DEVELOPER_CHOICE          = ${DEVELOPER_CHOICE}"
echo "SECTION_CHOICE            = ${SECTION_CHOICE}"
echo "MACHINE_CHOICE            = ${MACHINE_CHOICE}"
echo "OS_CHOICE                 = ${OS_CHOICE}"
echo " PERL_INSTALL_CHOICE      = ${PERL_INSTALL_CHOICE}"
echo "RPERL_INSTALL_CHOICE      = ${RPERL_INSTALL_CHOICE}"
echo

if [ $HELP_CHOICE == 'yes' ]; then
    echo 'LAMP Installer Script'
    echo 'Usage:'
    echo '        LAMP_installer.sh [ARGUMENTS]'
    echo
    echo 'Arguments:'
    echo '    -? ...OR... -h ...OR... --help'
    echo '        Print this (relatively) brief help message for command-line usage.'
    echo
    echo '    -d=[yes|no] ...OR... --developer=[yes|no]'
    echo '        Execute commands for developer sections, or not.'
    echo
    echo '    -s=INTEGER ...OR... --section=INTEGER'
    echo '        Execute commands starting at specified section number.'
    echo
    echo '    -m=[new|existing] ...OR... --machine=[new|existing]'
    echo '        Execute commands for new or existing machine.'
    echo
    echo '    -os=[ubuntu|centos] ...OR... --operating-system=[ubuntu|centos]'
    echo '        Execute commands for specified operating system.'
    echo
    echo '    -pi=[locallib|perlbrew|source|system] ...OR... --perl-install=[locallib|perlbrew|source|system]'
    echo '        Execute commands for specified Perl installation option.'
    echo
    echo '    -ri=[packages|cpanm-single|cpanm-system|cpan-single|cpan-system|github-secure-git|github-public-git|github-public-zip] ...OR...'
    echo '    -rperl-install=[packages|cpanm-single|cpanm-system|cpan-single|cpan-system|github-secure-git|github-public-git|github-public-zip]'
    echo '        Execute commands for specified RPerl installation option.'
    echo
    exit
fi

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
#    sudo bash -c " $COMMAND "  # CORRECT, DOES NOT PRESERVE ENVIRONMENT
    sudo -E bash -c " $COMMAND "  # CORRECT, DOES PRESERVE ENVIRONMENT
    echo
}

B () {  # _B_ash command
    COMMAND=" ${01} ${02} ${03} ${04} ${05} ${06} ${07} ${08} ${09} ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} \
        ${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27} ${28} ${29} ${30} ${31} ${32} ${33} ${34} ${35} ${36} ${37} ${38} ${39} \
        ${40} ${41} ${42} ${43} ${44} ${45} ${46} ${47} ${48} ${49} ${50} ${51} ${52} ${53} ${54} ${55} ${56} ${57} ${58} ${59} \
        ${60} ${61} ${62} ${63} ${64} ${65} ${66} ${67} ${68} ${69} ${70} ${71} ${72} ${73} ${74} ${75} ${76} ${77} ${78} ${79} \
        ${80} ${81} ${82} ${83} ${84} ${85} ${86} ${87} ${88} ${89} ${90} ${91} ${92} ${93} ${94} ${95} ${96} ${97} ${98} ${99} "
    echo '$' $COMMAND

    while true; do
        read -p 'Run above command, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

    bash -c " $COMMAND "
    echo
}

VERIFY_OS_CHOICE() {
    local OS_REQ="$1"
    local CHOICE="$OS_CHOICE"

    local GUESS='UNKNOWN'
    if [[ -f "/etc/redhat-release" ]]; then
        GUESS='centos'
    elif [[ -f "/etc/debian_version" ]]; then
        GUESS='ubuntu'
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
    VERIFY_OS_CHOICE 'centos'
}

VERIFY_UBUNTU() {
    VERIFY_OS_CHOICE 'ubuntu'
}

# do not provide menu prompt if already provided as command-line argument
if [ $SECTION_CHOICE == '__EMPTY__' ]; then
    echo "[[[<<< LAMP Installer Script v$VERSION >>>]]]"
    echo
    echo '  [[[<<< Tested Using Fresh Installs >>>]]]'
    echo
    echo 'Xubuntu v14.04.2 (Trusty Tahr) DEPRECATED'
    echo 'Xubuntu v16.04.4 (Xenial Xerus) DEPRECATED'
    echo 'Xubuntu v24.04   (Noble Numbat) DEPRECATED'
    echo 'CentOS  v7.4-1708'
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
    echo  '14. [[[ UBUNTU LINUX, INSTALL VNC & XPRA ]]]'
    echo  '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
    echo  '16. [[[ UBUNTU LINUX, UNINSTALL HUD & BLUETOOTH & MODEMMANAGER & GVFS & EXTRA GUI PACKAGES ]]]'
    echo  '17. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER ]]]'
    echo  '18. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
    echo  '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
    echo
    echo  '         <<< PERL & RPERL SECTIONS >>>'
    echo  '20. [[[        LINUX,   INSTALL  PERL DEPENDENCIES ]]]'
    echo  '21. [[[        LINUX,   INSTALL  PERL & CPANM ]]]'
    echo  '22. [[[        LINUX,   PACKAGE RPERL DEPENDENCIES, DEVELOPERS ONLY ]]]'
    echo  '23. [[[        LINUX,   INSTALL RPERL DEPENDENCIES ]]]'
    echo  '24. [[[  PERL,          INSTALL RPERL ]]]'
    echo  '25. [[[ RPERL,          RUN COMPILER TESTS ]]]'
    echo  '26. [[[ RPERL,          INSTALL RPERL APPS & RUN DEMOS ]]]'
    echo
    echo  '         <<< SERVICE SECTIONS >>>'
    echo  '30. [[[ UBUNTU LINUX,   INSTALL NFS & DBXFS]]]'
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
    echo  '60. [[[        LINUX,   INSTALL MONGODB ]]]'
    echo
    echo  '70. [[[ PERL CLOUDFORFREE, INSTALL ]]]'
    echo

    while true; do
        read -p 'Please type your chosen main menu section number, or press <ENTER> for 0... ' SECTION_CHOICE
        case $SECTION_CHOICE in
            [0123456789]|[1234][0123456789]|5[01]|60 ) echo; break;;
            '' ) echo; SECTION_CHOICE=0; break;;
            * ) echo 'Please choose a section number from the menu!'; echo;;
        esac
    done

fi
CURRENT_SECTION=$SECTION_CHOICE

# do not provide menu prompt if already provided as command-line argument
if [ $MACHINE_CHOICE == '__EMPTY__' ]; then
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
fi

# do not provide menu prompt if already provided as command-line argument
if [ $OS_CHOICE == '__EMPTY__' ]; then
    echo  '          [[[<<< OS Menu >>>]]]'
    echo
    echo \ '0. [[[           UBUNTU       ]]]'
    echo \ '1. [[[           CENTOS       ]]]'
    echo \ '9. [[[           OTHER        ]]]'
    echo

    while true; do
        read -p 'Please type your OS menu choice number, or press <ENTER> for 0... ' OS_CHOICE
        case $OS_CHOICE in
            0 ) echo; OS_CHOICE='ubuntu'; break;;
            1 ) echo; OS_CHOICE='centos'; break;;
            9 ) echo; OS_CHOICE='OTHER'; break;;
            '' ) echo; OS_CHOICE='ubuntu'; break;;
            * ) echo 'Please choose a number from the menu!'; echo;;
        esac
    done
fi

# SECTION 0 VARIABLES
EDITOR='__EMPTY__'
USERNAME='__EMPTY__'
IP_ADDRESS='__EMPTY__'
DOMAIN_NAME='__EMPTY__'

if [ $SECTION_CHOICE -le 0 ]; then
    echo '0. [[[ LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
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

if [ $SECTION_CHOICE -le 1 ]; then
    echo '1. [[[ LINUX, CONFIGURE CLOUD NETWORKING ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        B scp /etc/hosts $DOMAIN_NAME:/tmp/hosts
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now..."
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 2 VARIABLES
SWAP_DEVICE='__EMPTY__'

if [ $SECTION_CHOICE -le 2 ]; then
    echo '2. [[[ UBUNTU LINUX, USB INSTALL, FIX BROKEN SWAP DEVICE ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
        echo
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 3 ]; then
    echo '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ NOTE: Check For The Following Error When You Run The Next Command... "perl: warning: Setting locale failed." ]'
        B 'perl -e exit'
        echo '[ If You Saw The locale Error, Then Run The Next 2 Commands To Generate & Reconfigure Locales ]'
        S locale-gen en_US.UTF-8
        S dpkg-reconfigure locales
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 4 ]; then
    echo '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: THIS SECTION IS EXPERIMENTAL!  This should NOT be done if you are not sure about what you are doing!!! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install ubuntu-sdk
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list
# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list
# START HERE: ensure "CODENAME-updates" (ex. "xenial-updates") entries exist in /etc/apt/sources.list

if [ $SECTION_CHOICE -le 5 ]; then
    echo '5. [[[ UBUNTU LINUX, UPGRADE ENTIRE OPERATING SYSTEM OR ALL PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 6 ]; then
    echo '6. [[[ LINUX, INSTALL BASE CLI OPERATING SYSTEM PACKAGES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            VERIFY_UBUNTU
            echo '[ Check Install, Confirm No Errors ]'
            S apt-get update
            S apt-get -f install
            echo '[ General Tools: g++ make ssh perl cpan perl-doc vim git htop linuxlogo lynx traceroute screen ifconfig ]'
            echo '[ LAMP University Tools Requirements: zip unzip ]'
            S apt-get install g++ make ssh perl perl-doc vim git htop linuxlogo lynx traceroute screen net-tools zip unzip
            echo '[ Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            VERIFY_CENTOS
            if [ $DEVELOPER_CHOICE == 'yes' ]; then
                echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                S yum check
            fi
            echo '[ General Tools: g++ make ssh perl cpan perl-doc vim git htop linuxlogo lynx traceroute screen ifconfig ]'
            echo '[ LAMP University Tools Requirements: zip unzip ]'
            S yum install gcc-c++ make openssh openssh-clients perl perl-core perl-CPAN perl-Pod-Perldoc vim-enhanced git lynx traceroute screen net-tools zip unzip
            S yum install epel-release
            S yum install htop linux_logo
            if [ $DEVELOPER_CHOICE == 'yes' ]; then
                echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                S yum check
            fi
        fi

        echo '[ Configure SSH, Keep Connections Alive, Required Over Some VPN & Proxy Connections ]'

SSH_KEEPALIVE=$(cat <<END_HEREDOC

# [ KEEP SSH CONNECTIONS ALIVE, required over some VPN & proxy connections ]
# SSH client & server config, TCP layer: ping from server to client, can be spoofed or blocked by VPN, keep enabled but rely on SSH layer
TCPKeepAlive yes
END_HEREDOC
)

SSH_SERVERALIVE=$(cat <<END_HEREDOC
# SSH client config, SSH layer: ping from client to server every 60 seconds, if no reply then try 60 times before disconnecting
ServerAliveInterval 60 
ServerAliveCountMax 60
END_HEREDOC
)

SSH_CLIENTALIVE=$(cat <<END_HEREDOC
# SSH server config, SSH layer: ping from server to client every 60 seconds, if no reply then try 60 times before disconnecting
ClientAliveInterval 60
ClientAliveCountMax 60
END_HEREDOC
)

        S "echo '$SSH_KEEPALIVE'   >> /etc/ssh/ssh_config"  # DEV NOTE: must wrap redirects in quotes
        S "echo '$SSH_SERVERALIVE' >> /etc/ssh/ssh_config"  # DEV NOTE: must wrap redirects in quotes
        S "echo '$SSH_KEEPALIVE'   >> /etc/ssh/sshd_config"  # DEV NOTE: must wrap redirects in quotes
        S "echo '$SSH_CLIENTALIVE' >> /etc/ssh/sshd_config"  # DEV NOTE: must wrap redirects in quotes
#        S service sshd restart  # Xubuntu v16.04 DEPRECATED
        S systemctl restart ssh

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 7 ]; then
    echo '7. [[[ UBUNTU LINUX, INSTALL & TEST CLAMAV ANTI-VIRUS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 8 ]; then
    echo '8. [[[ LINUX, INSTALL LAMP UNIVERSITY TOOLS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        B wget https://github.com/wbraswell/lampuniversity.org/archive/master.zip
        B mv master.zip lampuniversity.org-master.zip
        B unzip lampuniversity.org-master.zip
        B mkdir ~/bin
        B cp lampuniversity.org-master/bin/* ~/bin
        echo '[ Install Vim RC Config File ]'
        B cp lampuniversity.org-master/run_commands/.vimrc ~/
        B rm -Rf lampuniversity.org*
        B hash -r
        C 'Please Log Out And Log Back In, Which Should Reset The $PATH Environmental Variable To Include The Newly-Created ~/bin Directory, Then Come Back To This Point.'
        echo '[ Test LAMP University Tools, Top Memory Script ]'
        B topmem.sh
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 9 ]; then
    echo '9. [[[ UBUNTU LINUX, INSTALL HEIRLOOM TOOLS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 10 ]; then
    echo '10. [[[ UBUNTU LINUX, INSTALL BROADCOM B43 WIFI ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: The following 2 apt-get commands are only for affected machines such as Dell Latitude D430 & D630. ]'
        echo '[ Symptoms include no working wireless support, and the inability to shut down or reboot or suspend. ]'
        C 'Please read the warning above.  Seriously.'
        # purge to get rid of config files as well as executable files;
        # remove b43 blacklisting in /etc/modprobe.d/broadcom-sta-dkms.conf
        S apt-get purge bcmwl-kernel-source broadcom-sta-dkms dkms
        S apt-get install firmware-b43-installer
        S modprobe b43

B43_MODULE=$(cat <<END_HEREDOC
# Broadcom b43 Wifi Module
b43
END_HEREDOC
)

        S "echo '$B43_MODULE'   >> /etc/modules-load.d/b43.conf"  # DEV NOTE: must wrap redirects in quotes

        echo '[ WARNING: The following 1 apt-get command is only for affected machines with a network card containing the Realtek 8812 chipset such as a D-Link DWA-182. Not for use on Dell Latitude D430 or D630. ]'
        S apt-get install rtl8812au-dkms
        S reboot
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 11 VARIABLES
CPUMINER_SERVER='__EMPTY__'
CPUMINER_USERNAME='__EMPTY__'
CPUMINER_PASSWORD='__EMPTY__'

if [ $SECTION_CHOICE -le 11 ]; then
    echo '11. [[[ UBUNTU LINUX, PERFORMANCE BENCHMARKING ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 12 VARIABLES
UBUNTU_RELEASE_NAME='__EMPTY__'

if [ $SECTION_CHOICE -le 12 ]; then
    echo '12. [[[ UBUNTU LINUX, INSTALL BASE GUI OPERATING SYSTEM PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $UBUNTU_RELEASE_NAME 'Ubuntu release name (trusty, xenial, bionic, focal, jammy, mantic, noble, etc.)' 'noble'
        UBUNTU_RELEASE_NAME=$USER_INPUT
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get update
        S apt-get -f install
        echo '[ X-Windows Installation Triggers: xterm xfce4-terminal ]'
        echo '[ Basic X-Windows Testing: x11-apps (contains xclock) ]'
        echo '[ General Tools: gkrellm hexchat update-manager indicator-multiload xclip (used by xcopy.sh) ]'
        S apt-get install xterm xfce4-terminal x11-apps gkrellm hexchat update-manager indicator-multiload xclip

        echo '[ Browsers: chromium (deb) instead of chromium-browser (snap) ]'
        S apt-get purge chromium-browser
        B snap remove --purge chromium
        S add-apt-repository ppa:xtradeb/apps -y
        S apt-get update
        S apt-get install chromium

        echo '[ Browsers: firefox (deb) instead of firefox (snap) ]'
        # DEV NOTE: unofficial Mozilla Team PPA (https:/launchpad.net/~mozillateam) is now deprecated 
        # in favor of official upstream Mozilla APT Repository as of January 2024;
        # snap disable & remove instructions:  https://askubuntu.com/questions/1414173/completely-remove-firefox-snap-package
        S snap disable firefox
FIREFOX_SNAP_LSBLK_OUTPUT=$(cat <<END_HEREDOC
NAME   FSTYPE FSVER LABEL UUID                                 FSAVAIL FSUSE% MOUNTPOINTS                            RO
sda                                                                                                                   0
├─sda1                                                                                                                0
└─sda2 ext4   1.0         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   77.7G    77% /var/snap/firefox/common/host-hunspell  0
END_HEREDOC
)
        echo 'Please run the `lsblk` command, then before proceeding further confirm the Firefox snap is mounted as ext4 for the hunspell service, as seen in the following sample output:'
        # DEV NOTE: must wrap variable in double quotes below to preserve multiline heredocs' newline characters in output
        echo "$FIREFOX_SNAP_LSBLK_OUTPUT"
        B lsblk -fe7 -o+ro
        C 'Check the output above to confirm the Firefox snap is mounted as ext4 for the hunspell service.'
        S systemctl stop var-snap-firefox-common-host\\x2dhunspell.mount
        S systemctl disable var-snap-firefox-common-host\\x2dhunspell.mount
        S snap remove firefox

        # APT install instructions:
        # https://www.omgubuntu.co.uk/2022/04/how-to-install-firefox-deb-apt-ubuntu-22-04
        # https://support.mozilla.org/en-US/kb/install-firefox-linux#w_install-firefox-deb-package-for-debian-based-distributions
        S install -d -m 0755 /etc/apt/keyrings
        # DEV NOTE: must wrap redirects in quotes
        B 'wget -q https://packages.mozilla.org/apt/repo-signing-key.gpg -O- | sudo tee /etc/apt/keyrings/packages.mozilla.org.asc > /dev/null'
        B 'gpg -n -q --import --import-options import-show /etc/apt/keyrings/packages.mozilla.org.asc'
        C 'Check to make sure the Firefox key fingerprint in the output above matches the following: 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3'
        B 'echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" | sudo tee -a /etc/apt/sources.list.d/mozilla.list > /dev/null'
FIREFOX_SNAP_PIN_PRIORITY=$(cat <<END_HEREDOC
Package: *
Pin: origin packages.mozilla.org
Pin-Priority: 1000
END_HEREDOC
)
        B "echo '$FIREFOX_SNAP_PIN_PRIORITY' | sudo tee /etc/apt/preferences.d/mozilla"
        S apt-get update
        S apt-get install firefox

        echo '[ General Tools: unetbootin (latest is "focal", no "noble" available as of 20250625)]'
        # DEV NOTE: the last version of unetbootin was built for Ubuntu v20.04 "focal", must specify explicitly below
        #S add-apt-repository ppa:gezakovacs/ppa
        S "add-apt-repository 'deb https://ppa.launchpadcontent.net/gezakovacs/ppa/ubuntu/ focal main'"
        S apt-get update
        S apt-get install unetbootin

        # BUG https://bugs.launchpad.net/bugs/1613949
        echo '[ gVim Fix: Copy All "xenial" Lines, Paste As New "xenial-update" Lines ]'
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        S apt-get install vim-gtk3  # example affected by 16.04.1 apt-get upgrade

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

        echo '[ Unit File Fix ]'
        echo 'Look the following 2 warning lines when running the `apt-get update` command below...'
        echo "Warning: The unit file, source configuration file or drop-ins of apt-news.service changed on disk. Run 'systemctl daemon-reload' to reload units."
        echo "Warning: The unit file, source configuration file or drop-ins of esm-cache.service changed on disk. Run 'systemctl daemon-reload' to reload units."
        S apt-get update
        C 'If you see the warning lines in the output above, then run the `systemctl` command below.'
        S systemctl daemon-reload
        echo 'Look for the same warning lines again, they should be gone now...'
        S apt-get update
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 13 ]; then
    echo '13. [[[ UBUNTU LINUX, INSTALL EXTRA GUI OPERATING SYSTEM PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
        S apt-get install webcamoid

        echo '[ Zoom App, Video Chat ]'
        # https://support.zoom.us/hc/en-us/articles/204206269-Installing-or-updating-Zoom-on-Linux
        B wget https://zoom.us/client/latest/zoom_amd64.deb
        S apt autoremove
        S apt install ./zoom_amd64.deb
        B rm ./zoom_amd64.deb

        echo '[ Signal App, Video Chat ]'
        # https://signal.org/en/download
        S 'wget -O- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > signal-desktop-keyring.gpg'
        S mv signal-desktop-keyring.gpg /usr/share/keyrings/
        S "echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' | sudo tee -a /etc/apt/sources.list.d/signal-xenial.list"
        S apt update 
        S apt install signal-desktop

        echo '[ Wire Messenger App, Video Chat ]'
        # https://github.com/wireapp/wire-desktop/wiki/How-to-install-Wire-for-Desktop-on-Linux
        S apt-get install apt-transport-https
        S 'wget -q https://wire-app.wire.com/linux/releases.key -O- | sudo apt-key add -'
        S "echo 'deb [arch=amd64] https://wire-app.wire.com/linux/debian stable main' > /etc/apt/sources.list.d/wire-desktop.list"
        S apt-get update
        S apt-get install wire-desktop

        echo '[ Eclipse IDE ]'
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

        echo '[ M$ Windows: Bottles Emulator & Firefox Browser ]'
        S apt install flatpak
        B flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        echo '[ REBOOT REQUIRED TO AVOID THE FOLLOWING ERROR ]'
        echo 'error: Failed to install org.gnome.Platform: Error pulling from repo: GPG verification enabled, but no signatures found (use gpg-verify=false in remote config to disable)'
        S reboot
        B flatpak install flathub com.usebottles.bottles
        B mkdir ~/bottles_external
        echo '[ DLL DOWNLOAD REQUIRED TO AVOID THE FOLLOWING ERROR ]'
        echo 'FOOBAR'
        C 'Manually download the lateset cryptbase.zip file (10.0.19041.1 seems to work) from https://www.dll-files.com/cryptbase.dll.html & save to ~/bottles_external directory'
        B unzip ~/bottles_external/cryptbase.zip
        B cp ~/bottles_external/cryptbase.dll ~/.var/app/com.usebottles.bottles/data/bottles/bottles/Firefox/drive_c/windows/system32/CRYPTBASE.dll
        C '[ CREATE NEW APPLICATION BOTTLE, RUN FIREFOX INSTALLER EXECUTABLE INSIDE BOTTLE ]'

        echo '[ GPU DISABLING REQUIRED TO AVOID THE FOLLOWING ERROR ]'
        echo 'err:vulkan:wine_vk_instance_load_physical_devices Failed to enumerate physical devices'
        echo 'err:vulkan:__wine_create_vk_instance_with_callback Failed to load physical devices'

        # NONE OF THE BELOW PREF SETTINGS SEEM TO PROPERLY DISABLE GPU???
        echo '
// WBRASWELL 20250104: disable GPU requirement
// https://superuser.com/questions/1813088/how-to-disable-graphics-hardware-acceleration-in-firefox
user_pref("browser.preferences.defaultPerformanceSettings.enabled", false);
user_pref("layers.acceleration.disabled", true);
// https://recoverhdd.com/blog/how-to-enable-or-disable-hardware-acceleration-in-browser.html
user_pref("layers.acceleration.force-enabled", false);
'
        B vi ~/.var/app/com.usebottles.bottles/data/bottles/bottles/Firefox/drive_c/users/steamuser/AppData/Roaming/Mozilla/Firefox/Profiles/*.default-release/prefs.js

        echo '[ RUN FIREFOX BROWSER EXECUTABLE INSIDE BOTTLE ]'

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 14 VARIABLES
LOCAL_HOSTNAME='__EMPTY__'

if [ $SECTION_CHOICE -le 14 ]; then
    echo '14. [[[ UBUNTU LINUX, INSTALL VNC & XPRA ]]]'
    echo
    VERIFY_UBUNTU

    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '14.0 [ VNC Server, Install VNC ]'
        S apt-get install x11vnc

        # VNC server, start VNC independent of client
#        B x11vnc -display :0  # run now
            # __OR__
#        S x11vnc -wait 50 -noxdamage -passwd PASSWORD -display :0 -forever -o /var/log/x11vnc.log -bg  # run at startup, put this inside startup file

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo '14.0 [ VNC Client, Install VNC ]'
        S apt-get install ssvnc
    fi

    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        C 'Please run section 14.0 on the existing local machine before proceeding.'
        echo '14.1a [ If VNC Server has Private IP via NAT, and '
        echo '        If VNC Client has Private IP via NAT with SSH Pinhole AKA Port Forwarding'
        echo '        Then: VNC Server, Start Reverse SSH Tunnel; and '
        echo '              VNC Client, Start Double-Reverse SSH Tunnel; and VNC Server, Start VNC'
        C 'Please read the instructions above to determine if you should run the following 1 command.'
        P $LOCAL_HOSTNAME "Existing Machine's Local Hostname"
        LOCAL_HOSTNAME=$USER_INPUT
        P $LOCAL_USERNAME "Existing Machine's Local Username"
        LOCAL_USERNAME=$USER_INPUT
        B ssh -R 19999:localhost:22 $LOCAL_USERNAME@$LOCAL_HOSTNAME

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        C 'Please run sections 14.0 & 14.1 on the new remote machine before proceeding.'
        echo '14.1a [ If VNC Server has Private IP via NAT, and '
        echo '        If VNC Client has Private IP via NAT with SSH Pinhole AKA Port Forwarding'
        echo '        Then: VNC Server, Start Reverse SSH Tunnel; and '
        echo '              VNC Client, Start Double-Reverse SSH Tunnel; and VNC Server, Start VNC'
        C 'Please read the instructions above to determine if you should run the following 1 command.'
        P $REMOTE_USERNAME "New Machine's Remote Username"
        REMOTE_USERNAME=$USER_INPUT
        echo 'Test Reverse SSH Tunnel Before Proceeding...'
        B ssh $REMOTE_USERNAME@localhost -p 19999
#        B scp -P 19999 $LOCAL_PATH/$LOCAL_FILENAME $REMOTE_USERNAME@localhost:$REMOTE_PATH  # template for SCP over reverse SSH tunnel
        B ssh $REMOTE_USERNAME@localhost -p 19999 -t -L 5900:localhost:5900 'x11vnc -localhost -display :0'
            # __OR__
        echo '14.1b [ If VNC Server has Public IP, and '
        echo '        If VNC Client has Private IP via NAT with SSH Pinhole AKA Port Forwarding'
        echo '        Then: VNC Client, Start Reverse SSH Tunnel; and VNC Server, Start VNC ]'
        C 'Please read the instructions above to determine if you should run the following 1 command.'
        P $REMOTE_HOSTNAME "New Machine's Remote Hostname"
        REMOTE_HOSTNAME=$USER_INPUT
        B ssh $REMOTE_HOSTNAME -t -L 5900:localhost:5900 'x11vnc -localhost -display :0'

        echo '14.2 [ VNC Client, Start VNC ]'
        B ssvncviewer localhost:0
    fi


    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
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

if [ $SECTION_CHOICE -le 15 ]; then
    echo '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: This sections is only for use with Ubuntu Linux installed inside a VirtualBox VM! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install dkms
        C 'Now Download VBoxGuestAdditions.iso From http://download.virtualbox.org/virtualbox/ And Mount ISO'
        P $ISO_MOUNT_POINT "ISO Mount Point, Directory's Full Path"
        ISO_MOUNT_POINT=$USER_INPUT
        S "cd $ISO_MOUNT_POINT; sh ./VBoxLinuxAdditions.run"
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 16 ]; then
    echo '16. [[[ UBUNTU LINUX, UNINSTALL HUD & BLUETOOTH & MODEMMANAGER & GVFS & EXTRA GUI PACKAGES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Uninstall HUD To Free System Memory ]'
        S apt-get purge hud
        echo '[ Uninstall Bluetooth Support To Free System Memory ]'
        S apt-get purge blueman bluez bluez-obexd
        echo '[ Uninstall Mobile Broadband ModemManager To Free System Memory ]'
        S apt-get purge modemmanager
        echo '[ Disable GVFS Network Mounting OR Uninstall GVFS To Speed Up Thunar File Explorer ]'
        echo '[ OPTION 1 ONLY: Disable GVFS Network Mounting ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ OPTION 1 ONLY: Manually Edit GVFS Config File, Copy Config Entry From The Following Line ]'
        echo 'AutoMount=false'
        echo
        S $EDITOR /usr/share/gvfs/mounts/network.mount
        echo '[ OPTION 2 ONLY: Uninstall GVFS Completely ]'
        echo '[ WARNING!  USB flash drives & CD/DVD discs will not be auto-mounted if you uninstall GVFS! ]'
        S apt-get purge gvfs-daemons gigolo
        echo '[ Uninstall Extra GUI Packages To Free System Storage (Disk Space) ]'
        S apt-get purge thunderbird pidgin simple-scan orage gnome-mines gnome-sudoku speech-dispatcher xfce4-notes transmission-gtk
        S apt-get purge libreoffice-common
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 17 ]; then
    echo '17. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER & CONFIGURE SPACE TELESCOPE IMAGES & CONFIGURE FLYING TOASTERS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: The following command is only for affected machines. ]'
        echo '[ Symptoms include the mouse cursor disappears after screensaver. (CTRL-ALT-F1 for temporary fix.) ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get remove light-locker
        echo '[ SPACE TELESCOPE ONLY: Download & Install Space Telescope Images ]'
#        B 'wget https://www.spacetelescope.org/static/images/zip/top100/top100-large.zip; unzip top100-large.zip'  # disabled due to bad files
        # alternative manual download source:  http://www.jpl.nasa.gov/spaceimages/searchwp.php?category=featured
        B 'wget https://raw.githubusercontent.com/wbraswell/spacetelescope.org-mirror/master/top100_cleaned_scaled.zip; unzip top100_cleaned_scaled.zip'
        B 'mkdir ~/.xscreensaver_glslideshow; mv top100/ ~/.xscreensaver_glslideshow/'
        echo '[ SPACE TELESCOPE ONLY: Install xcreensaver (potentially alongside xfce4-screensaver!) for GL Slideshow plugin ]'
        S apt-get install xscreensaver xscreensaver-data-extra xscreensaver-gl
        echo '[ FLYING TOASTERS ONLY: Download & Install Flying Toaster Files ]'
        B 'wget https://gitlab.com/wbraswell/xfce-screensaver-mpv-flying-toasters/-/archive/main/xfce-screensaver-mpv-flying-toasters-main.tar.gz; tar -xzvf xfce-screensaver-mpv-flying-toasters-main.tar.gz'
        # VERY FIRST START HERE, COPY FILES TO /usr/..., RUN SYMLINK SCRIPT, WRITE CONFIGURATION DIRECTIONS
        # VERY FIRST START HERE, COPY FILES TO /usr/..., RUN SYMLINK SCRIPT, WRITE CONFIGURATION DIRECTIONS
        # VERY FIRST START HERE, COPY FILES TO /usr/..., RUN SYMLINK SCRIPT, WRITE CONFIGURATION DIRECTIONS


        echo '[ UBUNTU 20.04 OR NEWER ONLY: Configure Xfce Screensaver ]'
        echo "Click main Xubuntu app menu -> Settings -> Screensaver or Xfce Screensaver"
        echo '-> Regard the computer as idle after: 10 minutes'
        echo '-> Theme -> GL Slideshow -> Settings Wrench Icon -> Frame rate: 11511 (low); Time until loading a new image: 10 seconds; Always show at least this much of the image: 85%; Pan / zoom duration: 10 seconds; Crossfade duration: 0 seconds (none); -> Close GLi Slideshow Settings'
        echo '-> Lock Screen -> Enable Lock Screen -> Lock Screen With Screensaver, Lock the screen after the screensaver is active for: 0 minutes'
        echo '[ UBUNTU 18.04 OR OLDER ONLY: Configure XScreensaver ]'
        echo "Click main Xubuntu app menu -> Settings -> Screensaver -> The XScreenSaver daemon doesn't seem to be running on display \":0.0\"."
        echo '-> Launch it now?  OK -> Blank & Lock After 10 Mins'
        echo '-> Mode, Only One Screensaver -> GLSlideshow -> Settings -> Advanced -> glslideshow -root -delay 46565 -duration 10 -zoom 85 -> Close GLSlideshow Settings'
        echo '-> Advanced Tab -> Image Manipulation -> Choose Random Image -> Browse -> Select Image Folder ~/.xscreensaver_glslideshow/top100'
        echo
        C 'Follow the directions above.'
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 18 ]; then
    echo '18. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Configure Window Manager Layout ]'
        echo 'Right-click on top panel -> Panel -> Panel Preferences -> Green Plus Sign -> Select New Panel -> Items Tab -> Add Windows Buttons & Separator & Workspace Switcher'
        echo '-> Windows Buttons Settings -> Sorting Order: None, Allow Drag-and-Drop; Show button labels: yes; Show flat buttons: no; Show handle: no; Show tooltips: no; -> Separator Settings -> Expand -> Workspace Switcher Settings -> 4 Workspaces: Browsers, E-Mail, Files & Office, Terminals'
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
        B rm -Rf ~/Videos/ ~/Public/ ~/Pictures/ ~/Music/ ~/Documents/
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead
# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead
# NEED UPDATE: do not require X interface (or any interactivity at all) to enable automatic security updates, directly modify the appropriate config files instead

if [ $SECTION_CHOICE -le 19 ]; then
    echo '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo 'Follow the directions below.'
        echo
        echo 'enable security updates only'
        echo 'check for updates daily'
        echo 'install security updates only'
        echo 'never remind of dist upgrade'
        echo 'enable Ubuntu (main & universe) repositories only, disable other (restricted & multiverse)'  # NEED ANSWER: why disable security updates from restricted & multiverse repos?
        echo
        S update-manager
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 20 ]; then
    echo '20. [[[ LINUX, INSTALL PERL DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Overview Of Perl Dependencies In This Section ]'
        echo '[ CPAN: The Comprehensive Perl Archive Network, Required For Installing Perl Software ]'
        echo '[ Perl Debug: Symbols For The Perl Interpreter, Optional For Perl Core & XS & RPerl Debugging ]'
        echo '[ Git: Source Code Version Control, Required To Install Latest Development & Unstable Software ]'
        echo '[ Make: Program Builder, Required To Build ExtUtils::MakeMaker ]'
        echo '[ cURL: Downloader, Required To Install cpanminus & Perlbrew & Perl-Build ]'
        echo '[ ExtUtils::MakeMaker: Source Code Builder, Required To Build Many Perl Software Suites ]'
        echo

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            VERIFY_UBUNTU
            echo '[ Install Perl Debugging Symbols System-Wide ]'
            S apt-get install perl-debug
            echo '[ Install git ]'
            S apt-get install git
            echo '[ Install make ]'
            S apt-get install make
            echo '[ Install cURL ]'
            S apt-get install curl
            echo '[ Check Install, Confirm No Errors ]'
            S apt-get -f install

            echo '[ OpenAI Codex: git, cURL, node.js, codex ]'
            S apt-get install git curl
            B git --version
            # DEV NOTE: Node.js v22 or newer is required, must remove default package and install via PPA instead
            # https://github.com/openai/codex
            S apt-get remove nodejs
            S apt autoremove
            S apt-get -f install
            # https://github.com/nodesource/distributions
            B curl -fsSL https://deb.nodesource.com/setup_23.x -o nodesource_setup.sh
            S nodesource_setup.sh
            S apt-get install nodejs
            S apt-get -f install
            B node -v
            # DEV NOTE: config npm permissions to avoid error "It appears you do not have permission..."
            # https://stackoverflow.com/questions/18088372/how-to-npm-install-global-not-as-root
            B npm config set prefix '~/.local/'
            echo '[ OpenAI Codex: ensure "~/.local/bin" is in your PATH environmental variable ]'
            B set | grep PATH
            B npm install -g @openai/codex
            B export OPENAI_API_KEY=insert_real_API_key_here
            B codex
        # OR
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            VERIFY_CENTOS
            echo '[ Install CPAN ]'
            S yum install perl-core perl-CPAN
            echo '[ Install Perl Debugging Symbols System-Wide ]'
            echo '[ NOT CURRENTLY AVAILABLE FOR CENTOS ]'
            echo '[ Install git ]'
            S yum install git
            echo '[ Install make ]'
            S yum install make
            echo '[ Install cURL ]'
            S yum install curl
            if [ $DEVELOPER_CHOICE == 'yes' ]; then
                echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                S yum check
            fi
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
        S "perl -e 'use Config; use File::Path qw(make_path); foreach my \$dir_key (qw(installprivlib installarchlib installsitelib installsitearch)) { if (not -e \$Config{\$dir_key}) { my \$success = make_path(\$Config{\$dir_key}); if (\$success) { print q{Created directory: }, \$Config{\$dir_key}, qq{\\n}; } else { print q{Error, could not create directory: }, \$Config{\$dir_key}, qq{\\n}, \$!, qq{\\n}; } } else { print q{Directory already exists: }, \$Config{\$dir_key}, qq{\\n}; } }'"
        echo '[ Choose "yes" For Automatic Configuration & Also "yes" For Automatic CPAN Mirror Selection ]'
        echo '[ Choose "sudo" For Installation Approach If Previous Command Does Not Solve "Warning: You do not have write permission for Perl library directories." ]'
        S cpan ExtUtils::MakeMaker
        echo '[ Install ExtUtils::MakeMaker System-Wide, Check Updated Version, Must Be v7.04 Or Newer ]'
        S 'perl -MExtUtils::MakeMaker\ 999'

        echo '[ Install markdownlint-cli2 System-Wide, Check Install Runs ]'
        S apt-get install nodejs npm
        S npm install markdownlint-cli2 --global
        B markdownlint-cli2 --help

        echo '[ Check Perl Version To Determine Which Of The Following Sections To Choose ]'
        B perl -v

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 21 VARIABLES
#PERL_INSTALL_CHOICE='__EMPTY__'  # this is now a global variable for command-line args, see top of file

if [ $SECTION_CHOICE -le 21 ]; then
    echo '21. [[[ LINUX, INSTALL PERL & CPANM ]]]'

    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        if [ $PERL_INSTALL_CHOICE == '__EMPTY__' ]; then
            echo 'Please carefully read the following instructions, in order to choose a Perl installation option...'
            echo
            echo '21a. [[[ LINUX, INSTALL SINGLE-USER PERL LOCAL::LIB & CPANM ]]]'
            echo '    [ You SHOULD Use This Instead Of Perlbrew Or Perl From Source Or System Perl In Sections 21b & 21c & 21d, Unless You Have No Choice ]'
            echo '    [ This Option Will Contain All Perl Code In Your Home Directory Under The ~/perl5 Subdirectory ]'
            echo '    [ This Option May  Not Work With Older Versions Of Debian GNU/Linux Which Include A Broken Perl v5.14, Use Perlbrew in Section 21b Instead ]'
            echo '    [ This Option Will Not Work With Older Versions Of Perl Which Are Not At Least v5.10 Or Newer, Use Perlbrew in Section 21b Instead ]'
            echo
            echo '__OR__ '
            echo
            echo '21b. [[[ LINUX, INSTALL SINGLE-USER PERLBREW & CPANM ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of local::lib In Section 21a, Unless You Have No Choice ]'
            echo '    [ This Option WILL Work With Older Versions Of Debian GNU/Linux Which Include A Broken Perl v5.14 ]'
            echo '    [ This Option WILL Work With Older Versions Of Perl Which Are Not At Least v5.10 Or Newer ]'
            echo
            echo '__OR__ '
            echo
            echo '21c. [[[ LINUX, INSTALL SYSTEM-WIDE PERL FROM SOURCE & CPANM ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of local::lib In Section 21a, Unless You Have No Choice ]'
            echo
            echo '__OR__ '
            echo
            echo '21d. [[[ LINUX, INSTALL SYSTEM-WIDE SYSTEM PERL & CPANM ]]]'
            echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 21a, Unless You Have No Choice ]'
            echo '[ This Option Will Install Both Perl & cpanminus System-Wide ]'
            echo '[ Also, All Future CPAN Distributions Will Install System-Wide In A Hard-To Control Manner ]'
            echo
            C 'Please read the warnings above.  Seriously.'
            echo

            P $PERL_INSTALL_CHOICE $'letter or word for a Perl installation option:\n[a] locallib\n[b] perlbrew\n[c] source\n[d] system\n'
            PERL_INSTALL_CHOICE=$USER_INPUT
        fi

        if [ $PERL_INSTALL_CHOICE == 'a' ] || [ $PERL_INSTALL_CHOICE == 'locallib' ]; then

            echo '21a. [[[ LINUX, INSTALL SINGLE-USER PERL LOCAL::LIB & CPANM ]]]'
            echo '[ Install local::lib & CPANM in ~/perl5 ]'
            B 'curl -L cpanmin.us | perl - -l $HOME/perl5 App::cpanminus local::lib'
            echo '[ Enable local::lib In .bashrc Run Commands Startup File ]'
            echo '[ NOTE: Do Not Run The Following Step If You Already Copied Your Own Pre-Existing LAMP University .bashrc File In Section 0 ]'
        # DEV NOTE: pre-munged command for comparison
#       if [ -d $HOME/perl5/lib/perl5 ]; then
#           eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
#       fi

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

        elif [ $PERL_INSTALL_CHOICE == 'b' ] || [ $PERL_INSTALL_CHOICE == 'perlbrew' ]; then

            echo '21b. [[[ LINUX, INSTALL SINGLE-USER PERLBREW & CPANM ]]]'
            echo '[ You Should Use Ubuntu Or CentOS Instead Of curl Below, Unless You Are Not In Ubuntu Or CentOS, Or You Have No Choice ]'
            echo '[ WARNING: Use Only ONE Of The Following Three Options, EITHER Ubuntu OR CentOS OR curl, But NOT More Than One! ]'
            C 'Please read the warning above.  Seriously.'

            if [[ "$OS_CHOICE" == "ubuntu" ]]; then
                VERIFY_UBUNTU

                echo '[ Install Perlbrew ]'
                S apt-get install perlbrew

                echo '[ Check Install, Confirm No Errors ]'
                S apt-get -f install
            # OR
            elif [[ "$OS_CHOICE" == "centos" ]]; then
                VERIFY_CENTOS
                echo '[ WARNING: Use Only ONE Of The Following Two CentOS Options, EITHER CPAN OR perlbrew_install.sh, But NOT More Than One! ]'
                C 'Please read the warning above.  Seriously.'

                echo '[ CENTOS & CPAN ONLY: Install Perl & CPAN ]'
                S yum install perl perl-core perl-CPAN perl-CPAN-Meta
                # DEV NOTE: create Perl lib dirs due to CentOS bug, dirs should already exist but do not, checked by CPAN::FirstTime::_can_write_to_libdirs()
                echo '[ CENTOS & CPAN ONLY: Ensure Perl Library Directories Exist ]'
                S "perl -e 'use Config; use File::Path qw(make_path); foreach my \$dir_key (qw(installprivlib installarchlib installsitelib installsitearch)) { if (not -e \$Config{\$dir_key}) { my \$success = make_path(\$Config{\$dir_key}); if (\$success) { print q{Created directory: }, \$Config{\$dir_key}, qq{\\n}; } else { print q{Error, could not create directory: }, \$Config{\$dir_key}, qq{\\n}, \$!, qq{\\n}; } } else { print q{Directory already exists: }, \$Config{\$dir_key}, qq{\\n}; } }'"
                echo '[ CENTOS & CPAN ONLY: Install CPANM ]'
                S cpan App::cpanminus
                echo '[ CENTOS & CPAN ONLY: Install Perlbrew ]'
                S cpanm -v --notest App::perlbrew

                # OR

                echo '[ CENTOS & perlbrew_install.sh ONLY: Install GCC Compiler & Other Requirements ]'
                S yum install gcc bzip2 patch 
                echo '[ CENTOS & perlbrew_install.sh ONLY: Download perlbrew_install.sh Script ]'
                B curl -L https://install.perlbrew.pl -o perlbrew_install.sh
                echo '[ CENTOS & perlbrew_install.sh ONLY: Run perlbrew_install.sh Script  ]'
                B chmod a+x ./perlbrew_install.sh && ./perlbrew_install.sh
    
                if [ $DEVELOPER_CHOICE == 'yes' ]; then
                    echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                    S yum check
                fi
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
            B cpanm -v --notest ExtUtils::MakeMaker
            echo '[ Re-Check Version Of ExtUtils::MakeMaker, Must Be v7.04 Or Newer ]'
            B 'perl -MExtUtils::MakeMaker\ 999'

        elif [ $PERL_INSTALL_CHOICE == 'c' ] || [ $PERL_INSTALL_CHOICE == 'source' ]; then

            echo '21c. [[[ LINUX, INSTALL SYSTEM-WIDE PERL FROM SOURCE & CPANM ]]]'
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

        elif [ $PERL_INSTALL_CHOICE == 'd' ] || [ $PERL_INSTALL_CHOICE == 'system' ]; then

            echo '21d. [[[ LINUX, INSTALL SYSTEM-WIDE SYSTEM PERL & CPANM ]]]'
            if [[ "$OS_CHOICE" == "ubuntu" ]]; then
                VERIFY_UBUNTU
                echo '[ Install Perl & CPANM ]'
                S apt-get install perl cpanminus
                echo '[ Check Install, Confirm No Errors ]'
                S apt-get -f install
            # OR
            elif [[ "$OS_CHOICE" == "centos" ]]; then
                VERIFY_CENTOS 
                echo '[ Install Perl & CPANM Dependencies ]'
                S yum install perl-core perl-libs perl-devel perl-CPAN curl
                echo '[ Install CPANM System-Wide ]'
                S 'curl -L http://cpanmin.us | perl - --sudo App::cpanminus'
                if [ $DEVELOPER_CHOICE == 'yes' ]; then
                    echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                    S yum check
                fi
            fi
        else
            echo "ERROR: Unrecognized value for PERL_INSTALL_CHOICE, '${PERL_INSTALL_CHOICE}', please see '--help' option for valid values"
        fi
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 22 VARIABLES
# overwrites previous settings, makes it easier to copy-and-paste from LAMP_installer.sh to rperl_installer.sh
EDITOR='__EMPTY__'
USERNAME='__EMPTY__'

if [ $SECTION_CHOICE -le 22 ] && [ $DEVELOPER_CHOICE != 'yes' ]; then
    echo  '22. [[[ LINUX, PACKAGE RPERL DEPENDENCIES ]]]'
    echo
    echo 'SKIPPING!  Developer Sections Disabled'
    echo
    CURRENT_SECTION_COMPLETE
elif [ $SECTION_CHOICE -le 22 ]; then
    echo  '22. [[[ LINUX, PACKAGE RPERL DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then

        # [[[ FPM ]]]
        # [[[ FPM ]]]
        # [[[ FPM ]]]
        # fpm, install deps
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            VERIFY_UBUNTU
            S apt-get install ruby ruby-dev rubygems build-essential
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            VERIFY_CENTOS
            S yum install ruby-devel gcc make rpm-build rubygems perl-generators
        fi

        S gem update --system  # must have RubyGems >= v2.7.5 to avoid "Errno::EPERM: Operation not permitted @ chown_internal" on `bundle install` for fpm dev version
        S cpan App::cpanminus

        # fpm, install release version
        S gem install --no-ri --no-rdoc fpm
        B which fpm
        B fpm --version
        B fpm --verbose -s cpan -t rpm ExtUtils::MakeMaker

# SRPM START HERE: to build source packages, figure out which parts to insert into spec file via --edit, BuildRequires & Obsoletes %build & %install & %check   https://src.fedoraproject.org/cgit/rpms/perl-IO-Compress.git/tree/perl-IO-Compress.spec
# SRPM START HERE: to build source packages, figure out which parts to insert into spec file via --edit, BuildRequires & Obsoletes %build & %install & %check   https://src.fedoraproject.org/cgit/rpms/perl-IO-Compress.git/tree/perl-IO-Compress.spec
# SRPM START HERE: to build source packages, figure out which parts to insert into spec file via --edit, BuildRequires & Obsoletes %build & %install & %check   https://src.fedoraproject.org/cgit/rpms/perl-IO-Compress.git/tree/perl-IO-Compress.spec

        B fpm --verbose --debug-workspace --edit --no-cpan-test -s cpan -t rpm IO::Compress::Gzip
        B rpm -qp --whatprovides ./perl-IO-Compress-2.081-1.noarch.rpm  # package not installed
        B rpm -q --whatprovides  perl-IO-Compress  # package installed
        B repoquery --provides perl-IO-Compress  # package installed or not

        # fpm, install dev version
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            S apt-get install bsdtar
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            S yum install bsdtar
        elif [[ "$OS_CHOICE" == "macosx" ]]; then
            VERIFY_MACOSX
            S xcode-select --install  # Mac OS 10.9 (Mavericks)
        fi

        S gem install bundler
        B mkdir -p ~/repos_github
#        B git clone git@github.com:jordansissel/fpm.git ~/repos_github/fpm-latest
        B git clone https://github.com/wbraswell/fpm.git ~/repos_github/fpm-fork-latest
        CD ~/repos_github/fpm-fork-latest
        S bundle install
            # OUTPUT: ... Using FOO (X.Y.Z)    Using fpm (X.Y.Z) from source at `.`    Using BAR (X.Y.Z) ...
        B make
        # ERRORS MAY OCCUR, it should work anyway
        B export PATH=~/repos_github/fpm-fork-latest/bin:$PATH
        B which fpm
        B fpm --version

        # fpm, build RPerl package w/out deps
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            B reset; rm -Rf ~/cpantofpm_tmp/* ~/cpantofpm_packages/*; cd ~/cpantofpm_packages/; time fpm --no-cpan-test --cpan-verbose --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/cpantofpm_tmp/ -s cpan -t deb --deb-?? RPerl
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            B reset; rm -Rf ~/cpantofpm_tmp/* ~/cpantofpm_packages/*; cd ~/cpantofpm_packages/; time fpm --no-cpan-test --cpan-verbose --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/cpantofpm_tmp/ -s cpan -t rpm --rpm-ba RPerl
        fi

        # [[[ FPM-Cookery ]]]
        # [[[ FPM-Cookery ]]]
        # [[[ FPM-Cookery ]]]
        S gem install bundler
        B mkdir -p ~/repos_github
        B git clone https://github.com/bernd/fpm-cookery.git ~/repos_github/fpm-cookery-latest
        CD ~/repos_github/fpm-cookery-latest
        S bundle install  # ignore warning about not running as root, must run as root for `sudo fpm-cook install-deps` to find facter.rb & other fpm-cookery runtime deps
        B rake spec --trace  # run tests, may seem frozen for 5 - 10 minutes
        B export PATH=~/repos_github/fpm-cookery-latest/bin:$PATH
        B which fpm-cook
        B fpm-cook --version

        B mkdir -p ~/fpm_cookery_tmp
        CD ~/fpm_cookery_tmp
        B vi recipe.rb
            #class Tmux < FPM::Cookery::Recipe
            #  description 'terminal multiplexer'
            #  name     'tmux'
            #  version  '1.9a'
            #  homepage 'http://tmux.github.io'
            #  source   'https://github.com/tmux/tmux/releases/download/1.9a/tmux-1.9a.tar.gz'
            #  build_depends 'libevent-devel', 'ncurses-devel'
            #  depends       'libevent-2.0*'
            #  def build
            #    configure :prefix => prefix
            #    make
            #  end
            #  def install
            #    make :install, 'DESTDIR' => destdir
            #  end
            #end
        S ~/repos_github/fpm-cookery-latest/bin/fpm-cook install-deps
        B fpm-cook

        # [[[ CPANtoFPM ]]]
        # [[[ CPANtoFPM ]]]
        # [[[ CPANtoFPM ]]]
        # cpantofpm, install deps
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            S apt-get install expect  # for unbuffer
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            S yum install expect  # for unbuffer
        fi

        S cpan Module::CoreList
        S cpan Alien::Build
        B cpanm -v --notest MetaCPAN::Client



# FPM THEN START HERE: FPM CPAN pull request pacman test failures; DEB support; RPM mock support
# FPM THEN START HERE: FPM CPAN pull request pacman test failures; DEB support; RPM mock support
# FPM THEN START HERE: FPM CPAN pull request pacman test failures; DEB support; RPM mock support

# FPM THEN START HERE: merge FPM & FPM-Cookery to enable SPEC/SRPM output;; __OR__;; get fpm to accept SPEC file as input; rebuild libbson & mongo-c-driver & mongo-cxx-driver using SPEC files & fpm; manually build SPEC files for PCRE2 & JPCRE2 & PLUTO 
# FPM THEN START HERE: merge FPM & FPM-Cookery to enable SPEC/SRPM output;; __OR__;; get fpm to accept SPEC file as input; rebuild libbson & mongo-c-driver & mongo-cxx-driver using SPEC files & fpm; manually build SPEC files for PCRE2 & JPCRE2 & PLUTO 
# FPM THEN START HERE: merge FPM & FPM-Cookery to enable SPEC/SRPM output;; __OR__;; get fpm to accept SPEC file as input; rebuild libbson & mongo-c-driver & mongo-cxx-driver using SPEC files & fpm; manually build SPEC files for PCRE2 & JPCRE2 & PLUTO 

# FPM THEN START HERE: remove comments in lib/fpm/package/cpan.rb; save all deps files in correct DEPS folder;  skip processing if rpm/srpm/spec/dep files already present, else run fpm w/ force option to overwrite existing file(s); save file names in $distributions_processed & use to make tarball
# FPM THEN START HERE: remove comments in lib/fpm/package/cpan.rb; save all deps files in correct DEPS folder;  skip processing if rpm/srpm/spec/dep files already present, else run fpm w/ force option to overwrite existing file(s); save file names in $distributions_processed & use to make tarball
# FPM THEN START HERE: remove comments in lib/fpm/package/cpan.rb; save all deps files in correct DEPS folder;  skip processing if rpm/srpm/spec/dep files already present, else run fpm w/ force option to overwrite existing file(s); save file names in $distributions_processed & use to make tarball

        # cpantofpm, set hostname to be embedded in packages
        S vi /etc/hostname && hostname -F /etc/hostname && hostname  # packages.rperl.org

        # cpantofpm, set path to executable
        B export PATH=~/repos_gitlab/app-cpantofpm-latest/bin/:$PATH  # NEED FIX, HARD-CODED SHORTCUTS TO ~/cpantofpm BELOW
            # __OR__
        B cd; rm ./cpantofpm ; vi ./cpantofpm ; chmod a+x ./cpantofpm

        # cpantofpm, build RPerl package w/ deps
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            B reset; rm -Rf ~/cpantofpm_tmp/* ~/cpantofpm_packages/*; cd ~/cpantofpm_packages/; time ~/cpantofpm -t deb RPerl
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            B reset; rm -Rf ~/cpantofpm_tmp/* ~/cpantofpm_packages/*; cd ~/cpantofpm_packages/; time ~/cpantofpm -t rpm RPerl
        fi

        # [[[ AStyle ]]]
        # [[[ AStyle ]]]
        # [[[ AStyle ]]]
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            CD ~/cpantofpm_packages/x86_64/
            B wget https://github.com/wbraswell/astyle-mirror/raw/master/backup/astyle-2.05.1-1.el7.centos.x86_64.rpm
            CD ~/cpantofpm_packages/SRPMS/
            B wget https://github.com/wbraswell/astyle-mirror/raw/master/backup/astyle-2.05.1-1.el7.centos.src.rpm
            # NEED UPGRADE: copy spec file out of srpm into SPECS/ directory
        fi

        # [[[ PCRE2 ]]]
        # [[[ PCRE2 ]]]
        # [[[ PCRE2 ]]]
        CD ~/
        B wget https://ftp.pcre.org/pub/pcre/pcre2-10.31.tar.gz
        B tar -xzvf pcre2-10.31.tar.gz
        CD pcre2-10.31
        B ./configure --enable-pcre2-16 --enable-pcre2-32 --disable-shared --enable-jit
        B make
        B make check
        B mkdir -p ~/fpm_tmp_install && rm -Rf ~/fpm_tmp_install/*
        B make install DESTDIR=~/fpm_tmp_install
        CD ~/
        B mkdir -p ~/fpm_tmp_work && rm -Rf ~/fpm_tmp_work/*

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            B reset; time fpm --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/fpm_tmp_work/ -s dir -t rpm --rpm-ba -p libpcre2-VERSION_ARCH.rpm     -n libpcre2     -v 10.31 -C ~/fpm_tmp_install usr/local/lib usr/local/bin usr/local/share
            B rm libpcre2-10.31_x86_64.rpm  # prefer file naming uniformity with '-1' in all file names
            B cp ~/fpm_tmp_work/package-rpm-build-*/RPMS/x86_64/libpcre2-10.31-1.x86_64.rpm ~/cpantofpm_packages/x86_64/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SRPMS/libpcre2-10.31-1.src.rpm ~/cpantofpm_packages/SRPMS/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SPECS/libpcre2.spec ~/cpantofpm_packages/SPECS/
            B mkdir -p ~/fpm_tmp_work && rm -Rf ~/fpm_tmp_work/*
            B reset; time fpm --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/fpm_tmp_work/ -s dir -t rpm --rpm-ba -p libpcre2-dev_VERSION_ARCH.rpm -n libpcre2-dev -v 10.31 -C ~/fpm_tmp_install usr/local/include
            B rm libpcre2-dev_10.31_x86_64.rpm  # prefer file naming uniformity with '-1' in all file names
            B cp ~/fpm_tmp_work/package-rpm-build-*/RPMS/x86_64/libpcre2-dev-10.31-1.x86_64.rpm ~/cpantofpm_packages/x86_64/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SRPMS/libpcre2-dev-10.31-1.src.rpm ~/cpantofpm_packages/SRPMS/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SPECS/libpcre2-dev.spec ~/cpantofpm_packages/SPECS/
        fi

        B rm -Rf pcre2-10.31.tar.gz pcre2-10.31 ~/fpm_tmp_work ~/fpm_tmp_install

        # [[[ JPCRE2 ]]]
        # [[[ JPCRE2 ]]]
        # [[[ JPCRE2 ]]]
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            S rpm -i ~/cpantofpm_packages/x86_64/libpcre2-10.31-1.x86_64.rpm
            S rpm -i ~/cpantofpm_packages/x86_64/libpcre2-dev-10.31-1.x86_64.rpm
        fi

        CD ~/
        B wget https://github.com/jpcre2/jpcre2/archive/10.31.02-2.tar.gz -O jpcre2-10.31.02-2.tar.gz
        B tar -xzvf jpcre2-10.31.02-2.tar.gz
        CD jpcre2-10.31.02-2
        B ./configure --disable-cpp11 --enable-test
        B make
        B make check
        B mkdir -p ~/fpm_tmp_install && rm -Rf ~/fpm_tmp_install/*
        B make install DESTDIR=~/fpm_tmp_install
        CD ~/
        B mkdir -p ~/fpm_tmp_work && rm -Rf ~/fpm_tmp_work/*

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            B reset; time fpm --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/fpm_tmp_work/ -s dir -t rpm --rpm-ba -p libjpcre2-dev_VERSION_ARCH.rpm -n libjpcre2-dev -v 10.31.02-2 -d "libpcre2 >= 10.31" -d "libpcre2-dev >= 10.31" -C ~/fpm_tmp_install usr/local/include usr/local/share/doc
            B rm libjpcre2-dev_10.31.02_2_x86_64.rpm  # prefer file naming uniformity with '-1' in all file names
            B cp ~/fpm_tmp_work/package-rpm-build-*/RPMS/x86_64/libjpcre2-dev-10.31.02_2-1.x86_64.rpm ~/cpantofpm_packages/x86_64/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SRPMS/libjpcre2-dev-10.31.02_2-1.src.rpm ~/cpantofpm_packages/SRPMS/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SPECS/libjpcre2-dev.spec ~/cpantofpm_packages/SPECS/
            S rpm -e libpcre2 libpcre2-dev
        fi
 
        B rm -Rf jpcre2-10.31.02-2.tar.gz jpcre2-10.31.02-2 ~/fpm_tmp_work/ ~/fpm_tmp_install/

        # [[[ Pluto ]]]
        # [[[ Pluto ]]]
        # [[[ Pluto ]]]
        CD ~/
        B wget https://github.com/bondhugula/pluto/files/737550/pluto-0.11.4.tar.gz
        B tar -xzvf pluto-0.11.4.tar.gz
        CD pluto-0.11.4
        B ./configure
        B make
        B make test
        B mkdir -p ~/fpm_tmp_install && rm -Rf ~/fpm_tmp_install/*
        B make install DESTDIR=~/fpm_tmp_install
        CD ~/
        B mkdir -p ~/fpm_tmp_work && rm -Rf ~/fpm_tmp_work/*

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            B reset; time fpm --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/fpm_tmp_work/ -s dir -t rpm --rpm-ba -p pluto-polycc-VERSION_ARCH.rpm     -n pluto-polycc     -v 0.11.4 -C ~/fpm_tmp_install usr/local/lib usr/local/bin usr/local/share
            B rm pluto-polycc-0.11.4_x86_64.rpm  # prefer file naming uniformity with '-1' in all file names
            B cp ~/fpm_tmp_work/package-rpm-build-*/RPMS/x86_64/pluto-polycc-0.11.4-1.x86_64.rpm ~/cpantofpm_packages/x86_64/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SRPMS/pluto-polycc-0.11.4-1.src.rpm ~/cpantofpm_packages/SRPMS/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SPECS/pluto-polycc.spec ~/cpantofpm_packages/SPECS/
            B mkdir -p ~/fpm_tmp_work && rm -Rf ~/fpm_tmp_work/*
            B reset; time fpm --verbose --debug-workspace --maintainer 'William N. Braswell, Jr. <william.braswell@NOSPAM.autoparallel.com>' --workdir ~/fpm_tmp_work/ -s dir -t rpm --rpm-ba -p pluto-polycc-dev-VERSION_ARCH.rpm -n pluto-polycc-dev -v 0.11.4 -C ~/fpm_tmp_install usr/local/include
            B rm pluto-polycc-dev-0.11.4_x86_64.rpm  # prefer file naming uniformity with '-1' in all file names
            B cp ~/fpm_tmp_work/package-rpm-build-*/RPMS/x86_64/pluto-polycc-dev-0.11.4-1.x86_64.rpm ~/cpantofpm_packages/x86_64/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SRPMS/pluto-polycc-dev-0.11.4-1.src.rpm ~/cpantofpm_packages/SRPMS/
            B cp ~/fpm_tmp_work/package-rpm-build-*/SPECS/pluto-polycc-dev.spec ~/cpantofpm_packages/SPECS/
        fi

        B rm -Rf pluto-0.11.4.tar.gz pluto-0.11.4 ~/fpm_tmp_work/ ~/fpm_tmp_install/

        # [[[ BSON ]]]
        # [[[ BSON ]]]
        # [[[ BSON ]]]

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            echo '[ Build RPerl Dependencies, MongoDB C++ Driver Prerequisites, BSON libbson ]'
            # perl-interpreter is a dummy package for CentOS 7 compatibility with Fedora source packages libbson & mongo-c-driver
            S yum install rpm-build libtool cyrus-sasl-lib cyrus-sasl-devel snappy-devel perl-interpreter python-sphinx

#            B wget http://dl.fedoraproject.org/pub/fedora/linux/updates/27/SRPMS/Packages/l/libbson-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer GitHub mirror below
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer our own GitHub mirror for uniformity
            S rpm -i -vv ./libbson-1.9.3-1.fc27.src.rpm
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson.spec
            S mv ./libbson.spec /root/rpmbuild/SPECS/libbson.spec
            S rpmbuild -ba /root/rpmbuild/SPECS/libbson.spec
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/libbson-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/libbson-devel-1.9.3-1.el7.centos.x86_64.rpm  # provides pkgconfig(libbson-1.0) to satisfy mongodb-c-driver requirements
            
            # DEV NOTE: check if SRPM can be rebuilt
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.src.rpm
#            B rpm -ivh ./libbson-1.9.3-1.el7.centos.src.rpm
#            S yum-builddep libbson
#            B rpmbuild -v -ba ~/rpmbuild/SPECS/libbson.spec

            # DEV NOTE: copy our own pre-built packages into CPANtoFPM directory structure
            CD ~/cpantofpm_packages/SPECS/
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson.spec 
            CD ~/cpantofpm_packages/SRPMS/
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.src.rpm 
            CD ~/cpantofpm_packages/x86_64/
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-devel-1.9.3-1.el7.centos.x86_64.rpm
        fi

        # [[[ MongoDB C Driver ]]]
        # [[[ MongoDB C Driver ]]]
        # [[[ MongoDB C Driver ]]]
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            echo 'NEED DEB COMMANDS HERE'
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            echo '[ Build RPerl Dependencies, MongoDB C++ Driver Prerequisites, MongoDB C Driver ]'
#            B wget http://dl.fedoraproject.org/pub/fedora/linux/updates/27/SRPMS/Packages/m/mongo-c-driver-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer GitHub mirror below
#            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.fc27.src.rpm  # DEV NOTE: prefer our own GitHub mirror for uniformity
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.el7.centos.src.rpm  # DEV NOTE: prefer our own re-built source RPMs for uniformity
            S rpm -i -vv mongo-c-driver-1.9.3-1.fc27.src.rpm
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver.spec
            S mv ./mongo-c-driver.spec /root/rpmbuild/SPECS/mongo-c-driver.spec
            S systemctl stop mongodb.service
            S rpmbuild -ba /root/rpmbuild/SPECS/mongo-c-driver.spec
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm
            S systemctl start mongodb.service

            # DEV NOTE: copy our own pre-built packages into CPANtoFPM directory structure
            CD ~/cpantofpm_packages/SPECS/
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver.spec
            CD ~/cpantofpm_packages/SRPMS/
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.el7.centos.src.rpm
            CD ~/cpantofpm_packages/x86_64/
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-libs-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/mongo-c-driver-devel-1.9.3-1.el7.centos.x86_64.rpm
        fi

        # [[[ MongoDB C++ Driver ]]]
        # [[[ MongoDB C++ Driver ]]]
        # [[[ MongoDB C++ Driver ]]]
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            # DEB START HERE: create packages
            # DEB START HERE: create packages
            # DEB START HERE: create packages

            # BEGIN UBUNTU MANUAL BUILD, MONGOCXX C++ DRIVER

            D $EDITOR 'preferred text editor' 'vi'
            EDITOR=$USER_INPUT
            D $USERNAME "new machine's username" `whoami`
            USERNAME=$USER_INPUT

            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Download & Uncompress ]'
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0.tar.gz
            B tar -xzvf mongo-cxx-driver-3.2.0.tar.gz && cd mongo-cxx-driver-3.2.0/build 

            # CMake Error at /usr/lib/x86_64-linux-gnu/cmake/libbson-1.0/libbson-1.0-config.cmake:28 (message): File or directory /usr/lib/include/libbson-1.0 referenced by variable BSON_INCLUDE_DIRS does not exist !
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Copy The Following Line ]'
            echo "set (PACKAGE_PREFIX_DIR /usr)  # WBRASWELL 20180615 2018.166: manually set PACKAGE_PREFIX_DIR due to CMake 'does not exist' failures"
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Paste The Now-Copied Line Immediately BEFORE The Following Line ]'
            echo "set_and_check (BSON_INCLUDE_DIRS \"${PACKAGE_PREFIX_DIR}/include/libbson-1.0\")"
            S $EDITOR /usr/lib/x86_64-linux-gnu/cmake/libbson-1.0/libbson-1.0-config.cmake
            # CMake Error at /usr/lib/x86_64-linux-gnu/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake:31 (message): File or directory /usr/lib/include/libmongoc-1.0 referenced by variable MONGOC_INCLUDE_DIRS does not exist !
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Paste The Now-Copied Line AGAIN Immediately BEFORE The Following Line ]'
            echo "set_and_check (MONGOC_INCLUDE_DIRS \"${PACKAGE_PREFIX_DIR}/include/libmongoc-1.0\")"
            S $EDITOR /usr/lib/x86_64-linux-gnu/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake

            # CMake Error: The following variables are used in this project, but they are set to NOTFOUND.  Please set them or make sure they are set and tested correctly in the CMake files: BSON_LIBRARY MONGOC_LIBRARY
    #        B cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/lib ..
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Configure The C++ Build Process ]'
            B cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DMONGOC_LIBRARY=/usr/lib/x86_64-linux-gnu/libmongoc-1.0.so -DBSON_LIBRARY=/usr/lib/x86_64-linux-gnu/libbson-1.0.so ..
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Build & Install The Minimalistic Polyfill ]'
            S make EP_mnmlstc_core
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Build ]'
            B make
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Install ]'
            S make install
    #        S ln -sf /usr/lib/pkgconfig/libmongocxx.pc /usr/share/pkgconfig/libmongocxx.pc  # NOT NECESSARY IN UBUNTU???
    #        S ln -sf /usr/lib/pkgconfig/libbsoncxx.pc /usr/share/pkgconfig/libbsoncxx.pc    # NOT NECESSARY IN UBUNTU???
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Before Running Optional Test Program, Please Install MongoDB Server Via LAMP Installer SECTION 60 [[[ UBUNTU LINUX, INSTALL MONGODB ]]] ]'
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Save Test Program ]'
            B printf "#include <iostream>\n#include <bsoncxx/builder/stream/document.hpp>\n#include <bsoncxx/json.hpp>\n#include <mongocxx/client.hpp>\n#include <mongocxx/instance.hpp>\nint main(int, char**) {\n    mongocxx::instance inst{};\n    mongocxx::client conn{mongocxx::uri{}};\n    bsoncxx::builder::stream::document document{};\n    auto collection = conn[\"testdb\"][\"testcollection\"];\n    document << \"hello\" << \"world\";\n    collection.insert_one(document.view());\n    auto cursor = collection.find({});\n    for (auto&& doc : cursor) {\n        std::cout << bsoncxx::to_json(doc) << std::endl;\n    }\n}" > ./mongocxx_test.cpp
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Compile Test Program ]'
            B c++ --std=c++11 mongocxx_test.cpp -o mongocxx_test -I/usr/include/mongocxx/v_noabi -I/usr/include/bsoncxx/v_noabi/ -L/usr/lib -Wl,-rpath,/usr/lib -lmongocxx -lbsoncxx
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Run Test Program ]'
            B ./mongocxx_test
            echo '[ UBUNTU MANUAL BUILD ONLY: Install RPerl Dependency MongoDB C++ Driver; Delete Test Program ]'
            B rm -Rf ./mongocxx_test*

            # END UBUNTU MANUAL BUILD, MONGOCXX C++ DRIVER

        elif [[ "$OS_CHOICE" == "centos" ]]; then
#            # DEV NOTE: prefer pre-built RPMs below
#            echo '[ Build RPerl Dependencies, MongoDB C++ Driver Prerequisites, Fix Broken CMake Files ]'
#            # NEED ANSWER: can we fix this CMake error permanently by including --enable-static in configure for both libbson & mongo-c-driver above???
#            # CMake Error at /lib64/cmake/libbson-1.0/libbson-1.0-config.cmake:28 (message): File or directory //include/libbson-1.0 referenced by variable BSON_INCLUDE_DIRS does not exist !
#            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.0-config.cmake
#            S mv ./libbson-1.0-config.cmake /lib64/cmake/libbson-1.0/libbson-1.0-config.cmake
#            # CMake Error at /lib64/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake:30 (message): File or directory //include/libmongoc-1.0 referenced by variable MONGOC_INCLUDE_DIRS does not exist !
#            B wget https://github.com/wbraswell/mongo-c-driver-mirror/raw/master/libmongoc-1.0-config.cmake
#            S mv ./libmongoc-1.0-config.cmake /lib64/cmake/libmongoc-1.0/libmongoc-1.0-config.cmake

            echo '[ Build RPerl Dependencies, MongoDB C++ Driver ]'
            S yum install cmake3

#            # DEV NOTE: prefer already-fixed tarball below
#            B wget https://github.com/mongodb/mongo-cxx-driver/archive/r3.2.0.tar.gz
#            S mv ./r3.2.0.tar.gz /root/rpmbuild/SOURCES/mongo-cxx-driver-3.2.0.tar.gz
#            CD /root/rpmbuild/SOURCES
#            S tar -xzvf mongo-cxx-driver-3.2.0.tar.gz
#            S mv mongo-cxx-driver-r3.2.0 mongo-cxx-driver-3.2.0
#            S rm mongo-cxx-driver-3.2.0.tar.gz
#            S tar -czvf mongo-cxx-driver-3.2.0.tar.gz ./mongo-cxx-driver-3.2.0
            # DEV NOTE: prefer our own already-fixed tarball below, for convenience
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0.tar.gz
            S mv ./mongo-cxx-driver-3.2.0.tar.gz /root/rpmbuild/SOURCES/mongo-cxx-driver-3.2.0.tar.gz
            CD /root/rpmbuild/SPECS
            S wget https://raw.githubusercontent.com/wbraswell/mongo-cxx-driver-mirror/master/mongo-cxx-driver.spec
            S rpmbuild -ba /root/rpmbuild/SPECS/mongo-cxx-driver.spec
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
            S rpm -i -vv /root/rpmbuild/RPMS/x86_64/mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm

            # DEV NOTE: copy our own pre-built packages into CPANtoFPM directory structure
            CD ~/cpantofpm_packages/SPECS/
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver.spec    
            CD ~/cpantofpm_packages/SRPMS/
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0-1.el7.centos.src.rpm
            CD ~/cpantofpm_packages/x86_64/
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-libs-3.2.0-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-3.2.0-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/mongo-cxx-driver-mirror/raw/master/mongo-cxx-driver-devel-3.2.0-1.el7.centos.x86_64.rpm
        fi

        # [[[ RPM, YUM REPOSITORY ]]]
        # [[[ RPM, YUM REPOSITORY ]]]
        # [[[ RPM, YUM REPOSITORY ]]]

        # server, install deps, RUN ONCE ONLY
        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            S apt-get install createrepo yum-utils gnupg2 gnupg-agent rng-tools
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            S yum install createrepo yum-utils gnupg2 rng-tools
        fi

        # server, prepare to receive RPMs tarball
        S mkdir -p /srv/www/packages.rperl.org/public_html/centos/7/rperl
        CD /srv/www/packages.rperl.org/public_html/centos/7/rperl
        S rm -Rf DEPS SPECS SRPMS x86_64 *.tar.gz
        
        # packager machine, create & transfer RPMs tarball
        B ~/manual_packages_copy.sh
        CD ~/cpantofpm_packages
        B tar -czvf ./perl-RPerl-VERSION-1-RPM_ALL_DEPS.tar.gz ./*
        B scp ./perl-RPerl-VERSION-1-RPM_ALL_DEPS.tar.gz packages.rperl.org:/srv/www/packages.rperl.org/public_html/centos/7/rperl/

        # server, unpack RPMs tarball & set initial permissions
        CD /srv/www/packages.rperl.org/public_html/centos/7/rperl
        B tar -xzvf perl-RPerl-VERSION-1-RPM_ALL_DEPS.tar.gz
        S chown -R www-data.www-data /srv/www/packages.rperl.org/
        S chmod -R g+rwX,o-w /srv/www/packages.rperl.org/

        # server, generate & export & import GPG keys, RUN ONCE ONLY
        S rngd -r /dev/urandom
        B gpg2 --full-gen-key
            # William N. Braswell, Jr. (packages.rperl.org) <william.braswell@autoparallel.com>
        B gpg2 --list-keys
        B gpg2 --export --armor "William N. Braswell, Jr. (packages.rperl.org) <william.braswell@autoparallel.com>" > /srv/www/packages.rperl.org/public_html/centos/RPM-GPG-KEY-RPerl-7
        B less /srv/www/packages.rperl.org/public_html/centos/RPM-GPG-KEY-RPerl-7  # confirm key has been exported
        B rpmkeys --import /srv/www/packages.rperl.org/public_html/centos/RPM-GPG-KEY-RPerl-7
        B rpm -q gpg-pubkey --qf '%{NAME}-%{VERSION}-%{RELEASE}\t%{SUMMARY}\n'  # confirm key has been imported

        # server, prepare to sign RPMs, RUN ONCE ONLY
        B vi ~/.rpmmacros
            # %_signature gpg
            # %_gpg_name William N. Braswell, Jr. (packages.rperl.org) <william.braswell@autoparallel.com>
            # %_gpg_bin /usr/bin
            # %__gpg /usr/bin/gpg2

        # server, sign RPMs & confirm signed
        CD /srv/www/packages.rperl.org/public_html/centos/7/rperl
        B export GPG_TTY=$(tty)
        B rpmsign --addsign SRPMS/*.rpm x86_64/*.rpm
        B rpm -qpi SRPMS/*.rpm x86_64/*.rpm | grep Signature

        # server, create repo & sign repo metadata & confirm signed
        CD /srv/www/packages.rperl.org/public_html/centos/7/rperl/x86_64
        B rm -Rf ./repodata/
        B createrepo --verbose .
        B gpg2 --detach-sign --armor repodata/repomd.xml
        B less repodata/repomd.xml.asc

        # server, generate repo file, RUN ONCE ONLY
        B vi /srv/www/packages.rperl.org/public_html/centos7-perl-cpan.repo
            [centos7-perl-cpan]
            name=CentOS 7 Perl CPAN Repository
            baseurl=https://packages.rperl.org/centos/7/rperl/x86_64/
            enabled=1
            gpgcheck=1
            repo_gpgcheck=1
            gpgkey=https://packages.rperl.org/centos/RPM-GPG-KEY-RPerl-7

        # server, set final permissions
        S chown -R www-data.www-data /srv/www/packages.rperl.org/
        S chmod -R g+rwX,o-w /srv/www/packages.rperl.org/

        # [[[ DEB, APT REPOSITORY ]]]
        # [[[ DEB, APT REPOSITORY ]]]
        # [[[ DEB, APT REPOSITORY ]]]

# DEB START HERE: set up server, set up client, install
# DEB START HERE: set up server, set up client, install
# DEB START HERE: set up server, set up client, install

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 23 ]; then
    echo '23. [[[ LINUX, INSTALL RPERL DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Overview Of RPerl Dependencies In This Section ]'
        echo '[ GCC: gcc & g++ Required For Compiling ]'
        echo '[ libc: libcrypt.(a|so) Required For Compiling ]'
        echo '[ libperl: libperl.(a|so) & perl.h etc, Required For Compiling ]'
        echo '[ openssl: err.h Required By RPerl Subdependency Net::SSLeay From IO::Socket::SSL From ... From Alien::* ]'
        echo '[ zlib: zlib.h Required By SDL.pm, Itself Required For Graphics In RPerl Applications ]'
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

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            VERIFY_UBUNTU
            echo '[ Add Non-Base APT Repositories ]'
            S add-apt-repository \"deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) main universe restricted multiverse\"
            echo '[ Update APT Repositories ]'
            S apt-get update
            echo '[ Install RPerl Dependencies ]'
            S apt-get install g++ make libc6-dev perl libperl-dev libssl-dev zlib1g zlib1g-dev libgmp10 libgmpxx4ldbl libgmp-dev libgsl-dev texinfo flex bison astyle

            echo '[ Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, pkg-config ]'
            S apt-get install pkg-config

# DEB START HERE: build & use our own libbson & libmongoc & libmongocxx packages, remove use of Bionic repo below
# DEB START HERE: build & use our own libbson & libmongoc & libmongocxx packages, remove use of Bionic repo below
# DEB START HERE: build & use our own libbson & libmongoc & libmongocxx packages, remove use of Bionic repo below

            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; Must Use Latest libbson & libmongoc From Bionic v18.04 Repositories ]"
            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; In Xenial v16.04, Temporarily Replace All Occurrences Of 'xenial' With 'bionic' (Same For Other Non-Bionic Releases), Skip If Already Using Bionic Or Newer ]"
            S $EDITOR /etc/apt/sources.list
            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; Update To Bionic v18.04 Repositories, Skip If Already Using Bionic Or Newer ]"
            S apt-get update
            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; Install libbson & libmongoc From Bionic v18.04 Repositories ]"
            S apt-get install libbson-1.0-0 libbson-dev libmongoc-1.0-0 libmongoc-dev
            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; In Xenial v16.04, Replace All Occurrences Of 'bionic' With Original 'xenial' (Same For Other Non-Bionic Releases), Skip If Already Using Bionic Or Newer ]"
            S $EDITOR /etc/apt/sources.list
            echo "[ Install RPerl Dependencies, MongoDB C & C++ Drivers; Update To Original Non-Bionic Repositories, Skip If Already Using Bionic Or Newer ]"
            S apt-get update

            echo '[ Check Install, Confirm No Errors ]'
            S apt-get -f install
        # OR
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            VERIFY_CENTOS


# RPM START HERE: remove wget & rpm below w/ yum via packages.rperl.org, astyle & libbson & libmongoc & libmongocxx & pluto
# RPM START HERE: remove wget & rpm below w/ yum via packages.rperl.org
# RPM START HERE: remove wget & rpm below w/ yum via packages.rperl.org


            echo '[ Install RPerl Dependencies ]'
            S yum install gcc-c++ make glibc-devel perl-core perl-libs perl-devel openssl-devel zlib zlib-static zlib-devel gmp gmp-static gmp-devel gsl gsl-devel texinfo flex bison
            echo '[ Install RPerl Dependencies, GCC/G++ GDB Debugging Symbols ]'
#            S debuginfo-install cracklib-2.9.0-11.el7.x86_64 cyrus-sasl-lib-2.1.26-21.el7.x86_64 glibc-2.17-196.el7_4.2.x86_64 keyutils-libs-1.5.8-3.el7.x86_64 krb5-libs-1.15.1-8.el7.x86_64 libcom_err-1.42.9-10.el7.x86_64 libgcc-4.8.5-16.el7_4.2.x86_64 libselinux-2.5-11.el7.x86_64 libstdc++-4.8.5-16.el7_4.2.x86_64 nspr-4.13.1-1.0.el7_3.x86_64 nss-3.28.4-15.el7_4.x86_64 nss-softokn-freebl-3.28.3-8.el7_4.x86_64 nss-util-3.28.4-3.el7.x86_64 openldap-2.4.44-5.el7.x86_64 openssl-libs-1.0.2k-8.el7.x86_64 pcre-8.32-17.el7.x86_64 postgresql96-libs-9.6.8-1PGDG.rhel7.x86_64 zlib-1.2.7-17.el7.x86_64
            S debuginfo-install cracklib cyrus-sasl-lib glibc keyutils-libs krb5-libs libcom_err libgcc libselinux libstdc++ nspr nss nss-softokn-freebl nss-util openldap openssl-libs pcre postgresql96-libs zlib

            echo '[ Download & Install RPerl Dependency AStyle ]'
            B wget https://github.com/wbraswell/astyle-mirror/raw/master/backup/astyle-2.05.1-1.el7.centos.x86_64.rpm
            S rpm -v -i ./astyle-2.05.1-1.el7.centos.x86_64.rpm
            echo '[ Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, pkg-config ]'
            S yum install pkgconfig

            # OLD VERSIONS, DO NOT USE!  libbson v1.3.5-5.el7, mongo-c-driver-libs v1.3.6-1.el7, mongo-c-driver v1.3.6-1.el7
            # must have new versions for MongoDB C++ driver compatibility
            # "For mongocxx-3.2.x, libmongoc 1.8.2 or later is required."    https://mongodb.github.io/mongo-cxx-driver/mongocxx-v3/installation/
#            echo '[ Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, MongoDB C Driver ]'
#            S yum install pkgconfig mongo-c-driver

            echo '[ Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, BSON libbson ]'

            # DEV NOTE: use our own pre-built RPMs from GitHub mirror, for speed & reliability & convenience
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-1.9.3-1.el7.centos.x86_64.rpm
            B wget https://github.com/wbraswell/libbson-mirror/raw/master/libbson-devel-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./libbson-1.9.3-1.el7.centos.x86_64.rpm
            S rpm -i -vv ./libbson-devel-1.9.3-1.el7.centos.x86_64.rpm  # provides pkgconfig(libbson-1.0) to satisfy mongodb-c-driver requirements
            B rm ./libbson-1.9.3-1.el7.centos.x86_64.rpm
            B rm ./libbson-devel-1.9.3-1.el7.centos.x86_64.rpm

            echo '[ Install RPerl Dependencies, MongoDB C++ Driver Prerequisites, MongoDB C Driver ]'

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

            echo '[ Install RPerl Dependencies, MongoDB C++ Driver ]'

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

            if [ $DEVELOPER_CHOICE == 'yes' ]; then
                echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
                S yum check
            fi
        # OR
        elif [[ "$OS_CHOICE" == "OTHER" ]]; then
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

            echo '[ MANUAL BUILD ONLY: Install RPerl Dependency Pluto PolyCC, Download ]'
            # B 'wget https://github.com/wbraswell/pluto-mirror/raw/master/backup/pluto-0.11.4.tar.gz; tar -xzvf pluto-0.11.4.tar.gz'  # prefer official repo below
            B 'wget https://github.com/bondhugula/pluto/files/737550/pluto-0.11.4.tar.gz; tar -xzvf pluto-0.11.4.tar.gz'
            echo '[ MANUAL BUILD ONLY: Install RPerl Dependency Pluto PolyCC, Build ]'
            B 'cd pluto-0.11.4; ./configure; make; make test'
            echo '[ Install RPerl Dependency Pluto PolyCC, Install ]'
            S 'cd pluto-0.11.4; make install'
        fi

        echo '[ Check GCC Version, Must Be v4.7 Or Newer; If Automatic Install Options Fail Or Are Too Old, Then Restart Installer & Select OTHER Operating System For Manual Build Option ]'
        B g++ --version

        echo '[ Check AStyle Version, Must Be v2.05.1 Or Newer; If Automatic Install Options Fail Or Are Too Old, Then Restart Installer & Select OTHER Operating System For Manual Build Option ]'
        B astyle -V

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 24 VARIABLES
#RPERL_INSTALL_CHOICE='__EMPTY__'  # this is now a global variable for command-line args, see top of file

# SECTION 24b VARIABLES
GITHUB_EMAIL='__EMPTY__'
GITHUB_FIRST_NAME='__EMPTY__'
GITHUB_LAST_NAME='__EMPTY__'
RPERL_REPO_DIR='__EMPTY__'

if [ $SECTION_CHOICE -le 24 ]; then
    echo '24. [[[ PERL, INSTALL RPERL ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        if [ $RPERL_INSTALL_CHOICE == '__EMPTY__' ]; then
            echo 'Please carefully read the following instructions, in order to choose an RPerl installation option...'
            echo
            echo '24a. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA PACKAGES.RPERL.ORG ]]]'
            echo '    [ You Should Use This Instead Of Stable Via CPAN Or Unstable Via GitHub In The Following Sub-Sections, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Stable Public Release Of RPerl, Pre-Built & Pre-Compiled ]'
            echo
            echo '__OR__ '
            echo
            echo '24b. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPANM, SINGLE-USER ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Stable Public Release Of RPerl, Built & Compiled On Your System, Using `cpanm` For Your Single User Only ]'
            echo
            echo '__OR__ '
            echo
            echo '24c. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPANM, SYSTEM-WIDE ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Stable Public Release Of RPerl, Built & Compiled On Your System, Using `cpanm` For The Entire System ]'
            echo
            echo '__OR__ '
            echo
            echo '24d. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPAN, SINGLE-USER ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Stable Public Release Of RPerl, Built & Compiled On Your System, Using `cpan` For Your Single User Only ]'
            echo
            echo '__OR__ '
            echo
            echo '24e. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPAN, SYSTEM-WIDE ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Stable Public Release Of RPerl, Built & Compiled On Your System, Using `cpan` For The Entire System ]'
            echo
            echo '__OR__ '
            echo
            echo '24f. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, SECURE GIT ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Unstable Development Release Of RPerl, Built & Compiled On Your System, Using Secure Github For Your Single User Only ]'
            echo
            echo '__OR__ '
            echo
            echo '24g. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, PUBLIC GIT ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Unstable Development Release Of RPerl, Built & Compiled On Your System, Using Public Github For Your Single User Only ]'
            echo
            echo '__OR__ '
            echo
            echo '24h. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, PUBLIC ZIP ]]]'
            echo '    [ You SHOULD NOT Use This Instead Of Stable Via Packages In Section 24a, Unless You Are An RPerl System Developer ]'
            echo '    [ This Option Will Install The Latest Unstable Development Release Of RPerl, Built & Compiled On Your System, Using Public Github For Your Single User Only ]'

            C 'Please read the warnings above.  Seriously.'
            echo

            P $RPERL_INSTALL_CHOICE $'letter or word for an RPerl installation option:\n[a] packages\n[b] cpanm-single\n[c] cpanm-system\n[d] cpan-single\n[e] cpan-system\n[f] github-secure-git\n[g] github-public-git\n[h] github-public-zip\n'
            RPERL_INSTALL_CHOICE=$USER_INPUT
        fi

        if [ $RPERL_INSTALL_CHOICE == 'a' ] || [ $RPERL_INSTALL_CHOICE == 'packages' ]; then
            echo '24a. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA PACKAGES.RPERL.ORG ]]]'
            echo

            if [[ "$OS_CHOICE" == "ubuntu" ]]; then
                # DEB START HERE: create packages
                # DEB START HERE: create packages
                # DEB START HERE: create packages
                echo 'NEED DEB COMMANDS HERE'
            elif [[ "$OS_CHOICE" == "centos" ]]; then
                S yum install pygpgme  # check GPG signatures of repo metadata & packages
                S yum-config-manager --add-repo https://packages.rperl.org/centos7-perl-cpan.repo
                S yum-config-manager --enable centos7-perl-cpan
                S yum repolist all    # confirm repo is in list
                S yum clean metadata  # clean metadata from other repos, or after updating our repo
                S yum install perl-RPerl

                echo '[ CHECK RPERL INSTALL ]'
                B which rperl
                B rpm -qf /usr/bin/rperl

                echo '[ UNINSTALL RPERL, IF LAST TRANSACTION ]'
                S yum history
                S yum history undo last
            fi

        elif [ $RPERL_INSTALL_CHOICE == 'b' ] || [ $RPERL_INSTALL_CHOICE == 'cpanm-single' ]; then
            echo '24b. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPANM, SINGLE-USER ]]]'
            echo '[ You Should Only Use This Option 24b If local::lib Or Perlbrew Is Installed For Your User ]'
            echo

            echo '[ Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
            B cpanm -v --notest IO::Socket::SSL
            echo '[ Install Missing Alien::GMP Dependencies ]'
            B cpanm -v --notest File::Which FFI::CheckLib Path::Tiny File::chdir Capture::Tiny Alien::GMP
            echo '[ Install RPerl ]'
            B cpanm -v --notest RPerl

        elif [ $RPERL_INSTALL_CHOICE == 'c' ] || [ $RPERL_INSTALL_CHOICE == 'cpanm-system' ]; then
            echo '24c. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPANM, SYSTEM-WIDE ]]]'
            echo '[ You Should Only Use This Option 24c If local::lib Or Perlbrew Is NOT Installed For Your User ]'
            echo

            echo '[ Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
            S cpanm -v --notest IO::Socket::SSL
            echo '[ Install Missing Alien::GMP Dependencies ]'
            S cpanm -v --notest File::Which FFI::CheckLib Path::Tiny File::chdir Capture::Tiny Alien::GMP
            echo '[ Install RPerl ]'
            S cpanm -v --notest RPerl

        elif [ $RPERL_INSTALL_CHOICE == 'd' ] || [ $RPERL_INSTALL_CHOICE == 'cpan-single' ]; then
            echo '24d. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPAN, SINGLE-USER ]]]'
            echo '[ You Should Only Use This Option 24d If local::lib Or Perlbrew Is Installed For Your User, And You Do NOT Have CPANM Installed ]'
            echo

            echo '[ Install Problematic RPerl Dependency IO::Socket::SSL ]'
            B cpan -T IO::Socket::SSL
            echo '[ Install Missing Alien::GMP Dependencies ]'
            B cpan -T --notest File::Which FFI::CheckLib Path::Tiny File::chdir Capture::Tiny Alien::GMP
            echo '[ Install RPerl ]'
            B cpan -T RPerl

        elif [ $RPERL_INSTALL_CHOICE == 'e' ] || [ $RPERL_INSTALL_CHOICE == 'cpan-system' ]; then
            echo '24e. [[[ PERL, INSTALL RPERL, LATEST STABLE VIA CPAN, SYSTEM-WIDE ]]]'
            echo '[ You Should Only Use This Option 24e If local::lib Or Perlbrew Is NOT Installed For Your User, And You Do NOT Have CPANM Installed ]'
            echo

            echo '[ Install Problematic RPerl Dependency IO::Socket::SSL ]'
            S cpan -T IO::Socket::SSL
            echo '[ Install Missing Alien::GMP Dependencies ]'
            S cpan -T --notest File::Which FFI::CheckLib Path::Tiny File::chdir Capture::Tiny Alien::GMP
            echo '[ Install RPerl ]'
            S cpan -T RPerl

        elif [ $RPERL_INSTALL_CHOICE == 'f' ] || [ $RPERL_INSTALL_CHOICE == 'github-secure-git' ]; then
            echo '24f. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, SECURE GIT ]]]'
            echo '[ If You Want To Upload Code To GitHub, Then You Must Use Secure Git Instead Of Public Git Or Public Zip ]'
            echo

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
            D $RPERL_REPO_DIR 'directory where RPerl should be downloaded (different than final RPerl installation directory)' "~/rperl-latest"
            RPERL_REPO_DIR=$USER_INPUT

            # DEV NOTE: for more info, see  https://help.github.com/articles/generating-ssh-keys
            # https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
            # https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account
            #if [ ! -f ~/.ssh/id_rsa.pub ] && [ ! -f ~/.ssh/id_dsa.pub ]; then  # OLD, DEPRECATED 3/15/2022
#            if [ ! -f ~/.ssh/id_rsa.pub ]; then  # STILL USABLE BUT REPLACED 3/15/2022, BUT MUST HAVE BEEN CREATED BEFORE 11/2/2021
            if [ ! -f ~/.ssh/id_ed25519.pub ]; then
                echo '[ Generate SSH Keys, _DO_ Create Secure Key Passphrase When Prompted ]'
                echo '[ WARNING: Be Sure To Record Your Secure Key Passphrase & Store It In A Safe Place! ]'
                C 'Please read the warning above.  Seriously.'
#                B "ssh-keygen -t rsa -C '$GITHUB_EMAIL'; eval `ssh-agent -s` ssh-add ~/.ssh/id_rsa; ssh-agent -k"  # REPLACED 3/15/2022
                B "ssh-keygen -t ed25519 -C '$GITHUB_EMAIL'; eval `ssh-agent -s` ssh-add ~/.ssh/id_ed25519; ssh-agent -k"
                echo '[ Copy & paste the output of the following command into https://github.com/settings/ssh/new or https://gitlab.com/-/user_settings/ssh_keys as needed ]'
                B "cat ~/.ssh/id_ed25519.pub"
            else
                echo '[ SSH Key File(s) Already Exist, Skipping Key Generation ]'
            fi

            if [[ "$OS_CHOICE" == "ubuntu" ]]; then
                VERIFY_UBUNTU
                echo '[ Install Keychain Key Manager For OpenSSH ]'
                S apt-get install keychain
                echo '[ Check Install, Confirm No Errors ]'
                S apt-get -f install
            # OR
            elif [[ "$OS_CHOICE" == "centos" ]]; then
                VERIFY_CENTOS 

# RPM START HERE: why doesn't the below command set work?
# RPM START HERE: why doesn't the below command set work?
# RPM START HERE: why doesn't the below command set work?

                C '[ SECURE GIT ON CENTOS: Not Currently Supported ]'
#                echo '[ Install Keychain Key Manager For OpenSSH ]'
#                S rpm --import http://mirror.ghettoforge.org/distributions/gf/RPM-GPG-KEY-gf.el7
#                S rpm -Uvh http://mirror.ghettoforge.org/distributions/gf/gf-release-latest.gf.el7.noarch.rpm 
#                S yum clean all
#                S yum install keychain
#                if [ $DEVELOPER_CHOICE == 'yes' ]; then
#                    echo '[ Check Install, Confirm No Errors; WARNING! MAY TAKE HOURS TO RUN! ]'
#                    S yum check
#                fi
            else
                C '[ SECURE GIT ON NON-UBUNTU AND NON-CENTOS: Please See Your Operating System Documentation To Install Keychain Key Manager For OpenSSH ]'
            fi

            echo '[ Enable Keychain ]'
            echo '[ NOTE: Do Not Run The Following Step If You Already Copied Your Own Pre-Existing LAMP University .bashrc File In Section 0 ]'
            B 'echo -e "\n# SSH Keys; for GitHub, etc.\nif [ -f /usr/bin/keychain ] && [ -f \$HOME/.ssh/id_rsa ]; then\n    /usr/bin/keychain \$HOME/.ssh/id_rsa\n    source \$HOME/.keychain/\$HOSTNAME-sh\nfi\n" >> ~/.bashrc;'
            SOURCE ~/.bashrc
            echo '[ How To Enable SSH Key On GitHub... ]'
            echo '[ Copy Data Produced By The Next Command ]'
            echo '[ Then Browse To https://github.com/settings/ssh ]'
            echo "[ Then Click 'Add SSH Key', Paste Copied Key Data, Title '$USERNAME@$HOSTNAME', Click 'Save' ]"
            echo
            B 'cat ~/.ssh/id_rsa.pub'
            echo
            C '[ Please Follow The Instructions Above ]'
            echo '[ Test SSH Key On GitHub, Enter Passphrase When Prompted, Confirm Automatic Reply Greeting From GitHub Server ]'
            B ssh -T git@github.com
            echo '[ Configure GitHub Account Setting On Local Machine ]'
            echo '[ NOTE: Do Not Repeat The 3 Following git config Steps If You Already Copied Your Own Pre-Existing .gitconfig File In Section 0 ]'
            B git config --global user.email "$GITHUB_EMAIL"
            B git config --global user.name "$GITHUB_FIRST_NAME $GITHUB_LAST_NAME"
            B git config --global core.editor "$EDITOR"
            echo '[ Clone (Download) RPerl Repository Onto New Machine ]'
            B git clone git@github.com:wbraswell/rperl.git $RPERL_REPO_DIR

        elif [ $RPERL_INSTALL_CHOICE == 'g' ] || [ $RPERL_INSTALL_CHOICE == 'github-public-git' ]; then
            echo '24g. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, PUBLIC GIT ]]]'
            echo '[ If You Want To Upload Code To GitHub, Then You Must Use Secure Git Instead Of Public Git Or Public Zip ]'
            echo

            D $RPERL_REPO_DIR 'directory where RPerl should be downloaded (different than final RPerl installation directory)' "~/rperl-latest"
            RPERL_REPO_DIR=$USER_INPUT

            echo '[ Clone (Download) RPerl Repository Onto New Machine ]'
            B git clone https://github.com/wbraswell/rperl.git $RPERL_REPO_DIR

        elif [ $RPERL_INSTALL_CHOICE == 'h' ] || [ $RPERL_INSTALL_CHOICE == 'github-public-zip' ]; then
            echo '24h. [[[ PERL, INSTALL RPERL, LATEST UNSTABLE VIA GITHUB, SINGLE-USER, PUBLIC ZIP ]]]'
            echo '[ If You Want To Upload Code To GitHub, Then You Must Use Secure Git Instead Of Public Git Or Public Zip ]'
            echo

            D $RPERL_REPO_DIR 'directory where RPerl should be downloaded (different than final RPerl installation directory)' "~/rperl-latest"
            RPERL_REPO_DIR=$USER_INPUT

            echo '[ Download RPerl Repository Onto New Machine ]'
            B "wget https://github.com/wbraswell/rperl/archive/master.zip; unzip master.zip; mv rperl-master $RPERL_REPO_DIR; rm master.zip"

        else
            echo "ERROR: Unrecognized value for RPERL_INSTALL_CHOICE, '${RPERL_INSTALL_CHOICE}', please see '--help' option for valid values"
        fi
 
        # avoid duplication of code for building Git options
        if [ $RPERL_INSTALL_CHOICE == 'f' ] || [ $RPERL_INSTALL_CHOICE == 'github-secure-git' ] ||
           [ $RPERL_INSTALL_CHOICE == 'g' ] || [ $RPERL_INSTALL_CHOICE == 'github-public-git' ] ||
           [ $RPERL_INSTALL_CHOICE == 'h' ] || [ $RPERL_INSTALL_CHOICE == 'github-public-zip' ]; then
            echo '[ ALL GIT OPTIONS: Install Problematic RPerl Dependency IO::Socket::SSL, Skip Tests ]'
            B cpanm -v --notest IO::Socket::SSL
            echo '[ ALL GIT OPTIONS: Install Missing Alien::GMP Dependencies ]'
            B cpanm -v --notest File::Which FFI::CheckLib Path::Tiny File::chdir Capture::Tiny Alien::GMP
            echo '[ ALL GIT OPTIONS: Install RPerl Dependencies Via CPAN ]'
            CD $RPERL_REPO_DIR
            B "perl Makefile.PL; cpanm -v --notest --installdeps ."
            echo '[ ALL GIT OPTIONS: Build RPerl ]'
            B make
            echo '[ ALL GIT OPTIONS: Test RPerl ]'
            B make test
#            echo '[ ALL GIT OPTIONS: Test RPerl, Optional Verbose Output ]'
#            B 'make test TEST_VERBOSE=1'
            echo '[ ALL GIT OPTIONS: Install RPerl ]'
            B 'make install'
        fi

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 25 VARIABLES
RPERL_VERBOSE='__EMPTY__'
RPERL_DEBUG='__EMPTY__'
RPERL_WARNINGS='__EMPTY__'
RPERL_INSTALL_DIRECTORY='__EMPTY__'

if [ $SECTION_CHOICE -le 25 ]; then
    echo '25. [[[ RPERL, RUN COMPILER TESTS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $RPERL_VERBOSE 'RPERL_VERBOSE additional user output, 0 for off, 1 for on' '1'
        export RPERL_VERBOSE=$USER_INPUT
        D $RPERL_DEBUG 'RPERL_DEBUG additional system output, 0 for off, 1 for on' '1'
        export RPERL_DEBUG=$USER_INPUT
        D $RPERL_WARNINGS 'RPERL_WARNINGS additional user & system warnings, 0 for off, 1 for on' '0'
        export RPERL_WARNINGS=$USER_INPUT
        # install directory guessing code copied from pm_location.sh, w/ addition of substr() to strip trailing '/RPerl.pm'
        RPERL_INSTALL_DIRECTORY_GUESS=`export RPERL_DEBUG=0; RPERL_VERBOSE=0; perl -e 'use RPerl; my $s = q{RPerl}; $s =~ s/::/\//g; $s .= q{.pm}; print (substr $INC{$s}, 0, -9);'`
        D $RPERL_INSTALL_DIRECTORY 'directory where RPerl is currently installed (include trailing "/lib" directory if present)' $RPERL_INSTALL_DIRECTORY_GUESS
        RPERL_INSTALL_DIRECTORY=$USER_INPUT

        echo '[ These RPerl Test Commands Must Be Executed From Within The RPerl Installation Directory ]'
        CD $RPERL_INSTALL_DIRECTORY

        echo '[ Display RPerl Command Usage, Ensure RPerl Command Is Properly Functioning ]'
        B rperl -?

        echo '[ Test Command Sequence #1, OO Inheritance Test: Clean Pre-Existing Compiled Files ]'
        B rperl -uu RPerl/Algorithm/Sort/Bubble.pm
#        B rm -Rf _Inline lib/RPerl/Algorithm.pmc lib/RPerl/Algorithm.h lib/RPerl/Algorithm.cpp lib/RPerl/Algorithm/Sort.pmc lib/RPerl/Algorithm/Sort.h lib/RPerl/Algorithm/Sort.cpp lib/RPerl/Algorithm/Sort/Bubble.pmc lib/RPerl/Algorithm/Sort/Bubble.h lib/RPerl/Algorithm/Sort/Bubble.cpp

        RPERL_CODE='use RPerl::Algorithm::Sort::Bubble; my $o = RPerl::Algorithm::Sort::Bubble->new(); $o->inherited_Bubble("logan"); $o->inherited_Sort("wolvie"); $o->inherited_Algorithm("claws");'

        echo '[ Test Command Sequence #1, OO Inheritance Test: Zero Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, PERLOPS_PERLTYPES, PERLOPS_PERLTYPES ]'
        B "perl -e '$RPERL_CODE'"
    
        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile First Of Three Files ]'
        B rperl RPerl/Algorithm.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: One Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, PERLOPS_PERLTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"
        echo '[ Test Command Sequence #1, OO Inheritance Test: Uncompile First Of Three Files ]'
        B rperl -u RPerl/Algorithm.pm

        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile Second Of Three Files ]'
        B rperl RPerl/Algorithm/Sort.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: Two Of Three Files Are Compiled, Output Should Be PERLOPS_PERLTYPES, CPPOPS_CPPTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"
        echo '[ Test Command Sequence #1, OO Inheritance Test: Uncompile Second Of Three Files ]'
        B rperl -u RPerl/Algorithm/Sort.pm

        echo '[ Test Command Sequence #1, OO Inheritance Test: Compile Third Of Three Files ]'
        B rperl RPerl/Algorithm/Sort/Bubble.pm
        echo '[ Test Command Sequence #1, OO Inheritance Test: All Three Files Are Compiled, Output Should Be CPPOPS_CPPTYPES, CPPOPS_CPPTYPES, CPPOPS_CPPTYPES ]'
        B "perl -e '$RPERL_CODE'"
        echo '[ Test Command Sequence #1, OO Inheritance Test: Uncompile Third Of Three Files ]'
        B rperl -u RPerl/Algorithm/Sort/Bubble.pm


        echo '[ Test Command Sequence #2, OO Bubble Sort Timing Test: Clean New or Pre-Existing Compiled Files ]'
        B rperl -uu RPerl/Algorithm/Sort/Bubble.pm
#        B rm -Rf _Inline lib/RPerl/Algorithm.pmc lib/RPerl/Algorithm.h lib/RPerl/Algorithm.cpp lib/RPerl/Algorithm/Sort.pmc lib/RPerl/Algorithm/Sort.h lib/RPerl/Algorithm/Sort.cpp lib/RPerl/Algorithm/Sort/Bubble.pmc lib/RPerl/Algorithm/Sort/Bubble.h lib/RPerl/Algorithm/Sort/Bubble.cpp
#        B ./script/demo/unlink_bubble.sh

        RPERL_CODE='use RPerl::Algorithm::Sort::Bubble; my $a = [reverse 0 .. 5000]; use Time::HiRes qw(time); my $start = time; my $s = RPerl::Algorithm::Sort::Bubble::integer_bubblesort($a); my $elapsed = time - $start; print Dumper($s); print "elapsed: " . $elapsed . "\n";'

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Slow Uncompiled PERLOPS_PERLTYPES Mode, 13 Seconds For 5_000 Elements ]'
        B "perl -e '$RPERL_CODE'"

# NEED FIX: re-enable CPPOS_PERLTYPES manually-compiled files, crashing w/ GCC compiler errors
# NEED FIX: re-enable CPPOS_PERLTYPES manually-compiled files, crashing w/ GCC compiler errors
# NEED FIX: re-enable CPPOS_PERLTYPES manually-compiled files, crashing w/ GCC compiler errors

#        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Fast Manually Compiled CPPOPS_PERLTYPES Mode, Link Files IF GITHUB REPO ONLY ]'
#        B ../script/demo/link_bubble_CPPOPS_PERLTYPES.sh
#        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Fast Manually Compiled CPPOPS_PERLTYPES Mode, 1.5 Seconds For 5_000 Elements ]'
#        B "perl -e '$RPERL_CODE'"

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Clean New Compiled Files ]'
        B rperl -u RPerl/Algorithm/Sort/Bubble.pm
#        B ./script/demo/unlink_bubble.sh

        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, Compile Files ]'
        B rperl RPerl/Algorithm/Sort/Bubble.pm
        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, 0.05 Seconds For 5_000 Elements ]'
        B "perl -e '$RPERL_CODE'"
        echo '[ Test Command Sequence #2, Bubble Sort Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, Uncompile Files ]'
        B rperl -u RPerl/Algorithm/Sort/Bubble.pm

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 26 VARIABLES
PHYSICSPERL_DOWNLOAD_DIRECTORY='__EMPTY__'
#PHYSICSPERL_INSTALL_DIRECTORY='__EMPTY__'
PHYSICSPERL_NBODY_STEPS='__EMPTY__'
PHYSICSPERL_ENABLE_GRAPHICS='__EMPTY__'

if [ $SECTION_CHOICE -le 26 ]; then
    echo '26. [[[ RPERL, INSTALL RPERL APPS & RUN DEMOS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $RPERL_VERBOSE 'RPERL_VERBOSE additional user output, 0 for off, 1 for on' '1'
        export RPERL_VERBOSE=$USER_INPUT
        D $RPERL_DEBUG 'RPERL_DEBUG additional system output, 0 for off, 1 for on' '1'
        export RPERL_DEBUG=$USER_INPUT
        D $RPERL_WARNINGS 'RPERL_WARNINGS additional user & system warnings, 0 for off, 1 for on' '0'
        export RPERL_WARNINGS=$USER_INPUT
        D $PHYSICSPERL_DOWNLOAD_DIRECTORY 'directory where PhysicsPerl is to be downloaded (different than final PhysicsPerl installation directory; do NOT include trailing "/lib" directory)' "~/physicsperl-latest" "~/repos_github/physicsperl-latest"
        PHYSICSPERL_DOWNLOAD_DIRECTORY=$USER_INPUT
        # NEED UPGRADE: support installation of PhysicsPerl, not just download; must be able to find & run `script/demo/n_body.pl`
#        D $PHYSICSPERL_INSTALL_DIRECTORY 'directory where PhysicsPerl is to be installed or is already installed (DO include trailing "/lib" directory if present)' "~/physicsperl-latest/lib" "~/perl5/lib/perl5" "~/repos_github/physicsperl-latest/lib"
#        PHYSICSPERL_INSTALL_DIRECTORY=$USER_INPUT
        D $PHYSICSPERL_NBODY_STEPS 'number of PhysicsPerl N-Body steps to complete (more steps is longer runtime)' '100_000'
        PHYSICSPERL_NBODY_STEPS=$USER_INPUT
        D $PHYSICSPERL_ENABLE_GRAPHICS 'enabling of PhysicsPerl graphics, 0 for off, 1 for on' '0'
        PHYSICSPERL_ENABLE_GRAPHICS=$USER_INPUT
        PHYSICSPERL_ENABLE_SSE='__EMPTY__'

        # DEV NOTE: PATH & PERL5LIB may already be set via LAMP University Run Commands .bashrc, but temporarily modify anyway just in case
        PATH=script:$PATH
        PERL5LIB=lib:$PERL5LIB

        # NEED UPDATE: add option to install PhysicsPerl via CPAN
        echo '[ Install Latest Unstable PhysicsPerl Via Public Github ]'
        B "wget https://github.com/wbraswell/physicsperl/archive/master.zip; unzip master.zip; mv physicsperl-master ${PHYSICSPERL_DOWNLOAD_DIRECTORY}; rm -rf master.zip"
        CD $PHYSICSPERL_DOWNLOAD_DIRECTORY
        echo
        echo '[ Install PhysicsPerl Dependencies Via CPAN ]'
        B cpanm -v --notest --installdeps .
#        echo '[ Build & Install PhysicsPerl ]'
#        B 'perl Makefile.PL; make; make test; make install'
#        CD $PHYSICSPERL_INSTALL_DIRECTORY

        PHYSICSPERL_ENABLE_SSE=1
        echo '[ Test Command Sequence #0a, PhysicsPerl N-Body Timing Test: Clean Pre-Existing Compiled Files ]'
        B rperl -uu lib/PhysicsPerl/Astro/SystemSSE.pm
#        B script/demo/unlink_astro.sh  # prefer functionally equivalent `rperl -u` for uniformity & professionalism
        echo '[ Test Command Sequence #0a, PhysicsPerl N-Body Timing Test: Super Slow Uncompiled PERLOPS_PERLTYPES_SSE Mode, 345 Seconds For 100K Steps & 4109 Seconds (68 Minutes) For 1M Steps Without Graphics ]'
        echo '[ NOTE: This Test Could Take SEVERAL HOURS OR DAYS To Run!!! ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

        PHYSICSPERL_ENABLE_SSE=0
        echo '[ Test Command Sequence #0b, PhysicsPerl N-Body Timing Test: Clean Pre-Existing Compiled Files ]'
        B rperl -u lib/PhysicsPerl/Astro/System.pm
        echo '[ Test Command Sequence #0b, PhysicsPerl N-Body Timing Test: Slow Uncompiled PERLOPS_PERLTYPES Mode, 20 Seconds For 100K Steps & 200 Seconds For 1M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

        PHYSICSPERL_ENABLE_SSE=0
        echo '[ Test Command Sequence #0c, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B rperl -u lib/PhysicsPerl/Astro/System.pm
        echo '[ Test Command Sequence #0c, PhysicsPerl N-Body Timing Test: Super Fast Manually Compiled CPPOPS_CPPTYPES Mode, Link Files ]'
        B script/demo/link_astro_CPPOPS_CPPTYPES.sh
        echo '[ Test Command Sequence #0c, PhysicsPerl N-Body Timing Test: Super Fast Manually Compiled CPPOPS_CPPTYPES Mode, 0.7 Seconds For 100K Steps & 7 Seconds For 1M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

        PHYSICSPERL_ENABLE_SSE=1
        echo '[ Test Command Sequence #0d, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B rperl -u lib/PhysicsPerl/Astro/SystemSSE.pm
        echo '[ Test Command Sequence #0d, PhysicsPerl N-Body Timing Test: Ultra Fast Manually Compiled CPPOPS_CPPTYPES_SSE Mode, Link Files ]'
        B script/demo/link_astro_CPPOPS_CPPTYPES_SSE.sh
        echo '[ Test Command Sequence #0d, PhysicsPerl N-Body Timing Test: Ultra Fast Manually Compiled CPPOPS_CPPTYPES_SSE Mode, 0.12 Seconds For 100K Steps & 1.2 Seconds For 1M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

        PHYSICSPERL_ENABLE_SSE=0
        echo '[ Test Command Sequence #0e, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B rperl -uu lib/PhysicsPerl/Astro/System.pm
        echo '[ Test Command Sequence #0e, PhysicsPerl N-Body Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, Compile Files ]'
        B rperl lib/PhysicsPerl/Astro/System.pm
        echo '[ Test Command Sequence #0e, PhysicsPerl N-Body Timing Test: Super Fast Automatically Compiled CPPOPS_CPPTYPES Mode, 0.7 Seconds For 100K Steps & 7 Seconds For 1M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

        PHYSICSPERL_ENABLE_SSE=1
        echo '[ Test Command Sequence #0f, PhysicsPerl N-Body Timing Test: Clean New Compiled Files ]'
        B rperl -u lib/PhysicsPerl/Astro/SystemSSE.pm
        echo '[ Test Command Sequence #0f, PhysicsPerl N-Body Timing Test: Ultra Fast Automatically Compiled CPPOPS_CPPTYPES_SSE Mode, Compile Files ]'
        B rperl lib/PhysicsPerl/Astro/SystemSSE.pm
        echo '[ Test Command Sequence #0f, PhysicsPerl N-Body Timing Test: Ultra Fast Automatically Compiled CPPOPS_CPPTYPES_SSE Mode, 0.12 Seconds for 100K Steps & 1.2 Seconds For 1M Steps Without Graphics ]'
        B script/demo/n_body.pl $PHYSICSPERL_NBODY_STEPS $PHYSICSPERL_ENABLE_GRAPHICS $PHYSICSPERL_ENABLE_SSE

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 30 ]; then
    echo '30. [[[ UBUNTU LINUX, INSTALL NFS & DBXFS ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Install dbxfs (Dropbox File System) Service, Python Dependencies ]'
        echo '[ https://thelig.ht/code/dbxfs/ ]'
        S apt-get install libpython3.12-dev python3-full python3-pip python3-venv libfuse2
        echo '[ Create Python Virtual Environment in Directory `dbxfs_env/` for `pip` Command to Function Properly ]'
        B python3 -m venv dbxfs_env
        echo '[ Create Mount Point Directory `dropbox/` ]'
        B mkdir dropbox
        echo '[ Activate Python Virtual Environment & Call `pip` to Install `dbxfs` ]'
        B source dbxfs_env/bin/activate && pip --verbose install dbxfs
        echo '[ Activate Python Virtual Environment & Run `dbxfs` to Mount into Directory `dropbox/` ]'
        B source dbxfs_env/bin/activate && dbxfs dropbox
        B ls dropbox

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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
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

if [ $SECTION_CHOICE -le 31 ]; then
    echo '31. [[[ UBUNTU LINUX, INSTALL APACHE & MOD_PERL ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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

        echo '[ SSL & https Support, Install Apache Certbot Packages ]'
        S apt-get update
        S apt-get install software-properties-common
        S add-apt-repository ppa:certbot/certbot
        S apt-get update
        S apt-get install python-certbot-apache 
        echo '[ SSL & https Support, Apache Certbot Certificates, Enable Automatic Configuration ]'
        S certbot --apache --server https://acme-v02.api.letsencrypt.org/directory
        echo '[ SSL & https Support, Apache Certbot Certificates, Test Automatic Renewal ]'
        S certbot renew --dry-run

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 32 VARIABLES
ADMIN_EMAIL='__EMPTY__'

if [ $SECTION_CHOICE -le 32 ]; then
    echo '32. [[[ APACHE, CONFIGURE DOMAIN(S) ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 33 ]; then
    echo '33. [[[ UBUNTU LINUX, INSTALL MYSQL & PHPMYADMIN ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ Do NOT configure Apache automatically ]'
        echo '[ DO     configure database with dbconfig-common ]'
        echo
        S apt-get install mysql-server mysql-client libmysqlclient-dev phpmyadmin
        echo '[ UBUNTU v16.04 OR NEWER ONLY: Install Additional PHP Package ]'
        S apt-get install php-mbstring
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 34 VARIABLES
MCRYPT_INI='__EMPTY__'
MCRYPT_SO='__EMPTY__'

if [ $SECTION_CHOICE -le 34 ]; then
    echo '34. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 35 ]; then
    echo '35. [[[ UBUNTU LINUX, INSTALL WEBMIN ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 36 ]; then
    echo '36. [[[ UBUNTU LINUX, INSTALL POSTFIX ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 37 ]; then
    echo '37. [[[ PERL, INSTALL LATEST CATALYST ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: Do NOT Mix With Non-Latest Catalyst Via apt In Section 38! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ NOTE: Installing Latest Catalyst Via CPAN May Take Over An Hour To Complete ]'
        B cpanm -v --notest Task::Catalyst Catalyst::Devel
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 38 ]; then
    echo '38. [[[ UBUNTU LINUX, INSTALL NON-LATEST CATALYST ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        echo '[ WARNING: Do NOT Mix With Latest Catalyst Via CPAN In Section 37! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install libmodule-install-perl libcatalyst-engine-apache-perl
        S service apache2 restart
        S apt-get install libcatalyst-devel-perl libcatalyst-modules-perl
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 39 ]; then
    echo '39. [[[ PERL, CHECK CATALYST VERSIONS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 40 VARIABLES
MYSQL_ROOTPASS='__EMPTY__'

if [ $SECTION_CHOICE -le 40 ]; then
    echo '40. [[[ PERL, INSTALL RAPIDAPP ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
        B cpanm -v --notest DBD::mysql MooseX::NonMoose RapidApp
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
        B 'cd ~/BlueBox-latest; perl Makefile.PL; cpanm -v --notest --installdeps .'  # DEV NOTE: no make or test here, either
        B script/bluebox_server.pl
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 41 ]; then
    echo '41. [[[ UBUNTU LINUX, INSTALL SHINYCMS DEPENDENCIES ]]]'
    echo
    VERIFY_UBUNTU
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        D $UBUNTU_RELEASE_NAME 'Ubuntu release name (trusty, xenial, bionic, focal, etc.)' 'xenial'
        UBUNTU_RELEASE_NAME=$USER_INPUT
        echo '[ WARNING: Prerequisite Dependencies Include Full LAMP Stack (Sections 0 - 11, 20, 21); mod_perl (Section 31) OR mod_fastcgi (This Section); Postfix (Section 36); And Expat, etc (This Section). ]'
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 42 ]; then
    echo  '42. [[[ PERL SHINYCMS, INSTALL SHINYCMS DEPENDENCIES & SHINYCMS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        echo '[ Ensure MySQL Configured To Support Perl Distribution DBD::mysql `make test` Command ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE USER '$USERNAME'@'localhost' IDENTIFIED BY '';"
        echo "mysql> SET PASSWORD FOR $USERNAME = '';"
        echo "mysql> GRANT ALL PRIVILEGES ON test.* TO '$USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password
        echo '[ Install ShinyCMS Dependencies Via CPAN ]'
        B cpanm -v --notest DBD::mysql Devel::Declare::MethodInstaller::Simple Text::CSV_XS inc::Module::Install Module::Install::Catalyst Test::Pod Test::Pod::Coverage
        B mkdir -p ~/public_html
        echo '[ Install MyShinyTemplate (ShinyCMS Fork) Via Github ]'
        B "wget https://github.com/wbraswell/myshinytemplate.com/archive/master.zip; unzip master.zip; mv myshinytemplate.com-master ~/public_html/$DOMAIN_NAME-latest; rm master.zip"
        B "cd ~/public_html/$DOMAIN_NAME-latest; perl Makefile.PL; cpanm -v --notest --installdeps .; cpanm -v --notest --installdeps ."
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 43 VARIABLES
DOMAIN_NAME_UNDERSCORES='__EMPTY__'
DOMAIN_NAME_NO_USER='__EMPTY__'
DOMAIN_NAME_YES_USER='__EMPTY__'
MYSQL_USERNAME='__EMPTY__'
MYSQL_USERNAME_DEFAULT='__EMPTY__'
MYSQL_PASSWORD='__EMPTY__'
SITE_NAME='__EMPTY__'
SITE_NAME_DEFAULT='__EMPTY__'
ADMIN_FIRST_NAME='__EMPTY__'
ADMIN_LAST_NAME='__EMPTY__'

if [ $SECTION_CHOICE -le 43 ]; then
    echo  '43. [[[ PERL SHINYCMS, CREATE DATABASE & EDIT MYSHINYTEMPLATE FILES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME_UNDERSCORES//-/_}  # replace hyphens with underscores
        DOMAIN_NAME_NO_USER=$DOMAIN_NAME
        DOMAIN_NAME_NO_USER+='__no_user'
        DOMAIN_NAME_YES_USER=$DOMAIN_NAME
        DOMAIN_NAME_YES_USER+='__yes_user'
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
        B "mv mysqldump__myshinytemplate.com__yes_user.sh.redacted mysqldump__$DOMAIN_NAME_YES_USER.sh.redacted"  # DO NOT ADD PASSWORD HERE
        B mkdir -p ~/bin
        B cp mysqldump__$DOMAIN_NAME_NO_USER.sh.redacted ~/bin/mysqldump__$DOMAIN_NAME_NO_USER.sh
        B cp mysqldump__$DOMAIN_NAME_YES_USER.sh.redacted ~/bin/mysqldump__$DOMAIN_NAME_YES_USER.sh
        # NEED ANSWER: should REDACTED in the regex below be wrapped in single quotes 'REDACTED' so as to avoid adding an extra pair of single quotes to the final output file???
        # NEED ANSWER: should REDACTED in the regex below be wrapped in single quotes 'REDACTED' so as to avoid adding an extra pair of single quotes to the final output file???
        # NEED ANSWER: should REDACTED in the regex below be wrapped in single quotes 'REDACTED' so as to avoid adding an extra pair of single quotes to the final output file???
        B sed -ri -e "s/REDACTED/'$MYSQL_PASSWORD'/g" ~/bin/mysqldump__$DOMAIN_NAME_NO_USER.sh  # ADD PASSWORD, USE SINGLE QUOTES IN CASE OF SPECIAL CHARACTERS
        B sed -ri -e "s/REDACTED/'$MYSQL_PASSWORD'/g" ~/bin/mysqldump__$DOMAIN_NAME_YES_USER.sh  # ADD PASSWORD, USE SINGLE QUOTES IN CASE OF SPECIAL CHARACTERS
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 44 ]; then
    echo  '44. [[[ PERL SHINYCMS, BUILD DEMO DATABASE & RUN TESTS ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 45 VARIABLES
DOMAIN_NAME_UNDERSCORES_NO_USER='__EMPTY__'
DOMAIN_NAME_UNDERSCORES_YES_USER='__EMPTY__'

if [ $SECTION_CHOICE -le 45 ]; then
    echo  '45. [[[ PERL SHINYCMS, BACKUP & RESTORE DATABASE ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_UNDERSCORES_NO_USER=$DOMAIN_NAME_UNDERSCORES
        DOMAIN_NAME_UNDERSCORES_NO_USER+='__no_user'
        DOMAIN_NAME_UNDERSCORES_YES_USER=$DOMAIN_NAME_UNDERSCORES
        DOMAIN_NAME_UNDERSCORES_YES_USER+='__yes_user'
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
        B "mysqldump --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES --lock-tables > $DOMAIN_NAME_UNDERSCORES_YES_USER.sql"

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
        B "mysql --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES < $DOMAIN_NAME_UNDERSCORES_YES_USER.sql"
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 46 ]; then
    echo  '46. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_FASTCGI ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
        B cpanm -v --notest FCGI FCGI::ProcManager
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
        
        echo '[ Start FastCGI Service, Automatic, Determine If Upstart Or SystemD Is In Use ]'
        B "ps -p1 | grep systemd && echo systemd || echo upstart"

        echo '[ Start FastCGI Service, Automatic, SystemD (Ubuntu v15.04 & Newer, CentOS, Most Modern Linux Distributions) ]'
#        S ln -s /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME.service /etc/systemd/system  # causes "Failed to execute operation: Too many levels of symbolic links"
        S systemctl enable /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME.service
        S systemctl daemon-reload
        S systemd-analyze verify /etc/systemd/system/multi-user.target.wants/fastcgi_$DOMAIN_NAME.service
        S systemctl start fastcgi_$DOMAIN_NAME.service
        S systemctl status fastcgi_$DOMAIN_NAME.service
        B "systemctl list-units | grep fastcgi"

        # OR

        echo '[ Start FastCGI Service, Automatic, Upstart (Ubuntu v14.10 & Older) ]'
        S ln -s /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME.conf /etc/init
        S initctl reload-configuration  # OR    $ reboot
        S "initctl list | grep $DOMAIN_NAME"
        S service fastcgi_$DOMAIN_NAME start
        S service fastcgi_$DOMAIN_NAME status

        # OR

        echo '[ Start FastCGI Service, Automatic, SysVinit (Older Linux Distributions) ]'
        S ln -s /home/$USERNAME/public_html/$DOMAIN_NAME-latest/modified/fastcgi_$DOMAIN_NAME-init.d /etc/init.d
        S reboot

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 47 ]; then
    echo  '47. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_PERL ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 48 ]; then
    echo  '48. [[[ PERL SHINYCMS, CREATE APACHE DIRECTORIES & ENABLE STATIC PAGE ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)" `hostname`
        DOMAIN_NAME=$USER_INPUT
        S mkdir -p /srv/www/$DOMAIN_NAME/public_html
        S mkdir /srv/www/$DOMAIN_NAME/logs
        S "echo '$DOMAIN_NAME lives!' > /srv/www/$DOMAIN_NAME/public_html/index.html"
        S a2ensite $DOMAIN_NAME
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 49 ]; then
    echo  '49. [[[ PERL SHINYCMS, CONFIGURE APACHE PERMISSIONS & ENABLE DYNAMIC PAGES ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
        S chmod g-w /home/$USERNAME/ /home/$USERNAME/.ssh /home/$USERNAME/.ssh/*
        S chmod -R o-rwx /home/$USERNAME/* /home/$USERNAME/.??*

#        echo "[ Ensure Only User $USERNAME Can Read Files Which May Contain Passwords ]"
#        B chmod -R go-rwx ~/.:100-fakexinerama ~/.bash_logout ~/bin ~/.config ~/.dbus ~/.gitconfig ~/LAMP_installer.sh ~/.local ~/perl5 ~/.viminfo ~/.Xauthority ~/.xsession-errors ~/.bash_history ~/.bashrc ~/.cache ~/.cpanm ~/.fakexinerama ~/.gkrellm2 ~/.lesshst ~/.mysql_history ~/.profile ~/.ssh ~/.vimrc ~/.xpra
        S service apache2 reload
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $SECTION_CHOICE -le 50 ]; then
    echo  '50. [[[ PERL SHINYCMS, CONFIGURE SHINY ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
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
    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#    CURRENT_SECTION_COMPLETE  # final section!
fi

if [ $SECTION_CHOICE -le 60 ]; then
    echo '60. [[[ LINUX, INSTALL MONGODB ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then

        echo '[ Install MongoDB Enterprise Edition ]'

        if [[ "$OS_CHOICE" == "ubuntu" ]]; then
            VERIFY_UBUNTU
            
            echo '[ OFFICIAL MONGODB INSTALLATION DOCS    https://docs.mongodb.com/manual/tutorial/install-mongodb-enterprise-on-ubuntu/ ]'
            echo '[ Import The Public Key Used By The Package Management System ]'
            S apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6

            echo '[ Create APT Source Entry For Downloading & Installing MongoDB ]'
            # DEV NOTE: must wrap redirect in quotes
            S "echo 'deb [ arch=amd64,arm64,ppc64el,s390x ] http://repo.mongodb.com/apt/ubuntu xenial/mongodb-enterprise/3.4 multiverse' > /etc/apt/sources.list.d/mongodb-enterprise.list"

            echo '[ Reload Local Package Database ]'
            S apt-get update
 
            echo '[ Install MongoDB Enterprise Edition, Allow aptitude To Downgrade libsnmp30 & snmpd If Necessary ]'
            S aptitude install mongodb-enterprise
                # The following packages have unmet dependencies: snmp : Depends: libsnmp30 (= 5.7.3+dfsg-1ubuntu4) but 5.7.3+dfsg-1ubuntu4.1 is installed.
#            S apt-get install mongodb-enterprise
                # The following packages have unmet dependencies: mongodb-enterprise : Depends: mongodb-enterprise-server but it is not going to be installed  (ALSO mongodb-enterprise-mongos & mongodb-enterprise-tools)

            echo '[ Start MongoDB Enterprise Service ]'
            S service mongod start

            echo '[ Verify That MongoDB Has Started Successfully By Checking The Contents Of The Log File'
            echo 'At /var/log/mongodb/mongod.log for a line (TYPICALLY THE LAST LINE) reading:'
            echo '    [initandlisten] waiting for connections on port <port>'
            echo 'Where <port> Is The Port Configured In /etc/mongod.conf, 27017 By Default ]'
            B less /var/log/mongodb/mongod.log

            echo '[ Optional, Stop MongoDB Enterprise Service ]'
            S service mongod stop
        # OR
        elif [[ "$OS_CHOICE" == "centos" ]]; then
            VERIFY_CENTOS

            echo '[ OFFICIAL MONGODB INSTALLATION DOCS    https://docs.mongodb.com/manual/tutorial/install-mongodb-enterprise-on-red-hat/ ]'
            echo '[ Create YUM Repo Entry For Downloading & Installing MongoDB ]'
            # DEV NOTE: must wrap redirect in quotes
            S 'printf "[mongodb-enterprise]\nname=MongoDB Enterprise Repository\nbaseurl=https://repo.mongodb.com/yum/redhat/\$releasever/mongodb-enterprise/3.6/\$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=https://www.mongodb.org/static/pgp/server-3.6.asc" > /etc/yum.repos.d/mongodb-enterprise.repo'

            echo '[ Install MongoDB Enterprise Edition ]'
            S yum install -y mongodb-enterprise

            echo '[ Pre-Configure MongoDB Enterprise Edition, Disable SELinux OR SEE OTHER INFO IN OFFICIAL MONGODB INSTALLATION DOCS ]'
            echo 'SELINUX=disabled' >> /etc/selinux/config 

            echo '[ Start MongoDB Enterprise Service ]'
            S service mongod start

            echo '[ Verify That MongoDB Has Started Successfully By Checking The Contents Of The Log File'
            echo 'At /var/log/mongodb/mongod.log for a line (TYPICALLY THE LAST LINE) reading:'
            echo '    [initandlisten] waiting for connections on port <port>'
            echo 'Where <port> Is The Port Configured In /etc/mongod.conf, 27017 By Default ]'
            B less /var/log/mongodb/mongod.log

            echo '[ Optional, Stop MongoDB Enterprise Service ]'
            S service mongod stop
        fi
        clear

    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#   CURRENT_SECTION_COMPLETE  # NEED UN-COMMENT WHEN THIS IS NO LONGER THE FINAL SECTION
fi









# docker install
S apt-get install apt-transport-https ca-certificates curl gnupg-agent software-properties-common
B "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"

S apt-key fingerprint 0EBFCD88

echo 'pub   4096R/0EBFCD88 2017-02-22'
echo '      Key fingerprint = 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88'
echo 'uid                  Docker Release (CE deb) <docker@docker.com>'
echo 'sub   4096R/F273FCD8 2017-02-22'

S add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
S apt-get update
S apt-get install docker-ce docker-ce-cli containerd.io

# prefer new version via curl
#S apt-get install docker-compose
# OR
echo '[ DIRECTIONS: find latest release version at https://github.com/docker/compose/releases ]'
C "Please follow the directions above..."
D $DOCKER_COMPOSE_VERSION "Latest stable Docker Compose version" '1.27.4'
DOCKER_COMPOSE_VERSION=$USER_INPUT
S curl -L https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
S chmod a+x /usr/local/bin/docker-compose
B which docker-compose
B docker-compose -v

# docker commands, test
S docker run hello-world
S docker run -it ubuntu bash

# docker commands, general
S docker info
S docker image ls --all

# docker commands, delete
S docker rmi BAD_IMAGE_TAG
S docker image rm BAD_IMAGE_ID
S docker system prune

# docker commands, publish
S docker tag OLD_IMAGE_TAG NEW_IMAGE_TAG
S docker push USERNAME/REPOSITORY:TAG


# docker commands, build RPerl
S docker build -t=wbraswell/rperl_github:2019xxxx . > docker_build.out 2>&1
S docker run  -it wbraswell/rperl_github:2019xxxx
S docker tag      wbraswell/rperl_github:2019xxxx wbraswell/rperl_github
S docker push     wbraswell/rperl_github
S docker run  -it wbraswell/rperl_github




# websocket server
B cpanm -v Net::Async::WebSocket::Server
B ./websocket_test_server.pl

# websocket client
# DEV NOTE: do not use Node.js from apt-get repos, broken & out-of-date due to node vs nodejs package naming
#sudo apt-get install node-ws
#sudo apt-get install npm
B netstat -an | grep 3000  # check if server is running
B curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.34.0/install.sh | bash
B source ~/.bashrc
B set | grep NVM
B nvm i 10
B npm i -g wscat2

S apt-get install runit  # NEED REMOVE HACK: chpst

B wscat -b -r ws://localhost:3000








# SECTION 70 VARIABLES
LOCAL_HOSTNAME='__EMPTY__'

if [ $SECTION_CHOICE -le 70 ]; then
    echo  '70. [[[ PERL CLOUDFORFREE, INSTALL ]]]'
    echo
    if [ $MACHINE_CHOICE == '0' ] || [ $MACHINE_CHOICE == 'new' ]; then
        D $USERNAME "new machine's username" `whoami`
        USERNAME=$USER_INPUT

        P $LOCAL_HOSTNAME "Existing Machine's Local Hostname"
        LOCAL_HOSTNAME=$USER_INPUT

echo '[ MUST COMPLETE SECTION 32 FOR cloudforfree.org DOMAIN BEFORE RUNNING THIS SECTION 70!!! ]'

# [[[ PERL CLOUDFORFREE, PREREQUISITES ]]]

echo '[ apache2-dev Package Contains /urs/bin/apxs Required By Apache2::Request & Apache2::Upload via libapreq2 via Apache2::FileManager ]'
S apt-get install aptitude
S aptitude install apache2-dev
    # accept solution w/ downgrades only
echo '[ libapache2-mod-perl2-dev Package Contains /usr/include/apache2/modperl_perl_unembed.h Required By Apache2::Request & Apache2::Upload via libapreq2 via Apache2::FileManager ]'
S apt-get install libapache2-mod-perl2-dev

# `unbuffer` required by cloudforfree.org Code.pm
# Ubuntu v14.04
S vi /etc/apt/sources.list
    deb http://archive.ubuntu.com/ubuntu trusty-updates main universe
S apt-get update
S apt-get install expect-dev
# OR
# Ubuntu v16.04
S apt-get install expect

# must have system-wide install of `cpanm` for call to `S cpanm -v --notest Apache2::FileManager` below
S apt-get install cpanminus

# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, PREREQUISITES ]]]

S apt-get install libapreq2-3
S a2enmod apreq2

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


# [[[ PERL CLOUDFORFREE, PREREQUISITES, Apache2::FileManager ]]]

# NEED UPDATE, CORRELATION #cff05: replace GitHub code w/ Apache2::FileManager v0.3 from CPAN, as soon as it has been created
B git clone https://github.com/wbraswell/apache2-filemanager.git ~/github_repos/apache2-filemanager-latest

# DISABLED: do not use CPAN v0.21 due to bugs
##S cpanm -v --notest Apache2::Request  # unnecessary, dependency of A2::FM below
#S cpanm -v --notest Apache2::FileManager
## installs in /usr/local/lib/x86_64-linux-gnu/perl/5.22.1 among other places?
##             /usr/local/share/perl/5.22.1/Apache2/FileManager.pm

## 2 CRITICAL BUGS: Apache2::FileManager
## Can't locate Apache/FileManager.pm in @INC
#echo "[ Replace 1 Occurrence Of 'use Apache::FileManager;' With 'use Apache2::FileManager;' ]"
#S $EDITOR ~/.cpanm/work/*/Apache2-FileManager-0.21/test.pl

## Can't load '/usr/local/lib/x86_64-linux-gnu/perl/5.22.1/auto/APR/Request/Apache2/Apache2.so' for module APR::Request::Apache2: 
## /usr/local/lib/x86_64-linux-gnu/perl/5.22.1/auto/APR/Request/Apache2/Apache2.so: undefined symbol: apreq_handle_apache2 at
## /usr/lib/x86_64-linux-gnu/perl/5.22/DynaLoader.pm line 187.
#echo "[ Replace 2 Occurrences Of 'PERL_DL_NONLAZY=1' With 'PERL_DL_NONLAZY=0' ]"
#S $EDITOR ~/.cpanm/latest-build/Apache2-FileManager-0.21/Makefile
#S cd ~/.cpanm/latest-build/Apache2-FileManager-0.21/ && make && make test && make install


# [[[ PERL CLOUDFORFREE, PREREQUISITES, Plack::Middleware::DoormanAuth0 ]]]

echo '[ Install CloudForFree.org CPAN Dependency, Doorman for Auth0 ]'
B cpanm -v --notest Plack::Middleware::DoormanAuth0
echo '[ Install CloudForFree.org CPAN Dependency, Doorman for Auth0, Fix Incorrect $VERSION From "0.01" To "0.10" ]'
B $EDITOR ./lib/perl5/Plack/Middleware/DoormanAuth0.pm


# [[[ PERL CLOUDFORFREE, PREREQUISITES, REMAINING CPAN DISTRIBUTIONS ]]]

echo '[ Download CloudForFree.org Source Code ]'
B git clone https://github.com/wbraswell/cloudforfree.org.git ~/github_repos/cloudforfree.org-latest
echo '[ Install CloudForFree.org CPAN Dependencies ]'
B cd ~/github_repos/cloudforfree.org-latest && perl Makefile.PL && cpanm -v --notest --installdeps .


# [[[ PERL CLOUDFORFREE, APACHE CONFIG, Apache2::FileManager ]]]

B mkdir -p ~/public_html
B ln -s ~/github_repos/cloudforfree.org-latest/ ~/public_html/cloudforfree.org-latest

S ln -s /home/wbraswell/public_html/cloudforfree.org-latest/modified/user_files /srv/www/$LOCAL_HOSTNAME/public_html/user_files

# NEED ANSWER: is this for testing Apache2::FileManager only???
# SECURITY THREAT!  all possibly-private github repos (and maybe other sensitive files) can be publicy read w/ this config!!!
S vi /etc/apache2/sites-enabled/$LOCAL_HOSTNAME.conf
#...
#    DocumentRoot /home/wbraswell/public_html/cloudforfree.org-latest/root
#...
#    <Location /FileManager>
#        SetHandler           perl-script
#        PerlHandler          Apache2::FileManager
#        PerlSetVar           DOCUMENT_ROOT /home/wbraswell/public_html/cloudforfree.org-latest/root/user_files
#    </Location>

S service apache2 restart
echo '[ Browse To http://$LOCAL_HOSTNAME/FileManager ]'

S chgrp www-data /home/wbraswell/
S chmod g+rX /home/wbraswell/
S chmod g-w /home/$USERNAME/ /home/$USERNAME/.ssh /home/$USERNAME/.ssh/*


# [[[ PERL CLOUDFORFREE, PLACK STARMAN TEST, Shiny & Apache2::FileManager ]]]

echo '[ Test Apache2::FileManager via Plack `plackup` Server ]'
B plackup --port 3000 app.psgi

echo '[ Test ShinyCMS via Starman Plack Server ]'
B cpanm -v --notest Starman
B ./script/shinycms_server.pl -p 80 -r
B ./script/shinycms_server.pl -p 80 --fork


# [[[ PERL CLOUDFORFREE, PREREQUISITES, ACE EDITOR & SYNTAX HIGHLIGHTER ]]]
# MOVED TO ARCHIVE NOTES, ACE CODE ALREADY PRESENT AT /cloudforfree.org-latest/modified/ace_edit/

# [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, COMPILE PERL & MODPERL ]]]
# MOVED TO ARCHIVE NOTES, FASTCGI USED INSTEAD OF MODPERL

# MOVED TO ARCHIVE NOTES:  [[[ PERL CLOUDFORFREE, PREREQUISITES, APACHE2::FILEMANAGER, DEBUG MODPERL SEGFAULT ]]]
# MOVED TO ARCHIVE NOTES, MODPERL HAS UNFIXED BUG


# [[[ PERL CLOUDFORFREE, RESTORE DATABASE & CONFIG FILE ]]]

echo '[ Restore Database, Create Empty Database To Receive Restoration ]'
echo '[ Copy Commands From The Following Lines ]'
echo "mysql> CREATE DATABASE cloudforfree_org;"
echo "mysql> CREATE USER 'cloudff_user'@'localhost' IDENTIFIED BY 'NEED_PASSWORD';"
echo "mysql> GRANT ALL PRIVILEGES ON cloudforfree_org.* TO 'cloudff_user'@'localhost';"
echo "mysql> QUIT"
echo
B mysql --user=root --password

echo '[ Restore Database, DO Include ShinyCMS User & Password Data, Import Raw sql File ]'
B "mysql --user=cloudff_user --password='NEED_PASSWORD' cloudforfree_org < wbraswell_20170315-cloudforfree_org.sql"

B cp shinycms.conf.redacted shinycms.conf
B $EDITOR shinycms.conf
    # password   REDACTED


# [[[ PERL CLOUDFORFREE, RESTORE USER FILES ]]]

B cp -a ~/github_repos/rperl-latest/lib/RPerl/Learning ~/github_repos/cloudforfree.org-latest/root/user_files/wbraswell/LearningRPerl

# DEV NOTE, CORRELATION #cff01: screen logfile max path length is 70, must use OS symlink to shorten path
S ln -s /home/wbraswell/github_repos/cloudforfree.org-latest/root/user_jobs /srv/cloudff_user_jobs

B mkdir -p ~/github_repos/cloudforfree.org-latest/modified/user_jobs/wbraswell

# restore all profile pics from backup
B mkdir -p ~/github_repos/cloudforfree.org-latest/modified/cms-uploads/user-profile-pics/
B tar -xzvf FOO.tar.gz
B ...

# restore one profile pic at a time
B mkdir -p ~/github_repos/cloudforfree.org-latest/modified/cms-uploads/user-profile-pics/wbraswell
wget -O ~/github_repos/cloudforfree.org-latest/modified/cms-uploads/user-profile-pics/wbraswell/wbraswell_profile_github.jpg https://avatars0.githubusercontent.com/u/1772630?s=460&v=4


# [[[ PERL CLOUDFORFREE, CONFIGURE APACHE PORT 80 FORWARDING FOR PLACK PORT 800 ]]]

# PORT FORWARDING, allow Plack/Starman via script/shinycms_server.pl when Apache is also running on the same OS
S a2enmod proxy
S a2enmod proxy_http
echo "<VirtualHost *:80>"
echo "    ServerName cloudforfree.org"
echo "    ServerAlias www.cloudforfree.org"
echo "    ServerAdmin william.braswell@NOSPAM.autoparallel.com"
echo "    DocumentRoot /srv/www/cloudforfree.org/public_html/"
echo "    ErrorLog /srv/www/cloudforfree.org/logs/error.log"
echo "    CustomLog /srv/www/cloudforfree.org/logs/custom.log common"
echo "    ProxyPreserveHost On"
echo "    ProxyPass / http://0:800/"
echo "    ProxyPassReverse / http://0:800/"
echo "</VirtualHost>"
S vi /etc/apache2/sites-available/cloudforfree.org.conf
S service apache2 restart



# [[[ PERL CLOUDFORFREE, RUN PLACK SERVER MANUALLY, DO NOT MIX WITH APACHE2 FASTCGI BELOW ]]]

B cpanm -v --notest Starman

# === BEGIN CURRENT STEPS ===
screen -S cloudforfree_plack;
screen -R cloudforfree_plack;
sudo -i;
source /home/wbraswell/.bashrc; 
export PATH=/home/wbraswell/github_repos/rperl-latest/script/:$PATH; 
# NEED UPDATE: replace github code w/ CPAN v0.3 as soon as it has been created
export PERL5LIB=/home/wbraswell/github_repos/apache2-filemanager-latest/lib/:/home/wbraswell/github_repos/rperl-latest/lib/:/home/wbraswell/perl5:/home/wbraswell/perl5/lib/perl5:$PERL5LIB; 
# DISABLED: do not use CPAN v0.21 due to bugs
#export PERL5LIB=/home/wbraswell/github_repos/rperl-latest/lib/:/home/wbraswell/perl5:/home/wbraswell/perl5/lib/perl5:$PERL5LIB; 
set | grep PERL
cd /home/wbraswell/github_repos/cloudforfree.org-latest/;
./script/shinycms_server.pl -p 800 --fork
# === END CURRENT STEPS ===
 

# [[[ PERL CLOUDFORFREE, RUN APACHE2 FASTCGI, DO NOT MIX WITH PLACK SERVER ABOVE ]]]

S ~/github_repos/cloudforfree.org-latest/modified/fastcgi_start__cloudforfree.org.sh

echo "Listen 800"
echo "<VirtualHost *:800>"
echo "    ..."
echo "</VirtualHost>"
S $EDITOR /etc/apache2/sites-available/phpmyadmin.cloud-web2.autoparallel.com.conf
S a2dissite cloud-web2.autoparallel.com
S service apache2 reload







    elif [ $MACHINE_CHOICE == '1' ] || [ $MACHINE_CHOICE == 'existing' ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#    CURRENT_SECTION_COMPLETE  # final section!
fi


# CODE PAST THIS POINT IS A WORK IN PROGRESS
# CODE PAST THIS POINT IS A WORK IN PROGRESS
# CODE PAST THIS POINT IS A WORK IN PROGRESS


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


# [[[ SCIKIT-LEARN ]]]
# apt-get install python3 python3-pip python3-matplotlib
# pip3 install -U scikit-learn


# [[[ DELL LATITUDE LAPTOP, CPU THROTTLE ]]]

# ignore BIOS CPU throttling directive
S vi /etc/default/grub
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash processor.ignore_ppc=1"
S update-grub
S reboot

# show CPU scaling frequency info 
S turbostat
S dmidecode
B cpufreq-info

# [[[ DELL LATITUDE LAPTOP, FAN CONTROL ]]]

# build SMM register program, disable/enable BIOS fan control
# SOLUTION A: WORKS FOR 3 SECONDS
S apt-get install g++-multilib
S apt-get build-dep i8kutils
S apt-get source i8kutils
CD i8kutils-1.41/
S gcc -g -O2 -Wall -I. -o smm -m32 smm.c
S ./smm 30a3  # DISABLE BIOS FAN CONTROL
S ./smm 31a3  #  ENABLE BIOS FAN CONTROL

# install i8kutils, set fan speeds
# SOLUTION A: WORKS FOR 3 SECONDS
S apt-get install i8kutils
S i8kctl fan - 2  # set right fan (only fan in Dell Latitude D630) to high speed
S i8kfan  # check fan speeds


# reload old i8k module in unrestricted mode
# DOES NOT WORK???
S rmmod dell-smm-hwmon
S modprobe dell-smm-hwmon restricted=0

# build dell-bios-fan-control program
# DOES NOT WORK???  uses 34a3 and 35a3 SMM values instead of 30a3 and 31a3 as w/ SMM register program below
B git clone https://github.com/TomFreudenberg/dell-bios-fan-control.git dell-bios-fan-control-latest
CD dell-bios-fan-control-latest
B make
S ./dell-bios-fan-control 0


echo
echo '[[[ ALL DONE!!! ]]]'
echo
