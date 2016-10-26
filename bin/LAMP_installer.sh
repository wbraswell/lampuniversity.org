#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.24.0.
# LAMP Installer Script v0.052_000

# enable extended pattern matching in case statements
shopt -s extglob

# global variables
USER_INPUT=''
CURRENT_SECTION=0

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

CD () {  # _C_hange _D_irectory with error check
    echo '$ cd' $1
    while true; do
        read -p 'Run above command, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
            n|N ) echo; echo; return;;
            y|Y ) echo; break;;
            '' ) break;;
            * ) echo;;
        esac
    done

    if [ -d "$1" ]; then
        cd $1
    else
        echo 'Cannot change directory to ' $1 ' because such directory does not exist'
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
            [abcdefghijklmnopqrstuvwxyz/]+([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./]) ) echo; break;;
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

echo  '    [[[<<< LAMP Installer Script >>>]]]'
echo
echo '  [[[<<< Tested Using Fresh Installs >>>]]]'
echo
echo ' Ubuntu v14.04   (Trusty Tahr) in Virtual Box'
echo ' Ubuntu v14.04.1 (Trusty Tahr) on CloudAtCost.com'
echo 'Xubuntu v14.04.2 (Trusty Tahr)'
echo 'Xubuntu v16.04.1 (Xenial Xerus)'
echo
echo  '          [[[<<< Main Menu >>>]]]'
echo
echo  '        <<< LOCAL CLI SECTIONS >>>'
echo \ '0. [[[        LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
echo \ '1. [[[        LINUX, CONFIGURE CLOUD NETWORKING ]]]'
echo \ '2. [[[ UBUNTU LINUX, USB INSTALL, FIX BROKEN SWAP DEVICE ]]]'
echo \ '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
echo \ '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
echo \ '5. [[[ UBUNTU LINUX, UPGRADE ALL OPERATING SYSTEM PACKAGES ]]]'
echo \ '6. [[[ UBUNTU LINUX, INSTALL BASE CLI OPERATING SYSTEM PACKAGES ]]]'
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
echo  '16. [[[ UBUNTU LINUX, UNINSTALL OR RECONFIGURE GVFS ]]]'
echo  '17. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER ]]]'
echo  '18. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
echo  '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
echo
echo  '         <<< SERVICE SECTIONS >>>'
echo  '20. [[[ UBUNTU LINUX,   INSTALL NFS ]]]'
echo  '21. [[[ UBUNTU LINUX,   INSTALL APACHE & MOD_PERL ]]]'
echo  '22. [[[ APACHE,         CONFIGURE DOMAIN(S) ]]]'
echo  '23. [[[ UBUNTU LINUX,   INSTALL MYSQL & PHPMYADMIN ]]]'
echo  '24. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
echo  '25. [[[ UBUNTU LINUX,   INSTALL WEBMIN ]]]'
echo  '26. [[[ UBUNTU LINUX,   INSTALL POSTFIX ]]]'
echo  '27. [[[ UBUNTU LINUX,   INSTALL PERL LOCAL::LIB  & CPANM ]]]'
echo  '28. [[[ UBUNTU LINUX,   INSTALL PERLBREW         & CPANM ]]]'
echo  '29. [[[ UBUNTU LINUX,   INSTALL PERL FROM SOURCE & CPANM ]]]'
echo  '30. [[[ PERL,           INSTALL     LATEST CATALYST ]]]'
echo  '31. [[[ UBUNTU LINUX,   INSTALL NON-LATEST CATALYST ]]]'
echo  '32. [[[ PERL,           CHECK CATALYST VERSIONS ]]]'
echo  '33. [[[ PERL,           INSTALL RAPIDAPP ]]]'
echo  '34. [[[ UBUNTU LINUX,   INSTALL SHINYCMS DEPENDENCIES ]]]'
echo  '35. [[[ PERL SHINYCMS,  INSTALL SHINYCMS DEPENDENCIES & SHINYCMS ]]]'
echo  '36. [[[ PERL SHINYCMS,  CREATE DATABASE & EDIT MYSHINYTEMPLATE FILES ]]]'
echo  '37. [[[ PERL SHINYCMS,  BUILD DEMO DATA & RUN TESTS ]]]'
echo  '38. [[[ PERL SHINYCMS,  BACKUP & RESTORE DATABASE ]]]'
echo  '39. [[[ PERL SHINYCMS,  CONFIGURE APACHE MOD_FASTCGI ]]]'
echo  '40. [[[ PERL SHINYCMS,  CONFIGURE APACHE MOD_PERL ]]]'
echo  '41. [[[ PERL SHINYCMS,  CREATE APACHE DIRECTORIES ]]]'
echo  '42. [[[ PERL SHINYCMS,  CONFIGURE APACHE PERMISSIONS ]]]'
echo  '43. [[[ PERL SHINYCMS,  CONFIGURE SHINY ]]]'
echo

