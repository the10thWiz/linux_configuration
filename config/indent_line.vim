" Emulate IndentLine 'correctly'
" I have had a number of issues. This is a simpler (albiet probably more
" expensive) implementation of indentline. It provides indentation guides
" based on the current shiftwidth. Note that this does distiguish between
" tabs and spaces: spaces have a blue indentline, and tabs have a green
" indent guide. This does not handle mixed tabs and spaces at all (it will
" only hightlight spaces at the beginning of the line, although tabs will be
" hightlighted anywhere they appear).

set tabstop=2
" Tabs will start with |
set list
set listchars=tab:\⎸\ 

set conceallevel=1
set concealcursor=nvic

" Disable automatic shiftwidth calculation, since I can't rely on it to
" raise an OptionSet event - I will be automatically calling it myself
let g:slueth_automatic = 1

function! s:applyIndentLine(new_buffer)
  " call vim-sleuth to calculate correct shiftwidth
  if a:new_buffer
    execute get(g:, 'IndentLineDetect', 'Sleuth')
  endif
  if exists('w:IndentPatternSpaceId')
    call matchdelete(w:IndentPatternSpaceId)
    unlet w:IndentPatternSpaceId
  endif
  if exists('w:IndentPatternTabId')
    call matchdelete(w:IndentPatternTabId)
    unlet w:IndentPatternTabId
  endif
  let pattern = '\(^\( \{' . &shiftwidth . '\}\)\+\)\@<= \( \{' . (&shiftwidth - 1) . '\}\)\@='
  let w:IndentPatternSpaceId = matchadd('Conceal', pattern, 10, -1, {'conceal': '⎸'})
  let pattern = '\(^\t\+\)\@<=\t'
  let w:IndentPatternTabId = matchadd('GruvBoxGreen', pattern, 10, -1)
endfunction

command! IndentLineDetect call <SID>applyIndentLine(v:false)

augroup IndentLine
  au!
  "autocmd OptionSet shiftwidth call ApplyIndentLine()
  autocmd Filetype * call s:applyIndentLine(v:true)
  autocmd BufWinEnter * call s:applyIndentLine(v:false)
augroup END
