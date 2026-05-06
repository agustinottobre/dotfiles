set clipboard=unnamedplus
" search
" ******************************************************************************
" Incremental highlight while typing a search command.
set incsearch
" If the 'ignorecase' option is on, the case of normal letters is ignored.
set ignorecase
" Ignore case when the pattern contains lowercase letters only.
set smartcase
" When there is a previous search pattern, highlight all its matches.
set hlsearch
" clear the highlight
nmap \q :nohlsearch<CR>
" ******************************************************************************
set maxmempattern=1000000  " Increase the maximum memory for patterns

" number each line from top to bottom
set number
" number each lines relative to cursor position up & down
set relativenumber

" ******************************************************************************
" map <leader> key
let g:mapleader = "\<Space>"
let g:maplocalleader = ','

let g:sync_taskwarrior = 0
" Plugin 'liuchengxu/vim-which-key'
" ******************************************************************************
nnoremap <silent> <leader>      :<c-u>WhichKey '<Space>'<CR>
nnoremap <silent> <localleader> :<c-u>WhichKey  ','<CR>
" By default timeoutlen is 1000 ms
set timeoutlen=500
" ******************************************************************************

" Edit vimrc configuration
" ******************************************************************************
function! Config()
  :vsp $HOME/.vimrc
endfunction
command! Config call Config()
nnoremap <leader>co :call Config()<CR>

" Source $HOME/.vimrc (Reload)
nnoremap <leader>r :source $HOME/.vimrc<CR>

" Format xml
" ******************************************************************************
nnoremap <leader>pxml :%!xmllint --format %<CR>
" ******************************************************************************

"deprecated
"set pastetoggle=<F12> "toggle paste / no paste
nnoremap <F12> :set paste!<CR>

" hightlight text according to syntax
syntax on
" set foldmethod=syntax
"set foldmethod=indent
"foldlevel=0 means all closed
" set foldlevel=99

" each tab is equivalent to 2 spaces
set tabstop=2
set shiftwidth=2
" replace tab with spaces
set expandtab
"show special characters
"set list
" Do not visually wrap text, if the window shrinks keep the line as is
set nowrap
" Set max text width, gqG reformats the whole file
set textwidth=80
" Number of characters from the right window border where wrapping starts.
set wrapmargin=0
" formatoptions char seq that describes how automatic formatting is to be done.
" t: Auto-wrap text using textwidth
set formatoptions+=t

"vertical ruler
set colorcolumn=81
"tune vertical ruler color
highlight ColorColumn ctermbg=0 guibg=lightgrey
"This highlights the background in a subtle red for text that goes over the 80
"column limit (subtle in GUI mode, anyway - in terminal mode it's less so).
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%81v.\+/

" If during this time in ms nothing is typed the swap file will be written to
" disk. YouCompleteMe linter and vim-gitgutter marks updates on this rate.
" Default is too slow (4000 ms = 4 seconds).
set updatetime=400

" This is currently done by "date" ultisnip
"insert current date & time
" nnoremap <leader>now "=strftime("%Y-%m-%d-%H:%M")<CR>P
" inoremap <leader>now <C-R>=strftime("%Y-%m-%d-%H:%M")<CR>
"insert current date
" nnoremap <leader>day "=strftime("%Y-%m-%d")<CR>P
" inoremap <leader>day <C-R>=strftime("%Y-%m-%d")<CR>

" Buffers
" ******************************************************************************
" vanilla switching
" nnoremap gb :ls<CR>:b<Space>
" fzf switching
nnoremap <silent> gb :Buffers<CR>
nmap <C-n> :bnext<CR>
nmap <C-p> :bprev<CR>
" ******************************************************************************

" netrw
" ******************************************************************************
"let g:netrw_banner = 0 "Remove the banner
"let g:netrw_liststyle = 3 "directory view in netrw
"let g:netrw_browse_split = 4 "Changing how files are opened
""let g:netrw_altv = 1
let g:netrw_winsize = 25 "Set the width of the directory explorer
"augroup ProjectDrawer
"  autocmd!
"  autocmd VimEnter * :Vexplore
"augroup END