while true; do
    read -p 'Please type your chosen main menu section number, or press <ENTER> for 0... ' MENU_CHOICE
    case $MENU_CHOICE in
        [0123456789]|[123][0123456789]|4[0123] ) echo; break;;
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
        echo "[ Manually Add $USERNAME To User Group sudo, Allows Running root Commands (Like update-manager) Via sudo In xpra ]"
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        S $EDITOR /etc/group
        echo '[ Take Note Of IP Address For Use On Existing Machine ]'
        B ifconfig
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo '1. [[[ EXISTING MACHINE; CLIENT; LOCAL USER SYSTEM ]]]'
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        P $USERNAME "new machine's username"
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
        echo '# === COMMENT OR REMOVE LOCAL HOSTNAME IF APPEARING BELOW ==='
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
        echo '[ Reboot, Then Check /etc/resolv.conf File To Confirm The Following Lines Have Been Appended ]'
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
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Generate & Reconfigure Locales To Fix "perl: warning: Setting locale failed." ]'
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
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: THIS SECTION IS EXPERIMENTAL!  This should NOT be done if you are not sure about what you are doing!!! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install ubuntu-sdk
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 5 ]; then
    echo '5. [[[ UBUNTU LINUX, UPGRADE ALL OPERATING SYSTEM PACKAGES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: THIS SECTION IS EXPERIMENTAL!  This should NOT be done if you are not sure about what you are doing!!! ]'
        C 'Please read the warning above.  Seriously.'
        # NEED FIX: gvim AKA vim-gtk3 Has Unmet Dependencies After `apt-get upgrade` In Ubuntu 16.04.1 Xenial
        # https://bugs.launchpad.net/ubuntu/+source/vim/+bug/1613949
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
    echo '6. [[[ UBUNTU LINUX, INSTALL BASE CLI OPERATING SYSTEM PACKAGES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get update
        S apt-get -f install
        echo '[ General Tools: g++ ssh perl-doc vim linuxlogo lynx screen ]'
        echo '[ LAMP University Tools Requirements: zip unzip ]'
        echo '[ RPerl Requirements: git curl astyle ]'
        S apt-get install g++ ssh zip unzip perl-doc vim linuxlogo git curl astyle lynx screen
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get -f install
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 7 ]; then
    echo '7. [[[ UBUNTU LINUX, INSTALL & TEST CLAMAV ANTI-VIRUS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ NOTE: ClamAV should be skipped on low-memory systems. ]'
        C 'Please read the note above.'
        S apt-get install clamav clamav-daemon 
        S freshclam
        S clamscan -r /home
        P $USERNAME "new machine's username"
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
    echo '8. [[[        LINUX, INSTALL LAMP UNIVERSITY TOOLS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        B wget https://github.com/wbraswell/lampuniversity.org/archive/master.zip
        B mv master.zip lampuniversity.org-master.zip
        B unzip lampuniversity.org-master.zip
        B mkdir ~/bin
        B cp lampuniversity.org-master/bin/* ~/bin
        B rm -Rf lampuniversity.org*
        C 'Please Log Out And Log Back In, Which Should Reset The $PATH Environmental Variable To Include The Newly-Created /home/bin Directory, Then Come Back To This Point.'
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
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: This section is only for affected machines such as Dell Latitude D430 & D630. ]'
        echo '[ Symptoms include no working wireless support, and the inability to shut down or reboot or suspend. ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get remove bcmwl-kernel-source dkms
        S apt-get install firmware-b43-installer
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

if [ $MENU_CHOICE -le 12 ]; then
    echo '12. [[[ UBUNTU LINUX, INSTALL BASE GUI OPERATING SYSTEM PACKAGES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Check Install, Confirm No Errors ]'
        S apt-get update
        S apt-get -f install
        echo '[ X-Windows Installation Triggers: xterm xfce4-terminal ]'
        echo '[ Basic X-Windows Testing: x11-apps (contains xeyes) ]'
        echo '[ General Tools: gkrellm hexchat firefox chromium-browser update-manager indicator-multiload unetbootin ]'
        S apt-get install xterm xfce4-terminal x11-apps gkrellm hexchat firefox chromium-browser update-manager indicator-multiload unetbootin
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
    if [ $MACHINE_CHOICE -eq 0 ]; then
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine First..."
        echo '[ Test X-Windows Single-Session Connection ]'
        P $LOCAL_HOSTNAME "Existing Machine's Local Hostname"
        LOCAL_HOSTNAME=$USER_INPUT
        B "export DISPLAY=$LOCAL_HOSTNAME:0.0; xeyes"
        echo '[ Install & Start xpra Multi-Session Service ]'
        S apt-get install xpra
        B 'xpra start :100 --start-child=xfce4-terminal; xeyes'
        echo '[ Default Enable xpra Multi-Session Connection ]'
        B 'echo "export DISPLAY=:100.0" >> ~/.bashrc'
        echo '[ Test xpra Multi-Session Connection ]'
        B '. ~/.bashrc; xeyes'
        echo '[ Optionally Stop xpra Service ]'
        B xpra stop
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        C "Please configure your local firewall to open TCP port 6000..."
        echo '[ Determine Display Manager, Either gdm OR lightdm ]'
        B 'ps aux | grep gdm'
        B 'ps aux | grep lightdm'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ WARNING: This sub-section is only for machines running the gdm display manager, NOT for those running lightdm! ]'
        C 'Please read the warning above.  Seriously.'
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

        echo '[ WARNING: This sub-section is only for machines running the lightdm display manager, NOT for those running gdm! ]'
        C 'Please read the warning above.  Seriously.'
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

        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT

        echo '[ Enable X-Windows Single-Session Connection ]'
        B "xhost +$DOMAIN_NAME"
        echo '[ Install xpra Multi-Session Service ]'
        S apt-get install xpra
        echo '[ NOTE: If you experienced issues installing xpra via apt-get above, then you may have an old machine. ]'
        echo '[ If this is the case, then complete the URL below, download the proper .deb file, and run the gdebi-gtk command to install the .deb file. ]'
        echo 'http://xpra.org/dists/USERDIST/main/USERARCH'
        echo '$ gdebi-gtk ./xpra_SOMEVERSION_USERARCH.deb'
        echo
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now... Then Come Back To This Point."
        echo '[ Test xpra Multi-Session Connection ]'
        B "xpra attach ssh:$DOMAIN_NAME:100"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 15 VARIABLES
ISO_MOUNT_POINT='__EMPTY__'

if [ $MENU_CHOICE -le 15 ]; then
    echo '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
    echo
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
    echo '16. [[[ UBUNTU LINUX, UNINSTALL OR RECONFIGURE GVFS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Uninstall Or Disable GVFS To Speed Up Thunar File Explorer ]'
        echo '[ OPTION 1: Uninstall GVFS Completely ]'
        S apt-get remove gvfs-daemons
        echo '[ OPTION 2: Disable GVFS Network Mounting ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ Manually Edit GVFS Config File, Copy Config Entry From The Following Line ]'
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

if [ $MENU_CHOICE -le 19 ]; then
    echo '19. [[[ UBUNTU LINUX, ENABLE AUTOMATIC SECURITY UPDATES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo 'Follow the directions below.'
        echo
        echo 'enable security & recommended updates only'
        echo 'check for updates daily'
        echo 'install security updates only'
        echo 'never remind of dist upgrade'
        echo 'enable Ubuntu repositories only, disable restricted & multiverse'  # NEED ANSWER: why disable security updates from restricted & multiverse repos?
        echo
        B update-manager
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 20 ]; then
    echo '20. [[[ UBUNTU LINUX, INSTALL NFS ]]]'
    echo
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
        echo '[ Test NFS Service, Part 1, Start With "hello" ]'
        S "echo 'hello world' > /nfs_exported/hello.txt"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now... Then Come Back To This Point."
        echo '[ Test NFS Service, Part 2, Check For "howdy" ]'
        S cat /nfs_exported/howdy.txt
        S rm /nfs_exported/howdy.txt
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        echo '[ Install NFS Client (Via Service Package) ]'
        S apt-get install nfs-kernel-server nfs-common
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        echo '[ Create NFS Import Directory & Mount NFS Share ]'
        S mkdir -p /nfs_imported/$DOMAIN_NAME
        S chmod a+rwX /nfs_imported/$DOMAIN_NAME
        S mount $DOMAIN_NAME:/nfs_exported /nfs_imported/$DOMAIN_NAME  # manual test
        echo '[ Manually Edit NFS Service Import Config File /etc/fstab ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ Copy NFS Import Entry From The Following Line ]'
        echo "$DOMAIN_NAME:/nfs_exported /nfs_imported/$DOMAIN_NAME nfs rsize=8192,wsize=8192,timeo=14,intr"
        echo
        S $EDITOR /etc/fstab
        echo '[ Test NFS Service, Part 1, Update "howdy" ]'
        S "echo \"howdy y'all\" > /nfs_imported/$DOMAIN_NAME/howdy.txt"
        echo '[ Test NFS Service, Part 2, Check "hello" ]'
        S cat /nfs_imported/$DOMAIN_NAME/hello.txt
        S rm /nfs_imported/$DOMAIN_NAME/hello.txt
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 21 ]; then
    echo '21. [[[ UBUNTU LINUX, INSTALL APACHE & MOD_PERL ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        S apt-get install apache2 libapache2-mod-perl2

        echo '[ Manually Edit Operating System User Group Config File /etc/group, Add New Username To www-data Group ]'
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        echo '[ Example Data Format On The Following Line, Group Number 33 May Differ In Your /etc/group, Use Your Group Number Instead Of 33 ]'
        echo "www-data:x:33:$USERNAME"
        echo
        S $EDITOR /etc/group

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

if [ $MENU_CHOICE -le 22 ]; then
    echo '22. [[[ APACHE, CONFIGURE DOMAIN(S) ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
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
        echo "    ServerAdmin webmaster@$DOMAIN_NAME"
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
        echo '[ Change DOMAIN_NAME_ONLY To bar.com Portion Of foo.bar.com Subdomain ]'
        echo
        echo "<VirtualHost *:80>"
        echo "    ServerName $DOMAIN_NAME"
        echo "    # DISABLE FOLLOWING LINE If Also Enabling phpmyadmin.$DOMAIN_NAME"
        echo "    ServerAlias $DOMAIN_NAME *.DOMAIN_NAME_ONLY"
        echo "    ServerAdmin webmaster@$DOMAIN_NAME"
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
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 23 ]; then
    echo '23. [[[ UBUNTU LINUX, INSTALL MYSQL & PHPMYADMIN ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ Do NOT configure Apache automatically ]'
        echo '[ DO     configure database with dbconfig-common ]'
        echo
        S apt-get install mysql-server mysql-client libmysqlclient-dev phpmyadmin
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 24 VARIABLES
MCRYPT_INI='__EMPTY__'
MCRYPT_SO='__EMPTY__'

if [ $MENU_CHOICE -le 24 ]; then
    echo '24. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT

        echo '[ Ensure MySQL Setting have_innodb Is Set To YES ]'
        echo '[ Copy Command From The Following Line, Check Return Value As Shown Below ]'
        echo
        echo "mysql> SHOW VARIABLES LIKE 'have_innodb';"
        echo "+---------------+-------+"
        echo "| Variable_name | Value |"
        echo "+---------------+-------+"
        echo "| have_innodb   | YES   |"
        echo "+---------------+-------+"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password

        echo "[ Manually Edit Apache Domain Config File /etc/apache2/sites-available/phpmyadmin.$DOMAIN_NAME.conf ]"
        echo '[ Automatically Using Subdomain Configuration ]'
        echo '[ Copy Data From The Following Lines, Then Paste Into Apache Domain Config File ]'
        echo
        echo "<VirtualHost *:80>"
        echo "     ServerName phpmyadmin.$DOMAIN_NAME"
        echo "     ServerAdmin webmaster@$DOMAIN_NAME"
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

        echo '[ Fix "missing mcrypt" Error ]'
        S updatedb
        S locate mcrypt.ini
        P $MCRYPT_INI "full path to the mcrypt.ini file as returned by the locate command above"
        MCRYPT_INI=$USER_INPUT
        S locate mcrypt.so
        P $MCRYPT_SO "full path to the mcrypt.so file as returned by the locate command above"
        MCRYPT_SO=$USER_INPUT
        echo "[ Copy Data From The Following Line, Then Paste Into mcrypt Config File $MCRYPT_INI ]"
        echo "extension=$MCRYPT_SO"
        echo
        S $EDITOR $MCRYPT_INI
        S php5enmod mcrypt
        S service apache2 reload
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 25 ]; then
    echo '25. [[[ UBUNTU LINUX, INSTALL WEBMIN ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
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

if [ $MENU_CHOICE -le 26 ]; then
    echo '26. [[[ UBUNTU LINUX, INSTALL POSTFIX ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT

        echo '[ Enable Outgoing E-Mail ]'
        echo "[ For Internet Site Config Option, Use Fully-Qualified Domain Name $DOMAIN_NAME ]"
        S apt-get install postfix

        echo '[ Copy Data From The Following Line, Then Paste Into Postfix Config File /etc/postfix/main.cf ]'
        echo "myhostname = $DOMAIN_NAME"
        echo
        S $EDITOR /etc/postfix/main.cf

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

if [ $MENU_CHOICE -le 27 ]; then
    echo '27. [[[ UBUNTU LINUX, INSTALL PERL LOCAL::LIB  & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD Use This Instead Of Perlbrew Or Perl From Source In Sections 28 & 29, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With Perlbrew In Section 28! ]'
        echo '[ WARNING: Do NOT Mix With Perl From Source In Section 29! ]'
        C 'Please read the warnings above.  Seriously.'
        echo '[ Copied From RPerl Installer ]'
        S apt-get install curl
        B 'curl -L cpanmin.us | perl - -l $HOME/perl5 App::cpanminus local::lib'
        # echo 'eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' >> ~/.bashrc  # DEV NOTE: pre-munged command for comparison
        B echo "'" eval '$(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)' "'" '>> ~/.bashrc'
        C 'Please Log Out And Log Back In, Which Should Reset The $PERL Environmental Variables, Then Come Back To This Point.'
        echo '[ Ensure The Following 4 Environmental Variables Now Include ~/perl5: PERL_MM_OPT, PERL_MB_OPT, PERL5LIB, PATH ]'
        #B source ~/.bashrc  # DEV NOTE: force logout and log back in
        B 'set | grep perl5'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 28 ]; then
    echo '28. [[[ UBUNTU LINUX, INSTALL PERLBREW & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 27, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With local::lib In Section 27! ]'
        echo '[ WARNING: Do NOT Mix With Perl From Source In Section 29! ]'
        C 'Please read the warnings above.  Seriously.'
        echo '[ Copied From RPerl Installer ]'

        echo '[ You Should Use apt-get Instead Of curl Below, Unless You Are Not In Ubuntu Or Have No Choice ]'
        echo '[ WARNING: Use Only ONE Of The Following Two Commands, EITHER apt-get OR curl, But NOT Both! ]'
        C 'Please read the warning above.  Seriously.'
        S sudo apt-get install perlbrew
        # OR
        S 'curl -L http://install.perlbrew.pl | bash'

        echo '[ Configure Perlbrew ]'
        B perlbrew init
        echo '[ In Texas, The Following Perlbrew Mirror Is Recommended: Arlington, TX #222 http://mirror.uta.edu/CPAN/ ]'
        B perlbrew mirror
        B 'echo "source ~/perl5/perlbrew/etc/bashrc" >> ~/.bashrc'
        C 'Please Log Out And Log Back In, Which Should Reset The $PERL Environmental Variables, Then Come Back To This Point.'
        #B source ~/.bashrc  # DEV NOTE: force logout and log back in
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
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 29 ]; then
    echo '29. [[[ UBUNTU LINUX, INSTALL PERL FROM SOURCE & CPANM ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ You SHOULD NOT Use This Instead Of local::lib In Section 27, Unless You Have No Choice ]'
        echo '[ WARNING: Do NOT Mix With local::lib In Section 27! ]'
        echo '[ WARNING: Do NOT Mix With Perlbrew In Section 28! ]'
        C 'Please read the warnings above.  Seriously.'
        echo '[ Copied From RPerl Installer ]'
        B wget http://www.cpan.org/src/5.0/perl-5.24.0.tar.bz2
        B bunzip2 perl-5.24.0.tar.bz2
        B 'cd perl-5.24.0; perl Makefile.PL; make; make test'
        S 'cd perl-5.24.0; make install'
        S perl -MCPAN -e 'install App::cpanminus'
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 30 ]; then
    echo '30. [[[ PERL, INSTALL LATEST CATALYST ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: Do NOT Mix With Non-Latest Catalyst Via apt In Section 31! ]'
        C 'Please read the warning above.  Seriously.'
        B cpanm Task::Catalyst Catalyst::Devel
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 31 ]; then
    echo '31. [[[ UBUNTU LINUX, INSTALL NON-LATEST CATALYST ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo '[ WARNING: Do NOT Mix With Latest Catalyst Via CPAN In Section 30! ]'
        C 'Please read the warning above.  Seriously.'
        S apt-get install libmodule-install-perl libcatalyst-engine-apache-perl
        S service apache2 restart
        S apt-get install libcatalyst-devel-perl libcatalyst-modules-perl
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 32 ]; then
    echo '32. [[[ PERL, CHECK CATALYST VERSIONS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        B dpkg -p libcatalyst-perl
        echo
        echo '[ Please Look For All Directories In @INC, In The Output Of The perl -V Command Below ]'
        echo '[ Then, For Each Directory In @INC, Perform The Following ]'
        echo '$ ls -l /PATH/TO/DIRECTORY'
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
fi

# SECTION 33 VARIABLES
MYSQL_ROOTPASS='__EMPTY__'

if [ $MENU_CHOICE -le 33 ]; then
    echo '33. [[[ PERL, INSTALL RAPIDAPP ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        echo '[ You Should Use mysql & cpanm Instead Of git clone Below, Unless You Want The Experimental Version Or Have No Choice ]'
        echo '[ WARNING: Use Only ONE Of The Following Two Sets Of Commands, EITHER mysql & cpanm OR git clone, But NOT Both! ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ ONLY IF USING mysql & cpanm COMMANDS: Ensure MySQL Configured To Support Perl Distribution DBD::mysql `make test` Command ]'
        echo '[ ONLY IF USING mysql & cpanm COMMANDS: Copy Command From The Following Line ]'
        echo "mysql> GRANT ALL PRIVILEGES ON test.* TO '$USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password
        B cpanm DBD::mysql MooseX::NonMoose RapidApp
        # OR
        B git clone https://github.com/vanstyn/RapidApp.git ~/RapidApp-latest  # DEV NOTE: no makefile on github, can't make or install

        P $MYSQL_ROOTPASS "MySQL root Password"
        MYSQL_ROOTPASS=$USER_INPUT
        echo "[ phpMyAdmin Demo App, Username 'admin', Password 'pass' ]"
        B "mkdir -p ~/public_html; cd ~/public_html; rapidapp.pl --helpers RapidDbic,Templates,TabGui,AuthCore,NavCore RapidApp_phpmyadmin_database -- --dsn dbi:mysql:database=phpmyadmin,root,'$MYSQL_ROOTPASS'"
        B 'cd ~/public_html/RapidApp_phpmyadmin_database; perl Makefile.PL; make; make test'
        B ~/public_html/RapidApp_phpmyadmin_database/script/rapidapp_phpmyadmin_database_server.pl

        echo "[ BlueBox Demo App, Username 'admin', Password 'pass' ]"
        B git clone https://github.com/vanstyn/BlueBox.git ~/BlueBox-latest
        B 'cd ~/BlueBox-latest; perl Makefile.PL; cpanm --installdeps .'  # DEV NOTE: no make or test here, either
        B script/bluebox_server.pl
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 34 ]; then
    echo '34. [[[ UBUNTU LINUX, INSTALL SHINYCMS DEPENDENCIES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        echo '[ WARNING: Prerequisite Dependencies Include Full LAMP Stack (Sections 0 - 11, 20 - 23); mod_perl (Section 21) OR mod_fastcgi (This Section); Postfix (Section 26); And Expat, etc (This Section). ]'
        C 'Please read the warning above.  Seriously.'
        echo '[ Install Expat, etc ]'
        S sudo apt-get install expat libexpat1-dev libxml2-dev zlib1g-dev
        echo '[ Install FastCGI ]'
        echo '[ Copy Data From The Following Lines, Then Paste Into The Apt Config File /etc/apt/sources.list ]'
        echo 'deb http://us.archive.ubuntu.com/ubuntu/ trusty multiverse      # needed for FastCGI'
        echo 'deb-src http://us.archive.ubuntu.com/ubuntu/ trusty multiverse  # needed for FastCGI'
        S $EDITOR /etc/apt/sources.list
        S apt-get update
        S apt-get -f install
        S apt-get install libapache2-mod-fastcgi
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 35 ]; then
    echo  '35. [[[ PERL SHINYCMS, INSTALL SHINYCMS DEPENDENCIES & SHINYCMS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        echo '[ Ensure MySQL Configured To Support Perl Distribution DBD::mysql `make test` Command ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> GRANT ALL PRIVILEGES ON test.* TO '$USERNAME'@'localhost';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password
        echo '[ Install ShinyCMS Dependencies Via CPAN ]'
        B cpanm DBD::mysql Devel::Declare::MethodInstaller::Simple Text::CSV_XS inc::Module::Install Module::Install::Catalyst Test::Pod Test::Pod::Coverage
        B mkdir -p ~/public_html
        echo '[ Install MyShinyTemplate (ShinyCMS Fork) Via Github ]'
        B git clone git@github.com:wbraswell/myshinytemplate.com.git ~/public_html/$DOMAIN_NAME-latest
        B "cd ~/public_html/$DOMAIN_NAME-latest; perl Makefile.PL; cpanm --installdeps .; cpanm --installdeps ."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

# SECTION 36 VARIABLES
DOMAIN_NAME_UNDERSCORES='__EMPTY__'
DOMAIN_NAME_NO_USER='__EMPTY__'
MYSQL_USERNAME='__EMPTY__'
MYSQL_USERNAME_DEFAULT='__EMPTY__'
MYSQL_PASSWORD='__EMPTY__'
SITE_NAME='__EMPTY__'
ADMIN_FIRST_NAME='__EMPTY__'
ADMIN_LAST_NAME='__EMPTY__'
ADMIN_EMAIL='__EMPTY__'

if [ $MENU_CHOICE -le 36 ]; then
    echo  '36. [[[ PERL SHINYCMS, CREATE DATABASE & EDIT MYSHINYTEMPLATE FILES ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_NO_USER=$DOMAIN_NAME
        DOMAIN_NAME_NO_USER+='__no_user'
        MYSQL_USERNAME_DEFAULT=`expr match "$DOMAIN_NAME" '\([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*\)'`  # extract lowest-level hostname
        SITE_NAME=$MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME_DEFAULT+='_user'
        D $MYSQL_USERNAME "new mysql username to be created (different than new machine's OS username)" $MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME=$USER_INPUT
        P $MYSQL_PASSWORD "new mysql password"
        MYSQL_PASSWORD=$USER_INPUT
        P $ADMIN_FIRST_NAME "website administrator's first name"
        ADMIN_FIRST_NAME=$USER_INPUT
        P $ADMIN_LAST_NAME "website administrator's last name"
        ADMIN_LAST_NAME=$USER_INPUT
        P $ADMIN_EMAIL "website administrator's e-mail address"
        ADMIN_EMAIL=$USER_INPUT

        echo '[ Create ShinyCMS Database In MySQL ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE DATABASE $DOMAIN_NAME_UNDERSCORES;"
        echo "mysql> GRANT ALL PRIVILEGES ON $DOMAIN_NAME_UNDERSCORES.* TO '$MYSQL_USERNAME'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
        echo "mysql> QUIT"
        echo
        B mysql --user=root --password

        echo '[ Create ShinyCMS Config File ]'
        CD ~/public_html/$DOMAIN_NAME-latest
        B 'rm modified/shinycms.conf; mv shinycms.conf.redacted modified/shinycms.conf; ln -s modified/shinycms.conf ./shinycms.conf'
        B sed -ri -e "s/Will\ Braswell/$ADMIN_FIRST_NAME\ $ADMIN_LAST_NAME/g" shinycms.conf
        B sed -ri -e "s/william\.braswell\@autoparallel\.com/$ADMIN_EMAIL/g" shinycms.conf
        B sed -ri -e "s/MyShinyTemplate/$SITE_NAME/g" shinycms.conf
        B sed -ri -e "s/myshinytemplate\.com/$DOMAIN_NAME/g" shinycms.conf
        B sed -ri -e "s/wbraswell/$USERNAME/g" shinycms.conf
        B sed -ri -e "s/myshinytemplate_com/$DOMAIN_NAME_UNDERSCORES/g" shinycms.conf
        B sed -ri -e "s/template_user/$MYSQL_USERNAME/g" shinycms.conf
        B sed -ri -e "s/REDACTED/$MYSQL_PASSWORD/g" shinycms.conf

        echo '[ Create ShinyCMS Appendant Files ]'
        B make clean
        MYSHINY_FILES=$(grep -Elr --binary-files=without-match myshiny ./*)
        B sed -ri -e "s/myshinytemplate\.com/$DOMAIN_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/myshinytemplate_com/$DOMAIN_NAME_UNDERSCORES/g" $MYSHINY_FILES
        B sed -ri -e "s/MyShinyTemplate\.com/$DOMAIN_NAME/g" $MYSHINY_FILES
        B sed -ri -e "s/template_user/$MYSQL_USERNAME/g" $MYSHINY_FILES
        B sed -ri -e "s/wbraswell/$USERNAME/g" $MYSHINY_FILES
        
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

if [ $MENU_CHOICE -le 37 ]; then
    echo  '37. [[[ PERL SHINYCMS, BUILD DEMO DATABASE & RUN TESTS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        CD ~/public_html/$DOMAIN_NAME-latest
        echo '[ Build Database ]'
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

# SECTION 38 VARIABLES
DOMAIN_NAME_UNDERSCORES_NO_USER='__EMPTY__'

if [ $MENU_CHOICE -le 38 ]; then
    echo  '38. [[[ PERL SHINYCMS, BACKUP & RESTORE DATABASE ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT
        DOMAIN_NAME_UNDERSCORES=${DOMAIN_NAME//./_}  # replace dots with underscores
        DOMAIN_NAME_UNDERSCORES_NO_USER=$DOMAIN_NAME_UNDERSCORES
        DOMAIN_NAME_UNDERSCORES_NO_USER+='__no_user'
        MYSQL_USERNAME_DEFAULT=`expr match "$DOMAIN_NAME" '\([abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*\)'`  # extract lowest-level hostname
        SITE_NAME=$MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME_DEFAULT+='_user'
        D $MYSQL_USERNAME "mysql username (different than new machine's OS username)" $MYSQL_USERNAME_DEFAULT
        MYSQL_USERNAME=$USER_INPUT
        P $MYSQL_PASSWORD "mysql password"
        MYSQL_PASSWORD=$USER_INPUT
        echo '[ WARNING: Use Only One Of The Following Backup Commands, No Need To Use Both ]'
        C 'Please read the warning above.  Seriously.'

        echo '[ Backup Database, Do NOT Include ShinyCMS User & Password Data, Export Raw sql File ]'
        B "mysqldump --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES --lock-all-tables --ignore-table=$DOMAIN_NAME_UNDERSCORES.user > $DOMAIN_NAME_UNDERSCORES_NO_USER.sql"

        echo '[ Backup Database, DO Include ShinyCMS User & Password Data, Export Raw sql File ]'
        B "mysqldump --user=$MYSQL_USERNAME --password='$MYSQL_PASSWORD' $DOMAIN_NAME_UNDERSCORES --lock-all-tables > $DOMAIN_NAME_UNDERSCORES.sql"

        echo '[ Restore Database, Create Empty Database To Receive Restoration ]'
        echo '[ Copy Commands From The Following Lines ]'
        echo "mysql> CREATE DATABASE $DOMAIN_NAME_UNDERSCORES;"
        echo "mysql> GRANT ALL PRIVILEGES ON $DOMAIN_NAME_UNDERSCORES.* TO '$MYSQL_USERNAME'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';"
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

if [ $MENU_CHOICE -le 39 ]; then
    echo  '39. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_FASTCGI ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo "Nothing To Do On Current Machine!"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine First..."
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now..."
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 40 ]; then
    echo  '40. [[[ PERL SHINYCMS, CONFIGURE APACHE MOD_PERL ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        echo "Nothing To Do On Current Machine!"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine First..."
        C "Please Run LAMP Installer Section $CURRENT_SECTION On Existing Machine Now..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine First..."
        C "Please Run LAMP Installer Section $CURRENT_SECTION On New Machine Now..."
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 41 ]; then
    echo  '41. [[[ PERL SHINYCMS, CREATE APACHE DIRECTORIES & ENABLE STATIC PAGE ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
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

if [ $MENU_CHOICE -le 42 ]; then
    echo  '42. [[[ PERL SHINYCMS, CONFIGURE APACHE PERMISSIONS ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        D $EDITOR 'preferred text editor' 'vi'
        EDITOR=$USER_INPUT
        P $USERNAME "new machine's username"
        USERNAME=$USER_INPUT
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
        DOMAIN_NAME=$USER_INPUT

        echo '[ Add Username To Web Server User Group www-data, Allowing Username To Modify Appropriate Permissions ]'
        echo '[ Copy Data From The Following Line, Then Paste Into Operating System User Group Config File /etc/group ]'
        echo "www-data:x:33:$USERNAME"
        echo
        S $EDITOR /etc/group

        echo '[ Configure Operating System User/Group/Other Permissions ]'
        S chown -R $USERNAME:www-data /home/$USERNAME/
        S chmod -R u+rwX,o+rX,o-w /home/$USERNAME/public_html/$DOMAIN_NAME-latest
        S chmod -R g+rwX /home/$USERNAME/public_html/$DOMAIN_NAME-latest/root/static/cms-uploads/
        S chmod -R g+rX /home/$USERNAME/
        S service apache2 reload
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
    CURRENT_SECTION_COMPLETE
fi

if [ $MENU_CHOICE -le 43 ]; then
    echo  '43. [[[ PERL SHINYCMS, CONFIGURE SHINY ]]]'
    echo
    if [ $MACHINE_CHOICE -eq 0 ]; then
        P $DOMAIN_NAME "new machine's fully-qualified domain name (ex: domain.com OR subdomain.domain.com)"
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
        echo 'Admin area -> Pages -> List Pages -> Edit Home -> Add Image "/static/cms-uploads/images/homepage_added.png" & "Lorem Ipsum Dolor" Text'
        echo 'Admin area -> Pages -> List Templates -> Edit Homepage -> Delete "video_url" Element -> Update'
        echo
        C "Please follow the directions above..."
    elif [ $MACHINE_CHOICE -eq 1 ]; then
        echo "Nothing To Do On Existing Machine!"
    fi
#    CURRENT_SECTION_COMPLETE  # final section!
fi


echo
echo '[[[ ALL DONE!!! ]]]'
echo