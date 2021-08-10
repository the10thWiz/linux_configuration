let mapleader = ' '
set mouse=nvichar

augroup startup
  autocmd!
  " Called after startup
  autocmd VimEnter * call Init()
augroup END

" g:autocd can be set by adding `-c 'let g:autocd = v:true'` to command used
function! Init()
  if get(g:, 'autocd', v:false) && argv() == []
    cd ~/Documents
  endif
  if get(g:, 'WorkspaceFolders', []) == []
    let g:WorkspaceFolders = [floaterm#path#get_root()]
  endif
endfunction

function! Focus(sleep)
  if getenv('KITTY_LISTEN_ON') != v:null
    if a:sleep
      sleep 400 m
    endif
    silent ! kitty @ focus-window
    return v:true
  else
    return v:false
  endif
endfunction

set termguicolors
set colorcolumn=101
set switchbuf=usetab

augroup LogProtect
  au!
  autocmd BufReadPost,FileReadPost,FilterReadPost,StdinReadPost *.log setlocal readonly | setlocal nomodifiable
augroup END

" Plugins will be downloaded under the specified directory.
call plug#begin('~/.vim/plugged')

" Declare the list of plugins.
Plug 'junegunn/fzf', {'dir': '~/.fzf','do': './install --all'}
Plug 'junegunn/fzf.vim' " needed for previews

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'antoinemadec/coc-fzf'

Plug 'ryanoasis/vim-devicons'
Plug 'scrooloose/nerdcommenter'

"Plug 'christoomey/vim-tmux-navigator'

" Color scheme
Plug 'morhetz/gruvbox'

Plug 'HerringtonDarkholme/yats.vim' " TS Syntax

Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
"Plug 'tpope/vim-endwise'

Plug 'tpope/vim-characterize'
Plug 'tpope/vim-sleuth'

" Cargo commands
Plug 'timonv/vim-cargo'

" Vimspector
Plug 'puremourning/vimspector'

" Floaterm
Plug 'voldikss/vim-floaterm'

" Remember the last location when reopening files
Plug 'farmergreg/vim-lastplace'

" Template files
Plug 'aperezdc/vim-template'

" Ghost server for firefox functionality
Plug 'raghur/vim-ghost', {'do': ':GhostInstall'}

Plug 'chrisbra/Colorizer'

" Reverse the order of commits in a rebase
Plug 'salcode/vim-interactive-rebase-reverse'

" List ends here. Plugins become visible to Vim after this call.
call plug#end()

"source /home/matt/Documents/hex_edit/plugin/hexedit.vim

" Fzf config

let g:fzf_buffers_jump = 1
let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.6 } }
let g:fzf_history_dir = '~/.local/share/fzf-history'
let g:fzf_colors =
\ { 'fg':    ['fg', 'Normal'],
  \ 'bg':    ['bg', 'Normal'],
  \ 'hl':    ['fg', 'Comment'],
  \ 'fg+':    ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':    ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':    ['fg', 'Statement'],
  \ 'info':   ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }
let g:fzf_action = {
  \ 'enter': 'tab drop',
  \ 'ctrl-t': 'tab drop',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

"command! GitFzf call fzf#run(fzf#wrap({'source': 'git ls-files', 'dir': GetGitRoot()}))
"function! FzfNetrwReplace()
  "let buf = 
"endfunction

augroup fzfcommands
  autocmd!
  " Work around to map <Esc> to quit, also handles when the window loses
  " focus
  autocmd FileType fzf autocmd TermLeave <buffer> q
  "autocmd FileType netrw call FzfNetrwReplace()
augroup END

function! OpenError()
  let pos = getcurpos()
  let line = getbufline(bufnr(), pos[1])[0]
  let match_info = matchstrpos(line, '\f\+')
  while match_info[2] < pos[2] && match_info[2] != -1
    let match_info = matchstrpos(line, '\f\+', match_info[2])
  endwhile
  if match_info[1] <= pos[2] && match_info[2] >= pos[2]
    let pos = matchlist(line, ':\(\d\+\)', match_info[2])
    FloatermHide
    if match(match_info[0], '/') == 0
      let prefix = ''
    else
      let prefix = get(g:, 'WorkspaceFolders', [getcwd()])[0] . '/'
    endif
    if len(pos) >= 1 && pos[1] != ''
      execute 'tab drop +' . pos[1] . ' ' . prefix . match_info[0]
    else
      execute 'tab drop ' . prefix . match_info[0]
    endif
  endif
endfunction

nmap <leader>o :call OpenError()<CR>

" Required for operations modifying multiple buffers like rename.
set hidden

" vimspector
let g:vimspector_enable_mappings = 'HUMAN'

" navigate chunks of current buffer
nmap [h <Plug>(coc-git-prevchunk)
nmap ]h <Plug>(coc-git-nextchunk)
" navigate conflicts of current buffer
nmap [c <Plug>(coc-git-prevconflict)
nmap ]c <Plug>(coc-git-nextconflict)
" show chunk diff at current position
nmap gs <Plug>(coc-git-chunkinfo)
" show commit contains current position
nmap gc <Plug>(coc-git-commit)
" create text object for git chunks
omap ig <Plug>(coc-git-chunk-inner)
xmap ig <Plug>(coc-git-chunk-inner)
omap ag <Plug>(coc-git-chunk-outer)
xmap ag <Plug>(coc-git-chunk-outer)

nmap <Leader>gs :CocCommand git.chunkStage<CR>
nmap <Leader>gu :CocCommand git.chunkUndo<CR>
nmap <Leader>gf :CocCommand git.foldUnchanged<CR>

function! s:gitrebasecmds()
  normal m`
  " Use `$` rather than exec or x
  " to avoid conflicting with edit
  silent! %s/^exec /$ /
  silent! %s/^x\w* /$ /
  " This has to be fixed later, in BufWritePre

  silent! %s/^p\w* /pick /
  silent! %s/^r\w* /reword /
  silent! %s/^e\w* /edit /
  silent! %s/^s\w* /squash /
  silent! %s/^f\w* /fixup /
  silent! %s/^b\w* /break /
  silent! %s/^d\w* /drop /
  silent! %s/^l\w* /label /
  silent! %s/^t\w* /reset /
  silent! %s/^m\w* /merge /
  silent! %s/^n\w* /noop /
  normal ``
endfunction

augroup gitrebase
  au!
  autocmd FileType gitrebase au! gitrebase InsertLeave
  autocmd FileType gitrebase au InsertLeave <buffer> call <SID>gitrebasecmds()
  autocmd FileType gitrebase au! gitrebase TextChanged
  autocmd FileType gitrebase au TextChanged <buffer> call <SID>gitrebasecmds()
  autocmd FileType gitrebase au! gitrebase BufWritePre
  autocmd FileType gitrebase au BufWritePre <buffer> silent! %s/^\$ /exec /
augroup END

function! s:open(name)
  let list = reverse(split(a:name))
  for name in list
    if bufnr(name) != -1
      execute 'tab drop ' . name
      return
    endif
  endfor
endfunction
"nmap <Leader>y :CocList yank<CR>
"nmap <leader>b :Buffers<cr>
nmap <leader>b :call fzf#vim#buffers({'sink': function('<SID>open')})<cr>
nmap <Leader>e :GitFiles<CR>
nmap <expr> <Leader>pe ':Files ' . get(g:, 'WorkspaceFolders', [getcwd()])[0] . '<CR>'

command! MdFmt normal ^79lwhr<lt>CR>J

nnoremap <leader>i :MdFmt<CR>

" coc-actions
" Remap for do codeAction of selected region
function! s:cocActionsOpenFromSelected(type) abort
  execute 'CocCommand actions.open ' . a:type
endfunction
xmap <silent> <leader>k :<C-u>execute 'CocCommand actions.open ' . visualmode()<CR>

" coc-calc
" append result on current expression
nmap <Leader>xa <Plug>(coc-calc-result-append)
" replace result on current expression
nmap <Leader>xr <Plug>(coc-calc-result-replace)

map <silent> <leader>a :<C-u>set operatorfunc=<SID>cocActionsOpenFromSelected<CR>g@

vmap <Leader>/ <plug>NERDCommenterToggle
nmap <Leader>/ <plug>NERDCommenterToggle

let g:NERDCustomDelimiters = {
    \ 'rust': { 'left': '//', 'leftAlt': '/*', 'rightAlt': '*/' },
  \ }

" j/k will move virtual lines (lines that wrap)
noremap <silent> <expr> j (v:count == 0 ? 'gj' : 'j')
noremap <silent> <expr> k (v:count == 0 ? 'gk' : 'k')

set relativenumber
set number

colorscheme gruvbox

" coc config
let g:coc_global_extensions = [
  \ 'coc-snippets',
  \ 'coc-lists',
  \ 'coc-yank',
  \ 'coc-git',
  \ 'coc-pairs',
  \ 'coc-tsserver',
  \ 'coc-eslint', 
  \ 'coc-prettier', 
  \ 'coc-json', 
  \ 'coc-discord-rpc',
  \ 'coc-calc',
  \ 'coc-actions',
  \ 'coc-rust-analyzer',
  \ 'coc-markdownlint',
  \ 'coc-java-debug',
  \ 'coc-java',
  \ 'coc-texlab',
  \ 'coc-python',
  \ 'coc-yaml',
  \ 'coc-html',
  \ 'coc-elixir',
\ ]

" from readme
" if hidden is not set, TextEdit might fail.
set hidden " Some servers have issues with backup files, see #649 set nobackup set nowritebackup " Better display for messages set cmdheight=2 " You will have bad experience for diagnostic messages when it's default 4000.
set updatetime=300

" don't give |ins-completion-menu| messages.
set shortmess+=c

" always show signcolumns
set signcolumn=yes:1

" Use tab for trigger completion with characters ahead and navigate.
" Use command ':verbose imap <tab>' to make sure tab is not mapped by other plugin.
inoremap <silent><expr> <TAB>
  \ pumvisible() ? "\<C-n>" :
  \ <SID>check_back_space() ? "\<TAB>" :
  \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion.
inoremap <silent><expr> <c-space> coc#refresh()

" Use <cr> to confirm completion, `<C-g>u` means break undo chain at current position.
" Coc only does snippet and additional edit on confirm.
inoremap <silent><expr> <cr> pumvisible() ? coc#_select_confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
" Or use `complete_info` if your vim support it, like:
" inoremap <expr> <cr> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-g>u\<CR>"

" Use `[g` and `]g` to navigate diagnostics
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" Remap keys for gotos
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Use K to show documentation in preview window
nnoremap <silent> K :call <SID>show_documentation()<CR>

" use <leader>d to add a debug macro to rust code
vmap <leader>d cdbg!()<esc>P

" Remap tab & shift+tab to change indent by one

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

let g:tool_tip_buffer = -1
let g:tool_tip_window = -1

function! TestWin(text)
  if g:tool_tip_buffer == -1
    let g:tool_tip_buffer = nvim_create_buf(v:false, v:true)
    call nvim_buf_set_lines(g:tool_tip_buffer, 0, 0, v:true, [a:text])
  endif
  "let [row, col] = nvim_win_get_cursor(0)
  let win_pos = nvim_win_get_cursor(0)
  let win_pos[0] = win_pos[0] - 1
  let row_p = win_pos[0]
  let col_p = 1
  if g:tool_tip_window == -1
    let opts = {'relative': 'win', 'width': 10, 'height': 1, 'bufpos': win_pos,
      \ 'anchor': 'NW', 'style': 'minimal'}
    let g:tool_tip_window = nvim_open_win(g:tool_tip_buffer, 0, opts)
    "call nvim_win_set_option(g:tool_tip_window, 'winhl', 'CocHintFloat')
  else
    let opts = {'relative': 'win', 'row': row_p, 'col': col_p}
    call nvim_win_set_config(g:tool_tip_window, opts)
  endif
endfunction
function! ResetWin() 
  let g:tool_tip_window = -1
  let g:tool_tip_buffer = -1
endfunction

" Highlight symbol under cursor on CursorHold
autocmd CursorHold * silent call CocActionAsync('highlight')

" Remap for rename current word
nmap <leader>r <Plug>(coc-rename)

" Remap for format selected region
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " Setup formatexpr specified filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

xmap <leader>a  :CocFzfList actions<CR>
nmap <leader>a  :CocFzfList actions<CR>

" Fix autofix problem of current line
nmap <leader>qf  <Plug>(coc-fix-current)

" Create mappings for function text object, requires document symbols feature of languageserver.
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

" Use <C-d> for select selections ranges, needs server support, like: coc-tsserver, coc-python
nmap <silent> <C-d> <Plug>(coc-range-select)
xmap <silent> <C-d> <Plug>(coc-range-select)

" Use `:Format` to format current buffer
command! -nargs=0 Format :call CocAction('format')

" Use `:Fold` to fold current buffer
command! -nargs=? Fold :call CocAction('fold', <f-args>)

" use `:OR` for organize import of current buffer
command! -nargs=0 OR :call CocAction('runCommand', 'editor.action.organizeImport')

" Floaterm Config
let g:floaterm_title=''
let g:floaterm_wintype='floating'
let g:floaterm_width=0.7
let g:floaterm_height=0.7
let g:floaterm_position='top'
let g:floaterm_rootmarkers=['.git', 'Cargo.lock', 'build.gradle']
let g:floaterm_opener='tabe'
let g:floaterm_autoclose=2
let g:floaterm_autoinsert=v:true
let g:floaterm_borderchars=[' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ']

" Set floaterm window's background to black
hi Floaterm guibg=#000000 ctermbg=0

hi link FloatermBorder CursorColumn

function! StartFloatermSilently(name, params) abort
  exec 'FloatermNew --name='. a:name . ' --cwd=<root> ' . a:params . ' zsh'
  call timer_start(1, {-> execute('FloatermHide! ' . a:name)})
endfunction

function! FloatermCommand(cmd)
  FloatermHide q
  execute 'FloatermSend --name=q ' . a:cmd
  FloatermShow q
endfunction

function! FloatermRun(build)
  if a:build
    let cmd = floatmake#buildcmd()
  else
    let cmd = floatmake#runcmd()
  endif
  if cmd != ''
    call FloatermCommand(cmd)
  endif
endfunction

command! Build call FloatermRun(v:true)
command! Run call FloatermRun(v:false)
noremap <A-b> <Cmd>Build<CR>
tnoremap <A-b> <Cmd>Build<CR>
noremap <A-r> <Cmd>Run<CR>
tnoremap <A-r> <Cmd>Run<CR>

augroup Term
  autocmd!
  autocmd VimEnter * call StartFloatermSilently('q', '')
  autocmd VimEnter * call StartFloatermSilently('w', '--position=bottom')
augroup END

tnoremap <Esc> <C-\><C-N>
tnoremap <M-[> <Esc>

noremap <A-q>  <Cmd>FloatermHide w<CR><Cmd>FloatermToggle q<CR>
tnoremap <A-q> <Cmd>FloatermHide w<CR><Cmd>FloatermToggle q<CR>
noremap <A-w>  <Cmd>FloatermHide q<CR><Cmd>FloatermToggle w<CR>
tnoremap <A-w> <Cmd>FloatermHide q<CR><Cmd>FloatermToggle w<CR>

tnoremap <A-j> <C-\><C-N><C-w>j
tnoremap <A-k> <C-\><C-N><C-w>k
tnoremap <A-h> <C-\><C-N><C-w>h
tnoremap <A-j> <C-\><C-N><C-w>j
noremap <A-j> <Esc><C-w>j
noremap <A-k> <Esc><C-w>k
noremap <A-h> <Esc><C-w>h
noremap <A-j> <Esc><C-w>j
inoremap <A-k> <Esc><C-w>k
inoremap <A-h> <Esc><C-w>h
inoremap <A-l> <Esc><C-w>l
inoremap <A-j> <Esc><C-w>j

" Using CocList
" Show all diagnostics
"nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" Manage extensions
"nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" Show commands
nnoremap <silent> <space>c  :<C-u>CocFzfList commands<cr>
" Find symbol of current document
"nnoremap <silent> <space>o  :<C-u>CocFzfList outline<cr>
" Search workspace symbols
nnoremap <silent> <space>s  :<C-u>call OutlineRun()<cr>
" Do default action for next item.
"nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" Do default action for previous item.
"nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" Resume latest coc list
nnoremap <silent> <space>p  :<C-u>CocFzfListResume<CR>

hi User1 ctermbg=108 guibg=#282828 ctermfg=235 guifg=#ebdbb2
hi User2 ctermbg=108 guibg=#fb4934 ctermfg=235 guifg=#282828
hi User3 ctermbg=108 guibg=#b8bb26 ctermfg=235 guifg=#282828
hi User4 ctermbg=108 guibg=#fabd2f ctermfg=235 guifg=#282828
hi User5 ctermbg=108 guibg=#83a598 ctermfg=235 guifg=#282828
hi User6 ctermbg=108 guibg=#d3869b ctermfg=235 guifg=#282828
hi User7 ctermbg=108 guibg=#8ec07c ctermfg=235 guifg=#282828
hi User8 ctermbg=108 guibg=#fe8019 ctermfg=235 guifg=#282828
hi User9 ctermbg=108 guibg=#ebdbb2 ctermfg=235 guifg=#282828

set statusline=
set statusline+=\ %3*\ %y\ %{get(g:,'coc_git_status','')}%{get(b:,'coc_git_status','')}%{get(b:,'coc_git_blame','')}\ %*
set statusline+=\ \ %7*\ %t\ %*
set statusline+=\ \ %5*\ XX\ %*
set statusline+=\ \ %6*\ %{coc#status()}%{get(b:,'coc_current_function','')}\ %*
set statusline+=\ \ %=(%l,%c)\ U+%04B\ 