" Freed <C-l> in Netrw
nmap <leader><leader><leader><leader><leader><leader>l <Plug>NetrwRefresh

" netrw h and l nav
function! NetrwBuf()
  nmap <buffer> h -
  nmap <buffer> l <CR>
endfunction

augroup FILETYPES
  autocmd FileType netrw call NetrwBuf()
augroup END
" ******************************************************************************

" Plugin 'tpope/vim-vinegar'
" ******************************************************************************
" NOT WORKING YET
" vim-vinagar map - to Rexplore to close vinagar
"autocmd VimEnter * if &ft ==# "netrw" | noremap - :Rex | endif
"if &ft ==# "netrw"
"  noremap - :Rex
"endif
" ******************************************************************************

" Plugin 'ycm-core/YouCompleteMe'
" ******************************************************************************
"YouCompleteMe requirements for java projects
"Diagnostic display - Syntastic
"let g:syntastic_java_checkers = []
"Diagnostic display - Eclim
"let g:EclimFileTypeValidate = 0
" ******************************************************************************

" Plug 'neoclide/coc.nvim', {'branch': 'release'}
" ******************************************************************************
set completeopt=longest,menuone
" --------------------------------------------------------
" COC-VIM TAB SETTINGS START

" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" Use <c-space> to trigger completion.
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current
" position. Coc only does snippet and additional edit on confirm.
" <cr> could be remapped by other vim plugin, try `:verbose imap <CR>`.
if exists('*complete_info')
  inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"
else
  inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"
endif

" COC-VIM TAB SETTINGS END
" ******************************************************************************

" Plugin 'Konfekt/FastFold'
" ******************************************************************************
nmap zuz <Plug>(FastFoldUpdate)
let g:fastfold_savehook = 1
let g:fastfold_fold_command_suffixes =  ['x','X','a','A','o','O','c','C']
let g:fastfold_fold_movement_commands = [']z', '[z', 'zj', 'zk']
let g:fastfold_fdmhook = 0
let g:loaded_markdown = 1

let g:markdown_folding = 1
" ******************************************************************************

" Plugin 'mbbill/undotree'
" ******************************************************************************
" Use persistent history.
if !isdirectory($HOME."/.vim/undodir")
  call mkdir($HOME."/.vim/undodir", "", 0700)
endif
set undodir=$HOME/.vim/undodir
set undofile

nnoremap <leader>ut :UndotreeToggle<cr>
" ******************************************************************************

" Plugin 'VundleVim/Vundle.vim'
" ******************************************************************************
set nocompatible              " be iMproved, required
filetype off                   " required!

" set the runtime path to include Vundle and initialize
"set rtp+=~/.vim/bundle/Vundle.vim
"call vundle#begin()
call plug#begin()

Plug 'christoomey/vim-tmux-navigator'
Plug 'mbbill/undotree'
Plug 'aklt/plantuml-syntax', { 'ft': 'plantuml' }
Plug 'hashivim/vim-terraform', { 'ft': 'terraform' }
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'chrisbra/csv.vim'
Plug 'lervag/wiki.vim'
Plug 'vuciv/vim-bujo'
""Plug 'wsdjeg/vim-todo'
""Plug 'agustinottobre/taskwiki'
""Plug 'agustinottobre/vimwiki-sync'
Plug 'skywind3000/asyncrun.vim'
Plug 'agustinottobre/wikivim-sync', {'branch': 'main'}
Plug 'bullets-vim/bullets.vim', { 'ft': 'markdown' }
""Plug 'dense-analysis/ale'
"" Plug 'preservim/vim-lexical'
"" Plug 'preservim/vim-litecorrect'
"" Plug 'mattn/calendar-vim'
Plug 'godlygeek/tabular', { 'on': 'Tabularize' }
" Is this helpfull or embeded in vimwiki? It breaks vimwiki folding...
""Plug 'preservim/vim-markdown'
Plug 'Konfekt/FastFold'
Plug 'iamcco/markdown-preview.nvim'
Plug 'Yggdroot/indentLine'
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive', { 'on': 'Git' }
Plug 'itchyny/lightline.vim'
Plug 'morhetz/gruvbox'
Plug 'tpope/vim-vinegar'
" Plug 'SirVer/ultisnips'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'airblade/vim-gitgutter'
Plug 'liuchengxu/vim-which-key'
"" Plug 'jceb/vim-orgmode'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
Plug 'tpope/vim-commentary'
Plug 'preservim/tagbar'
"" Plugin 'ludovicchabant/vim-gutentags'
Plug 'dart-lang/dart-vim-plugin'

