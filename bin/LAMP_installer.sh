#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.24.0.
# LAMP Installer Script v0.000_300

# requires double-quotes when called
b='bash -xc'
#$b "echo DUMMY COMMAND $MENU_CHOICE 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49"

# does not require double-quotes when called
B () {
	echo '$' "$@"
	while true; do
		read -p 'Run above command, yes or no?  [yes] ' -n 1 PROMPT_INPUT
        case $PROMPT_INPUT in
        	n|N ) echo; echo; return;;
    		y|Y ) echo; break;;
    		'' ) break;;
        	* ) echo;;
		esac
	done
	#	bash -xc " \  # -x replaced w/ echo above
	bash -c " \
		      ${01} ${02} ${03} ${04} ${05} ${06} ${07} ${08} ${09} ${10} ${11} ${12} ${13} ${14} ${15} ${16} ${17} ${18} ${19} \
		${20} ${21} ${22} ${23} ${24} ${25} ${26} ${27} ${28} ${29} ${30} ${31} ${32} ${33} ${34} ${35} ${36} ${37} ${38} ${39} \
		${40} ${41} ${42} ${43} ${44} ${45} ${46} ${47} ${48} ${49} ${50} ${51} ${52} ${53} ${54} ${55} ${56} ${57} ${58} ${59} \
		${60} ${61} ${62} ${63} ${64} ${65} ${66} ${67} ${68} ${69} ${70} ${71} ${72} ${73} ${74} ${75} ${76} ${77} ${78} ${79} \
		${80} ${81} ${82} ${83} ${84} ${85} ${86} ${87} ${88} ${89} ${90} ${91} ${92} ${93} ${94} ${95} ${96} ${97} ${98} ${99} "
	echo
}
#B echo DUMMY COMMAND $MENU_CHOICE 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49

echo  '    [[[<<< LAMP Installer Script >>>]]]'
echo

echo  '    <<< LOCAL CLI >>>'
echo \ '0. [[[        LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
echo \ '1. [[[        LINUX, CONFIGURE CLOUD NETWORKING ]]]'
echo \ '2. [[[ UBUNTU LINUX, FIX BROKEN SWAP DEVICE ]]]'
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

echo  '    <<< LOCAL GUI >>>'
echo  '12. [[[ UBUNTU LINUX, INSTALL BASE GUI OPERATING SYSTEM PACKAGES ]]]'
echo  '13. [[[ UBUNTU LINUX, INSTALL EXTRA GUI OPERATING SYSTEM PACKAGES ]]]'
echo  '14. [[[ UBUNTU LINUX, INSTALL XPRA ]]]'
echo  '15. [[[ UBUNTU LINUX, INSTALL VIRTUALBOX GUEST ADDITIONS ]]]'
echo  '16. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER ]]]'
echo  '17. [[[ UBUNTU LINUX, CONFIGURE XFCE WINDOW MANAGER ]]]'
echo

echo  '    <<< SERVICES >>>'
echo  '18. [[[ UBUNTU LINUX,   INSTALL NFS ]]]'
echo  '19. [[[ UBUNTU LINUX,   INSTALL APACHE & MOD_PERL ]]]'
echo  '20. [[[ APACHE,         CONFIGURE DOMAIN(S) ]]]'
echo  '21. [[[ UBUNTU LINUX,   INSTALL MYSQL & PHPMYADMIN ]]]'
echo  '22. [[[ APACHE & MYSQL, CONFIGURE PHPMYADMIN ]]]'
echo  '23. [[[ UBUNTU LINUX,   INSTALL WEBMIN ]]]'
echo  '24. [[[ UBUNTU LINUX,   INSTALL POSTFIX ]]]'
echo  '25. [[[ UBUNTU LINUX,   INSTALL NON-LATEST PERL CATALYST ]]]'
echo  '26. [[[ UBUNTU LINUX,   INSTALL PERL CPANM & LOCAL::LIB; COPIED FROM RPERL INSTALL DOC ]]]'
echo  '27. [[[ UBUNTU LINUX,   INSTALL HAND-COMPILED PERL, OR PERLBREW & CPANMINUS; COPIED FROM RPERL INSTALL DOC ]]]'
echo  '28. [[[ PERL CATALYST,  INSTALL TUTORIAL FROM CPAN ]]]'
echo  '29. [[[ UBUNTU LINUX,   INSTALL PERL CATALYST SHINYCMS PREREQUISITES ]]]'
echo  '30. [[[ PERL CATALYST,  INSTALL SHINYCMS FROM GITHUB & LATEST CATALYST FROM CPAN ]]]'
echo  '31. [[[ PERL CATALYST,  INSTALL RAPIDAPP FROM GITHUB & LATEST CATALYST FROM CPAN ]]]'
echo  '32. [[[ PERL CATALYST,  CHECK VERSIONS ]]]'
echo

while true; do
    read -p 'Please enter your menu choice number, or press <ENTER> for 0... ' MENU_CHOICE
    case $MENU_CHOICE in
        [0-9]|[12][0-9]|3[0-2] ) echo; break;;
    	'' ) echo; MENU_CHOICE=0; break;;
        * ) echo 'Please choose a number from the menu!'; echo;;
	esac
done

if [ $MENU_CHOICE -le 0 ]; then
	echo '0. [[[ LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
	echo
	B echo DUMMY COMMAND $MENU_CHOICE 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49
	B echo ANOTHER DUMMY COMMAND $MENU_CHOICE 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49
fi

if [ $MENU_CHOICE -le 1 ]; then
	echo '1. [[[ LINUX, CONFIGURE CLOUD NETWORKING ]]]'
	echo
fi

if [ $MENU_CHOICE -le 2 ]; then
	echo '2. [[[ UBUNTU LINUX, FIX BROKEN SWAP DEVICE ]]]'
	echo
fi

if [ $MENU_CHOICE -le 3 ]; then
	echo '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
	echo
fi

if [ $MENU_CHOICE -le 4 ]; then
	echo '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
	echo
fi