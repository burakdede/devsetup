" ~/.vimrc -- fallback only.
"
" Neovim is the daily driver and is configured in ~/.config/nvim/. Vim does not
" read that config, and this file is never read by Neovim, so the two are
" entirely separate.
"
" This exists for the case where you land on a machine that has vim but not
" nvim (a bare server, a rescue shell, sudoedit). Its whole job is to make that
" experience feel like the Neovim setup rather than like stock vim, so muscle
" memory carries over.
"
" KEEP IT SMALL. Anything that needs a plugin belongs in the Neovim config, not
" here. When you change a core setting or a core mapping in
" ~/.config/nvim/lua/config/{options,keymaps}.lua, mirror it here if it is one
" of the basics below.

set nocompatible
filetype plugin indent on
syntax on

" ─── Leader ───────────────────────────────────────────────────────────────────
" Space, matching vim.g.mapleader in options.lua. The old vimrc mapped <Space>
" to PageDown, which fought that muscle memory directly.
let mapleader = " "
let maplocalleader = "\\"

" ─── Appearance ───────────────────────────────────────────────────────────────
if has('termguicolors')
  set termguicolors
endif
set number
set relativenumber
set signcolumn=yes
set cursorline
set colorcolumn=100
set laststatus=2
set showcmd
set title

" ─── Editing ──────────────────────────────────────────────────────────────────
set expandtab
set shiftwidth=4
set tabstop=4
set softtabstop=4
set shiftround
set smarttab
set autoindent
set nowrap
set linebreak
set textwidth=0

" ─── Search ───────────────────────────────────────────────────────────────────
set ignorecase
set smartcase
set hlsearch
set incsearch

" ─── Files & persistence ──────────────────────────────────────────────────────
set nobackup
set noswapfile
set autoread
if has('persistent_undo')
  set undofile
  set undodir=~/.vim/undo
  silent! call mkdir(expand('~/.vim/undo'), 'p')
endif

" ─── Splits ───────────────────────────────────────────────────────────────────
set splitbelow
set splitright

" ─── Clipboard ────────────────────────────────────────────────────────────────
" Matches opt.clipboard = "unnamedplus". Needs +clipboard; on Linux that means
" xclip or wl-clipboard, both installed by the Ubuntu system step.
if has('clipboard')
  set clipboard^=unnamedplus
endif

" ─── Misc ─────────────────────────────────────────────────────────────────────
set mouse=a
set encoding=utf-8
set scrolloff=8
set sidescrolloff=8
set updatetime=200
set timeoutlen=300
set wildmenu
set wildmode=longest:full,full
set pumheight=10
set list
set listchars=tab:»\ ,trail:·,nbsp:␣
set noerrorbells
set visualbell t_vb=

" ─── Mappings (mirroring lua/config/keymaps.lua) ──────────────────────────────
nnoremap <M-h> <C-w>h
nnoremap <M-j> <C-w>j
nnoremap <M-k> <C-w>k
nnoremap <M-l> <C-w>l

nnoremap <S-h> :bprevious<CR>
nnoremap <S-l> :bnext<CR>

nnoremap <silent> <Esc> :nohlsearch<CR>

vnoremap < <gv
vnoremap > >gv

vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>
vnoremap <C-s> <Esc>:w<CR>

" ─── Restore cursor position (mirrors autocmds.lua) ───────────────────────────
augroup RestoreCursor
  autocmd!
  autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END