"call vundle#end()            " required
call plug#end()
filetype plugin indent on   " re-enable filetype
" ******************************************************************************

" Plugin 'morhetz/gruvbox'
" ******************************************************************************
set background=dark    " Setting dark mode, so gruvbox uses dark theme
"g:gruvbox_contrast_dark works only if the hi Normal cmd below is not set
"let g:gruvbox_contrast_dark = 'hard'
"Set the color scheme installed by gruvbox plugin
colorscheme gruvbox
"for VimDiff highlight
"Gray background
autocmd vimenter * hi DiffChange cterm=BOLD ctermfg=NONE ctermbg=237
"light yellow background
"autocmd vimenter * hi DiffChange cterm=BOLD ctermfg=NONE ctermbg=228
"for tmux forground and background dim when inactive "transparent fg and bg
"This seems to easier than updating colorscheme on focus events
autocmd vimenter * hi Normal guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE
" ******************************************************************************

" Change colorscheme on focus events inside tmux.
" ******************************************************************************
"It requires tmux-plugins/vim-tmux-focus-events
"au FocusGained * let g:gruvbox_contrast_dark = 'hard' | :colo gruvbox
"au FocusLost * let g:gruvbox_contrast_dark = 'soft' | :colo gruvbox

"Better vimdiff highlight for colorscheme:default
"https://www.codyhiar.com/blog/vimdiff-better-highlighting/
"highlight DiffAdd    cterm=BOLD ctermfg=NONE ctermbg=22
"highlight DiffDelete cterm=BOLD ctermfg=NONE ctermbg=52
"highlight DiffChange cterm=BOLD ctermfg=NONE ctermbg=23
"highlight DiffText   cterm=BOLD ctermfg=NONE ctermbg=23
" ******************************************************************************

" Plugin 'itchyny/lightline.vim'
" ******************************************************************************
set laststatus=2
set noshowmode
let g:lightline = {
  \   'colorscheme': 'gruvbox',
  \   'active': {
  \     'left':[ [ 'mode', 'paste' ],
  \              [ 'gitbranch', 'readonly', 'filename', 'modified' ]
  \     ]
  \   },
  \   'component_function': {
  \     'gitbranch': 'FugitiveHead',
  \     'fileformat': 'LightlineFileformat',
  \     'filetype': 'LightlineFiletype',
  \     'filename': 'LightlineFilename',
  \     'fileencoding': 'LightLineFileencoding',
  \     'mode': 'LightLineMode',
  \   }
  \ }
"Hide file format on narrow window
function! LightlineFileformat()
  return winwidth(0) > 70 ? &fileformat : ''
