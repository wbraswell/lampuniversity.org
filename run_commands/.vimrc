" see .bashrc for opening files in new tab of existing gvim, alias gvim="gvim --remote-tab-silent"
" v0.053

" DEV NOTE, CORRELATION #lu001: some systems require 4-space-tab config code to be at the top of this file, some at the bottom
" always use 4 space characters instead of 1 tab character
:set smartindent
:set tabstop=4
:set shiftwidth=4
:set expandtab

" enable <CTRL> keybindings
source $VIMRUNTIME/mswin.vim
behave mswin

" start GVim windows maximized
if has("gui_running")
  " use wmctrl to tell the Xfce window manager to maximize gVim
  autocmd VimEnter * call system('wmctrl -i -b add,maximized_vert,maximized_horz -r ' . v:windowid)
endif

" [ BEGIN CLIPBOARD SETTINGS ]

" DEV NOTE: must install Vim/GVim Clipboard via LAMP_installer.sh version 0.534 or newer, section 12 GUI packages

" keep vim internal deletes (dd, x, etc) in internal memory;
" prevents vim from overwriting the OS clipboard during normal editing
:set clipboard=unnamed

" ensure visual highlights go to OS clipboard so Clipman grabs them before close,
" but use 'P' instead of 'a' to restore internal yank-and-pull across windows
:set guioptions-=a
:set guioptions+=P

" use 'pastetoggle' to prevent 'smartindent' from ruining multi-line pastes;
" hitting F11 turns 'paste mode' on ONLY while you are pasting data;
" hitting F11 again turns it off so your Ctrl+C and Ctrl+V work again;
" this is required because 'paste mode' disables all key mappings
:set nopaste 
:set pastetoggle=<F11> 
":set paste  " ERROR: causes noexpandtab, must be called before expandtab setting below

" [ END CLIPBOARD SETTINGS ]

" enable <CTRL>-arrow keybindings to jump words instead of delete lines
:set term=xterm

" DEV NOTE, CORRELATION #lu001: some systems require 4-space-tab config code to be at the top of this file, some at the bottom
" always use 4 space characters instead of 1 tab character
:set smartindent
:set tabstop=4
:set shiftwidth=4
:set expandtab

" enable <F12> as shortcut to refresh syntax highlighting
noremap <F12> <Esc>:syntax sync fromstart<CR>

" enable mouse click to move cursor
:set mouse=a
