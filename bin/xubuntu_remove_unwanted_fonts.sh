#!/bin/bash

#dpkg --list | awk '/FOO/{print $2}'
#dpkg --list | awk '/FOO/{print $2}' | sudo xargs dpkg --purge

# fonts-thai-tlwg depends on fonts-tlwg
dpkg --list | awk '/fonts-thai-tlwg/{print $2}'
dpkg --list | awk '/fonts-thai-tlwg/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-tlwg/{print $2}'
dpkg --list | awk '/fonts-tlwg/{print $2}' | sudo xargs dpkg --purge
#fonts-tlwg-garuda
#fonts-tlwg-garuda-ttf
#fonts-tlwg-kinnari
#fonts-tlwg-kinnari-ttf
#fonts-tlwg-laksaman
#fonts-tlwg-laksaman-ttf
#fonts-tlwg-loma
#fonts-tlwg-loma-ttf
#fonts-tlwg-mono
#fonts-tlwg-mono-ttf
#fonts-tlwg-norasi
#fonts-tlwg-norasi-ttf
#fonts-tlwg-purisa
#fonts-tlwg-purisa-ttf
#fonts-tlwg-sawasdee
#fonts-tlwg-sawasdee-ttf
#fonts-tlwg-typewriter
#fonts-tlwg-typewriter-ttf
#fonts-tlwg-typist
#fonts-tlwg-typist-ttf
#fonts-tlwg-typo
#fonts-tlwg-typo-ttf
#fonts-tlwg-umpush
#fonts-tlwg-umpush-ttf
#fonts-tlwg-waree
#fonts-tlwg-waree-ttf

# DEV NOTE: can not remove "noto" AKA "no tofu" fonts;
# xubuntu-default-settings depends on fonts-noto-hinted
# https://ubuntuforums.org/showthread.php?t=2452679
#dpkg --list | awk '/fonts-noto/{print $2}'
#dpkg --list | awk '/fonts-noto/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-kacst/{print $2}'
dpkg --list | awk '/fonts-kacst/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-khmeros/{print $2}'
dpkg --list | awk '/fonts-khmeros/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-lato/{print $2}'
dpkg --list | awk '/fonts-lato/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-lklug/{print $2}'
dpkg --list | awk '/fonts-lklug/{print $2}' | sudo xargs dpkg --purge

# fonts-guru depends on fonts-lohit-guru
dpkg --list | awk '/fonts-guru/{print $2}'
dpkg --list | awk '/fonts-guru/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-lohit/{print $2}'
dpkg --list | awk '/fonts-lohit/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-sil-padauk/{print $2}'
dpkg --list | awk '/fonts-sil-padauk/{print $2}' | sudo xargs dpkg --purge

dpkg --list | awk '/fonts-tibetan/{print $2}'
dpkg --list | awk '/fonts-tibetan/{print $2}' | sudo xargs dpkg --purge