endfunction
"Hide file type on narrow window
function! LightlineFiletype()
  return winwidth(0) > 70 ? (&filetype !=# '' ? &filetype : 'no ft') : ''
endfunction
"Hide file encoding on narrow window
function! LightLineFileencoding()
  return winwidth(0) > 70 ? (strlen(&fenc) ? &fenc : &enc) : ''
endfunction
"Hide mode on narrow window
function! LightLineMode()
  return winwidth(0) > 60 ? lightline#mode() : ''
endfunction
"Show absolute path on regular files and relative to git root dir on repos.
"Requires vim fugitive
function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction
" ******************************************************************************

" Plugin 'Yggdroot/indentLine'
" ******************************************************************************
" indentline config to avoid vimwiki conceal issues
" https://github.com/Yggdroot/indentLine/issues/303
let g:indentLine_concealcursor=""
let g:indentLine_conceallevel=2
" ******************************************************************************

" plugin 'vimwiki/vimwiki'
" ******************************************************************************
"let wiki = {'path': '~/wiki/', 'syntax': 'markdown', 'ext': '.md'}
"let wiki_work = {'path': '~/wiki_work/', 'syntax': 'markdown', 'ext': '.md'}
"let g:vimwiki_list = [wiki, wiki_work]
" Append wiki file extension to links in Markdown. This is needed for
" compatibility with other Markdown tools.
"let g:vimwiki_markdown_link_ext = 1
"let g:vimwiki_url_maxsave = 2
"avoid wiki file management oustide wiki dir, i.e. to avoid wiki behaviour on
"all other .md files
"let g:vimwiki_global_ext = 0
"let g:vimwiki_hl_cb_checked = 2 "Highlight a complete checked list item and all its child items
" let g:vimwiki_folding = 'expr'
" let g:vimwiki_folding = 'syntax'
" let g:vimwiki_folding = 'expr:quick'

" autocommand to call VimwikiDiaryGenerateLinks
"command! Diary VimwikiDiaryIndex
"augroup vimwikigroup
"    autocmd!
"    " automatically update links on read diary
"    autocmd BufRead,BufNewFile diary.wiki VimwikiDiaryGenerateLinks
"augroup end
" ******************************************************************************

" plugin 'lervag/wiki.vim"
" ******************************************************************************
let g:wiki_root = '~/wiki'
" ******************************************************************************

" Plug 'bullets-vim/bullets.vim'
" ******************************************************************************
let g:bullets_custom_mappings = [
  \ ['nmap', '<C-Space>', '<Plug>(bullets-toggle-checkbox)'],
  \ ]
" ******************************************************************************

" Plugin 'vuciv/vim-bujo'
" ******************************************************************************
let g:bujo#todo_file_path = $HOME . "/wiki"
let g:bujo#window_width = 80
nmap <leader>to :botright Todo<CR>
" ******************************************************************************

" Plugin 'dense-analysis/ale'
" ******************************************************************************
" ALE uses languagetool and proselint command line tools to check grammar and
" suggest writting improvements.
" ******************************************************************************
let g:ale_virtualtext_cursor = 'disabled'
let g:ale_virtualtext_delay = 5

" Plugin 'preservim/vim-lexical'
" ******************************************************************************
"let g:lexical#spellfile = ['$HOME/.vim/spell/en.utf-8.add',]
"let g:lexical#thesaurus = [ '$HOME/.vim/thesaurus/mthesaur.txt',
"  \ '$HOME/.vim/thesaurus/thesaurii.txt']
"let g:lexical#dictionary = ['/usr/share/dict/words',]
"
"augroup lexical
"  autocmd!
"  autocmd FileType markdown,mkd call lexical#init()
"  autocmd FileType text call lexical#init({ 'spell': 0 })
"augroup END
" ******************************************************************************

" Plugin 'preservim/vim-litecorrect'
" ******************************************************************************
"augroup litecorrect
"  autocmd!
"  autocmd FileType markdown,mkd call litecorrect#init()
"augroup END
" ******************************************************************************

" Plugin 'iamcco/markdown-preview.nvim'
" ******************************************************************************
" markdown enhanced vim
" open browser each time a markdown buffer opens
"let g:mkdp_auto_start = 1
nnoremap <Leader>mp :MarkdownPreview<CR>
" ******************************************************************************

" Plugin 'junegunn/fzf'
" Plugin 'junegunn/fzf.vim'
" ******************************************************************************
" Open Files
"nnoremap <C-x><C-f> :Files<CR>
"nnoremap <silent> <C-g> :GFiles<CR>

" Path completion with custom source command
inoremap <expr> <c-x><c-f> fzf#vim#complete#path('fd')

"If the current buffer is tracked by git (even in a subdirectory),
"   get the root directory of the project,
"if it is not under git control,
"   get the current working directory
function! s:getProjectDirForCurrentBuffer()
  let gitDir = system(
    \ 'git -C '.expand('%:p:h').' rev-parse --show-toplevel 2> /dev/null')[:-2]
  return len(gitDir) > 0 ? gitDir : getcwd()
endfunction

command! -bang -nargs=? -complete=dir FilesProjectDirForCurrentBuffer
    \ call fzf#vim#files(
    \   s:getProjectDirForCurrentBuffer(), fzf#vim#with_preview(), <bang>0)

nnoremap <C-x><C-f> :FilesProjectDirForCurrentBuffer<CR>

"Grep recursively within the project directory of the current buffer
command! -bang -nargs=* RgWithinCurrentBufferProject
  \ call fzf#vim#grep(
  \   "rg --column --line-number --no-heading --color=always --smart-case
  \   ".shellescape(<q-args>), 1,
  \   {'dir': s:getProjectDirForCurrentBuffer()}, <bang>-1)

