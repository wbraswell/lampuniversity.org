" see .bashrc for opening files in new tab of existing gvim, alias gvim="gvim --remote-tab-silent"

" always use 4 space characters instead of 1 tab character
:set smartindent
:set tabstop=4
:set shiftwidth=4
:set expandtab

" enable <CTRL> keybindings
source $VIMRUNTIME/mswin.vim
behave mswin

" enable system clipboard
:set clipboard=unnamed

:set paste  " ERROR: causes noexpandtab, must be called before expandtab setting below

" enable <CTRL>-arrow keybindings to jump words instead of delete lines
:set term=xterm

