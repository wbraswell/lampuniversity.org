# Last Updated 20181019 2018.292

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# NON-INTERACTIVE CUSTOM USER CONTENT BELOW

# Source global definitions
if [ -f /etc/bashrc ]; then
    source /etc/bashrc
fi

# [[[ BEGIN CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]
# [[[ BEGIN CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]
# [[[ BEGIN CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]

# enable local::lib, do NOT mix with Perlbrew below
if [ -d $HOME/perl5/lib/perl5 ]; then 
    eval $(perl -I$HOME/perl5/lib/perl5 -Mlocal::lib)
fi

# enable Perlbrew, do NOT mix with local::lib above
#source ~/perl5/perlbrew/etc/bashrc

# current directory code
# DEV NOTE: do NOT enable relative (non-absolute) dirs in @INC,
# may cause unpredictable behavior, or may cause dists (like Net::DNS) to locate themselves during `perl Makefile.PL`
#export PERL5LIB=blib/lib:lib:$PERL5LIB
# DEV NOTE: append relative paths to the end of PATH,
# to avoid error "No such file or directory" if ./script/ or ./bin/ exist & desired command is instead in ~/script/ or ~/bin/
export PATH=$HOME/script:$HOME/bin:$PATH:.:script:bin

# RPerl GitHub latest code
if [ -d $HOME/github_repos/rperl-latest ]; then 
    export PERL5LIB=$HOME/github_repos/rperl-latest/lib:$PERL5LIB
    export PATH=$HOME/github_repos/rperl-latest/script:$PATH
fi

# MathPerl GitHub latest code
if [ -d $HOME/github_repos/mathperl-latest ]; then 
    export PERL5LIB=$HOME/github_repos/mathperl-latest/lib:$PERL5LIB
    export PATH=$HOME/github_repos/mathperl-latest/script:$PATH
fi

# PhysicsPerl GitHub latest code
if [ -d $HOME/github_repos/physicsperl-latest ]; then 
    export PERL5LIB=$HOME/github_repos/physicsperl-latest/lib:$PERL5LIB
    export PATH=$HOME/github_repos/physicsperl-latest/script:$PATH
fi

# perlall
if [ -f ~/.perlall ]; then
    source ~/.perlall
fi

# Vi; for opening files in new tab of existing gvim, couldn't figure how to put this in .vimrc
alias gvim="gvim --remote-tab-silent"

# [[[ END CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]
# [[[ END CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]
# [[[ END CONTENT, LAMP UNIVERSITY & RPERL FAMILY OF SOFTWARE ]]]

# END NON-INTERACTIVE CONTENT

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    source ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    source /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    source /etc/bash_completion
  fi
fi

# INTERACTIVE CUSTOM USER CONTENT BELOW

# SSH Keys; for GitHub, etc.
if [ -f /usr/bin/keychain ] && [ -f $HOME/.ssh/id_rsa ]; then
    /usr/bin/keychain $HOME/.ssh/id_rsa
    source $HOME/.keychain/$HOSTNAME-sh
fi