nnoremap <C-x><C-p> :RgWithinCurrentBufferProject<CR>

" ******************************************************************************

" Plugin 'tpope/vim-fugitive'
" ******************************************************************************
" fugitive git add
command Gadd Git add %
" ******************************************************************************

" DiffHistory for Git branch diff
" ******************************************************************************
"https://github.com/tpope/vim-fugitive/issues/132
command! DiffHistory call s:view_git_history()

function! s:view_git_history() abort
  Git difftool --name-only ! !^@
  call s:diff_current_quickfix_entry()
  " Bind <CR> for current quickfix window to properly set up diff split layout after selecting an item
  " There's probably a better way to map this without changing the window
  copen
  nnoremap <buffer> <CR> <CR><BAR>:call <sid>diff_current_quickfix_entry()<CR>
  wincmd p
endfunction

function s:diff_current_quickfix_entry() abort
  " Cleanup windows
  for window in getwininfo()
    if window.winnr !=? winnr() && bufname(window.bufnr) =~? '^fugitive:'
      exe 'bdelete' window.bufnr
    endif
  endfor
  cc
  call s:add_mappings()
  let qf = getqflist({'context': 0, 'idx': 0})
  if get(qf, 'idx') && type(get(qf, 'context')) == type({}) && type(get(qf.context, 'items')) == type([])
    let diff = get(qf.context.items[qf.idx - 1], 'diff', [])
    echom string(reverse(range(len(diff))))
    for i in reverse(range(len(diff)))
      exe (i ? 'leftabove' : 'rightbelow') 'vert diffsplit' fnameescape(diff[i].filename)
      call s:add_mappings()
    endfor
  endif
endfunction

