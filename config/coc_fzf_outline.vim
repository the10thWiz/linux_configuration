
let s:prompt = 'Coc Outline> '

function! OutlineRun(...) abort
  "call coc_fzf#common#log_function_call(expand('<sfile>'), a:000)
  let expect_keys = coc_fzf#common#get_default_file_expect_keys()
  let opts = {
        \ 'source': s:get_outline(a:000),
        \ 'sink*': function('s:symbol_handler'),
        \ 'options': ['--multi','--expect='.expect_keys,
        \ '--ansi', '--prompt=' . s:prompt] + g:coc_fzf_opts,
        \ }
  call fzf#run(fzf#wrap(opts))
endfunction

function! s:format_coc_outline(item, kind_filter) abort
  let match = matchlist(a:item.label, '^\(\(| \)*\)\(.*\)\s\+\[\([^\[\]]*\)\].*')[1:4]
  if empty(match)
    return ''
  endif
  let level = match[0]
  let text = match[2]
  let kind = match[3]
  let line = a:item.location.range.start.line + 1
  let col = a:item.location.range.start.character + 1
  if !empty(a:kind_filter) && a:kind_filter != kind
    return ''
  endif
  return printf('%s%s %s %s%s',
        \ coc_fzf#common_fzf_vim#green(level, 'Comment'),
        \ text,
        \ coc_fzf#common_fzf_vim#yellow('[' . kind . ']', 'Typedef'),
        \ coc_fzf#common_fzf_vim#green(line, 'Comment'),
        \ coc_fzf#common_fzf_vim#black(',' . col, 'Ignore'))
endfunction

function! s:get_outline(args_list) abort
  " parse arguments
  let args = a:args_list[:-2] " remove range
  "   --kind <kind>
  let kind = ''
  let kind_idx = index(args, '--kind')
  if kind_idx >= 0
    if len(args) < kind_idx+2
      call coc_fzf#common#echom_error('Missing kind argument')
      return
    endif
    let kind = args[l:kind_idx+1]
    call remove(args, l:kind_idx, l:kind_idx+1)
  endif
  " get outline
  let outline = CocAction('listLoadItems', 'outline')
  let ret = []
  let cur = ""
  for line in outline
    if !empty(line)
      let lst = matchlist(line.label, '^\(impl \)\?\i\+')
      if len(lst) > 0
        if match(lst[0], '^impl') == 0
          let cur = substitute(lst[0], '^\(impl\s*\)\?', '| ', '') . '::'
        else
          let cur = substitute(lst[0], '^\(impl\s*\)\?', '| ', '') . '.'
        endif
      endif
      let line.label = substitute(line.label, '| ', cur, '')
      let ret = ret + [s:format_coc_outline(line, kind)]
    endif
  endfor
  return ret
endfunction

function! s:symbol_handler(sym) abort
  if empty(a:sym)
    return
  endif
  let parsed_dict_list = s:parse_symbol(a:sym[1:])
  call coc_fzf#common#process_file_action(a:sym[0], parsed_dict_list)
endfunction

function! s:parse_symbol(sym) abort
  let parsed_dict_list = []
  for str in a:sym
    let parsed_dict = {}
    let match = matchlist(str, '^\s*\(.* \[[^[]*\]\) \(\d\+\),\(\d\+\)')[1:3]
    if empty(match) || empty(l:match[0])
      return
    endif
    let parsed_dict['filename'] = expand('%:p')
    let parsed_dict['text'] = match[0]
    let parsed_dict['lnum'] = match[1]
    let parsed_dict['col'] = match[2]
    let parsed_dict_list += [parsed_dict]
  endfor
  return parsed_dict_list
endfunction
