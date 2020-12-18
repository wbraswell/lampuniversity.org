#!/bin/bash
# Copyright © 2020, William N. Braswell, Jr.. All Rights Reserved. This work is Free & Open Source; you can redistribute it and/or modify it under the same terms as Perl 5.

ARG=$1
echo; echo have \$ARG = $ARG

# strip trailing ".xml" file extension
ARG_NO_XML=${ARG%.xml}
echo; echo have \$ARG_NO_XML = $ARG_NO_XML

echo; echo rm -f $ARG_NO_XML.html
read -p "Press <ENTER> to continue..."
rm -f $ARG_NO_XML.html

# sudo apt-get install xsltproc

# parser error : internal error: Huge input lookup
# Segmentation fault (core dumped)
# xsltproc $ARG -o $ARG_NO_XML.html

# look Mom, I created a new --huge command-line argument!
# xsltproc --huge $ARG -o $ARG_NO_XML.html
echo; echo ~/repos_gitlab/libxslt-fork-latest/xsltproc/xsltproc --huge $ARG -o $ARG_NO_XML.html
read -p "Press <ENTER> to continue..."
~/repos_gitlab/libxslt-fork-latest/xsltproc/xsltproc --huge $ARG -o $ARG_NO_XML.html

# convert heart character '❤️' to valid HTML '&hearts;'
echo; echo perl -i -pe's/❤️/\&hearts;/g' $ARG_NO_XML.html
read -p "Press <ENTER> to continue..."
perl -i -pe's/❤️/\&hearts;/g' $ARG_NO_XML.html

