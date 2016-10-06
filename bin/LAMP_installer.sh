#!/bin/bash
# Copyright © 2016, William N. Braswell, Jr.. All Rights Reserved. This work is Free \& Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.24.0.
# LAMP Installer Script v0.000_200

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

echo '[[[<<< LAMP Installer Script >>>]]]'
echo
echo \ '0. [[[ LINUX, CONFIGURE OPERATING SYSTEM USERS ]]]'
echo \ '1. [[[ LINUX, CONFIGURE CLOUD NETWORKING ]]]'
echo \ '2. [[[ UBUNTU LINUX, FIX BROKEN SWAP DEVICE ]]]'
echo \ '3. [[[ UBUNTU LINUX, FIX BROKEN LOCALE ]]]'
echo \ '4. [[[ UBUNTU LINUX, INSTALL EXPERIMENTAL UBUNTU SDK BEFORE OTHER PACKAGES ]]]'
echo \ '5. [[[ UBUNTU LINUX, UPGRADE ALL OPERATING SYSTEM PACKAGES ]]]'
echo \ '6. [[[ UBUNTU LINUX, UPDATE & INSTALL BASE OPERATING SYSTEM PACKAGES ]]]'
echo \ '7. [[[ UBUNTU LINUX, INSTALL & TEST CLAMAV ANTI-VIRUS ]]]'
echo \ '8. [[[ UBUNTU LINUX, FIX BROKEN SCREENSAVER ]]]'
echo \ '9. [[[ UBUNTU LINUX, UPDATE & INSTALL EXTRA OPERATING SYSTEM PACKAGES ]]]'
echo  '10. [[[ LINUX, INSTALL LAMP UNIVERSITY TOOLS ]]]'
echo  '11. [[[ UBUNTU LINUX, SET UP XFCE WINDOW MANAGER ]]]'
echo  '12. [[[ UBUNTU LINUX, ENABLE BROADCOM B43 WIFI ]]]'
echo  '13. [[[ UBUNTU LINUX, INSTALL X WINDOWS & XPRA ]]]'
echo  '14. [[[ UBUNTU LINUX, INSTALL NFS ]]]'
echo  '15. [[[ UBUNTU LINUX, PERFORMANCE BENCHMARKING ]]]'
echo  '16. [[[ APACHE, ENABLE DOMAIN(S) ]]]'
echo  '17. [[[ UBUNTU LINUX, INSTALL MYSQL & PHPMYADMIN ]]]'
echo  '18. [[[ MYSQL & APACHE, ENABLE PHPMYADMIN ]]]'
echo  '19. [[[ UBUNTU LINUX, INSTALL POSTFIX ]]]'
echo  '20. [[[ UBUNTU LINUX, INSTALL WEBMIN ]]]'
echo  '21. [[[ UBUNTU LINUX, INSTALL PERL CATALYST, SYSTEM-WIDE ]]]'
echo  '22. [[[ UBUNTU LINUX, INSTALL PERL CPANM & LOCAL::LIB; COPIED FROM RPERL INSTALL DOC ]]]'
echo  '23. [[[ UBUNTU LINUX, INSTALL HAND-COMPILED PERL, OR PERLBREW & CPANMINUS; COPIED FROM RPERL INSTALL DOC ]]]'
echo  '24. [[[ PERL CATALYST, INSTALL TUTORIAL ]]]'
echo  '25. [[[ PERL CATALYST, CHECK VERSIONS ]]]'
echo  '26. [[[ UBUNTU LINUX, INSTALL PERL CATALYST PREREQUISITES ]]]'
echo  '27. [[[ PERL CATALYST, INSTALL SHINYCMS FROM GITHUB & LATEST CATALYST FROM CPAN ]]]'
echo  '28. [[[ PERL CATALYST, INSTALL RAPIDAPP FROM GITHUB & LATEST CATALYST FROM CPAN ]]]'
echo

while true; do
    read -p 'Please enter your menu choice number, or press <ENTER> for 0... ' MENU_CHOICE
    case $MENU_CHOICE in
        [0-9]|1[0-9]|2[0-8] ) echo; break;;
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