function! s:add_mappings() abort
  nnoremap <buffer>]q :cnext <BAR> :call <sid>diff_current_quickfix_entry()<CR>
  nnoremap <buffer>[q :cprevious <BAR> :call <sid>diff_current_quickfix_entry()<CR>
  " Reset quickfix height. Sometimes it messes up after selecting another item
  11copen
  wincmd p
endfunction
" ******************************************************************************

" Plugin 'SirVer/ultisnips'
" ******************************************************************************
" Trigger configuration.
let g:UltiSnipsExpandTrigger="<c-j>"
let g:UltiSnipsJumpForwardTrigger="<c-j>"
let g:UltiSnipsJumpBackwardTrigger="<c-k>"

" If you want :UltiSnipsEdit to split your window.
let g:UltiSnipsEditSplit="vertical"

let g:snips_author = ''
let g:snips_email = ''
" ******************************************************************************

" Plugin 'junegunn/goyo.vim'
" ******************************************************************************
" Toggle Goyo
nnoremap <Leader>go :Goyo<CR>
let g:goyo_width=81
let g:goyo_height="100%"
let g:goyo_linenr=1
" ******************************************************************************

" Plugin 'junegunn/limelight.vim'
" ******************************************************************************

" When GoyoEnter Set Limelight, wrap text assuming it is prose, remap j and k to
" move between wrapped lines as if the were real lines.
function! s:goyo_enter()
  if executable('tmux') && strlen($TMUX)
    silent !tmux set status off
  "  silent !tmux list-panes -F '\#F' | grep -q Z || tmux resize-pane -Z
  endif
  set noshowmode
  set noshowcmd
  " Setting 'scrolloff' to a large value causes the cursor to stay in the middle
  " line when possible:
  set scrolloff=999
  nnoremap j gj
  nnoremap k gk
  Limelight
  set wrap
endfunction

" When GoyoLeave rollback them all.
function! s:goyo_leave()
  if executable('tmux') && strlen($TMUX)
    silent !tmux set status on
  "  silent !tmux list-panes -F '\#F' | grep -q Z && tmux resize-pane -Z
  endif
  set showmode
  set showcmd
  set scrolloff=5
  unmap j
  unmap k
  Limelight!
  hi Normal guifg=NONE ctermfg=NONE guibg=NONE ctermbg=NONE
  set nowrap
endfunction

autocmd! User GoyoEnter nested call <SID>goyo_enter()
autocmd! User GoyoLeave nested call <SID>goyo_leave()

let g:limelight_conceal_ctermfg = 240
" ******************************************************************************

" Plugin 'tpope/vim-commentary'
" ******************************************************************************
autocmd FileType dart setlocal commentstring=//\ %s
" ******************************************************************************

" Plugin 'preservim/tagbar'
" ******************************************************************************
nmap <leader>tb :TagbarToggle<CR>
" ******************************************************************************

" Tmux-like window resizing
" ******************************************************************************
function! IsEdgeWindowSelected(direction)
    let l:curwindow = winnr()
    exec "wincmd ".a:direction
    let l:result = l:curwindow == winnr()

    if (!l:result)
        " Go back to the previous window
        exec l:curwindow."wincmd w"
    endif

    return l:result
endfunction

function! GetAction(direction)
    let l:keys = ['h', 'j', 'k', 'l']
    let l:actions = ['vertical resize -', 'resize +', 'resize -', 'vertical resize +']
    return get(l:actions, index(l:keys, a:direction))
endfunction

function! GetOpposite(direction)
    let l:keys = ['h', 'j', 'k', 'l']
    let l:opposites = ['l', 'k', 'j', 'h']
    return get(l:opposites, index(l:keys, a:direction))
endfunction

function! TmuxResize(direction, amount)
    " v >
    if (a:direction == 'j' || a:direction == 'l')
        if IsEdgeWindowSelected(a:direction)
            let l:opposite = GetOpposite(a:direction)
            let l:curwindow = winnr()
            exec 'wincmd '.l:opposite
            let l:action = GetAction(a:direction)
            exec l:action.a:amount
            exec l:curwindow.'wincmd w'
            return
        endif
    " < ^
    elseif (a:direction == 'h' || a:direction == 'k')
        let l:opposite = GetOpposite(a:direction)
        if IsEdgeWindowSelected(l:opposite)
            let l:curwindow = winnr()
            exec 'wincmd '.a:direction
            let l:action = GetAction(a:direction)
            exec l:action.a:amount
            exec l:curwindow.'wincmd w'
            return
        endif
    endif

    let l:action = GetAction(a:direction)
    exec l:action.a:amount
endfunction

" Map to buttons
nnoremap <silent> <C-w>h :call TmuxResize('h', 5)<CR>
nnoremap <silent> <C-w>j :call TmuxResize('j', 5)<CR>
nnoremap <silent> <C-w>k :call TmuxResize('k', 5)<CR>
nnoremap <silent> <C-w>l :call TmuxResize('l', 5)<CR>
" ******************************************************************************

" Plugin 'kana/vim-submode'
" ******************************************************************************
" A message will appear in the message line when you're in a submode
" and stay there until the mode has existed.
" let g:submode_always_show_submode = 1

" We're taking over the default <C-w> setting. Don't worry we'll do
" our best to put back the default functionality.
" call submode#enter_with('window', 'n', '', '<C-w>')

" Note: <C-c> will also get you out to the mode without this mapping.
" Note: <C-[> also behaves as <ESC>
" call submode#leave_with('window', 'n', '', '<ESC>')

" Go through every letter
" for key in ['a','b','c','d','e','f','g','h','i','j','k','l','m',
" \           'n','o','p','q','r','s','t','u','v','w','x','y','z']
  " maps lowercase, uppercase and <C-key>
"   call submode#map('window', 'n', '', key, '<C-w>' . key)
"   call submode#map('window', 'n', '', toupper(key), '<C-w>' . toupper(key))
"   call submode#map('window', 'n', '', '<C-' . key . '>', '<C-w>' . '<C-'.key . '>')
" endfor
" Go through symbols. Sadly, '|', not supported in submode plugin.
" for key in ['=','_','+','-','<','>']
"   call submode#map('window', 'n', '', key, '<C-w>' . key)
" endfor

" Whenever you type any key which is not mapped in the current submode,
" it causes to leave from the submode
"let g:submode_keep_leaving_key = 1

" Resize faster
"call submode#map('window', 'n', '', 'j', ':call TmuxResize(''j'', 5)<CR>')
"call submode#map('window', 'n', '', 'k', ':call TmuxResize(''k'', 5)<CR>')
"call submode#map('window', 'n', '', 'h', ':call TmuxResize(''h'', 5)<CR>')
"call submode#map('window', 'n', '', 'l', ':call TmuxResize(''l'', 5)<CR>')
" ******************************************************************************

" Replace C-n/p for C-j/k on pumvisible menus for nvim
" ******************************************************************************
" CONFLICT WITH ULTISNIPT BINDING
"inoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
"inoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"
"cnoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<C-j>"
"cnoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<C-k>"
" ******************************************************************************

"Move lines with movement
" ******************************************************************************
function! s:swap_lines(n1, n2)
    let line1 = getline(a:n1)
    let line2 = getline(a:n2)
    call setline(a:n1, line2)
    call setline(a:n2, line1)
endfunction

function! s:swap_up()
    let n = line('.')
    if n == 1
        return
    endif

    call s:swap_lines(n, n - 1)
    exec n - 1
  endfunction

function! s:swap_down()
    let n = line('.')
    if n == line('$')
        return
    endif

    call s:swap_lines(n, n + 1)
    exec n + 1
endfunction

"noremap <silent> <S-K> :call <SID>swap_up()<CR>
"noremap <silent> <S-J> :call <SID>swap_down()<CR>
noremap <leader>k :m -2<CR>
noremap <leader>j :m +1<CR>
" ******************************************************************************
" let g:calendar_diary = '~/wiki/journal'
" see calendar.vim hooks
"function MyCalAction(day, month, year, week, dir)
"    call calendar#close()
"    call append(line('.'), printf('%04d-%02d-%02d', a:year, a:month, a:day))
"endfunction
"let calendar_action = 'MyCalAction'

augroup tf
  autocmd!
  autocmd BufEnter *.tf :set foldmethod=syntax
augroup END

augroup json
  autocmd!
  autocmd BufEnter *.json :set foldmethod=syntax
augroup END
