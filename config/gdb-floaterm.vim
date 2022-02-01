
"let g:min_gdb_width = 40

function! s:get_cmd(cmd)
  let gdb = 'gdb'
  if &filetype == 'rust'
    let gdb = 'rust-gdb'

    let built_file = g:WorkspaceFolders[0] . '/target/debug' . matchstr(g:WorkspaceFolders[0], '/[^/]*$')
    return gdb . ' --readnow --args ' . built_file . ' ' . a:cmd
  endif
  if empty(a:cmd)
    return gdb
  else
    return gdb . ' --readnow --args ' . a:cmd
  endif
endfunction

" BreakPoint Logic
" group 'gdb_pending_breakpoints' is the list of breakpoints we are aware of
"   that gdb isn't. If gdb is running, this should be empty
" group 'gdb_breakpoints' is the list of breakpoints gdb is aware of. These
"   are only added in response to gdb lines

function! ToggleBreakpoint()
  let file = expand('%')
  let line = line('.')
  let id = s:CheckBreakPointDefined(file, line)
  if id == -1
    if !s:gdb_job.send_cmd('-break-insert ' . file . ':' . line)
      call sign_place(0, 'gdb_pending_breakpoints', 'gdb_breakpoint', file, {'lnum': line, 'priority': 10})
    endif
  else
    call sign_unplace('gdb_pending_breakpoints', {'id': id})
    call sign_unplace('gdb_breakpoints', {'id': id})
    for [gdb_id, sign_id] in items(s:gdb_job.breakpoints)
      if sign_id == id
        call s:gdb_job.send_cmd('-break-delete ' . gdb_id)
        call remove(s:gdb_job.breakpoints, gdb_id)
        break
      endif
    endfor
  endif
endfunction

function! s:CheckBreakPointDefined(file, line)
  for buffer in sign_getplaced(a:file, {'lnum': a:line, 'group': '*'})
    for sign in buffer.signs
      "call add(cmds, 'break ' . bufname(buffer.bufnr) . ':' . sign.lnum)
      if sign.group == 'gdb_pending_breakpoints' || sign.group == 'gdb_breakpoints'
        return sign.id
      endif
    endfor
  endfor
  return -1
endfunction

" TODO: remove
function! SetBreakPoint()
  if !s:gdb_job.send_cmd('-break-insert ' . expand('%') . ':' . line('.'))
    echo "Gdb is not open"
    "call add(s:gdb_job.pending_breakpoints, '-break-insert ' . expand('%') . ':' . line('.'))
  endif
  "let gdb_window = floaterm#terminal#get_bufnr('gdb')
  "if gdb_window != -1
    "let br = 'break ' . expand('%') . ':' . line('.')
    "call floaterm#terminal#send(gdb_window, [br])
  "else
    "if !s:CheckBreakPointDefined(line('.'))
      "call sign_place(0, 'breakpoints', 'debugging_breakpoint', expand('%'), {'lnum': line('.'), 'priority': 0})
    "endif
  "endif
endfunction

let s:gdb_job = {
      \ 'cur': '',
      \ 'lines': [],
      \ 'id': -1,
      \ 'term_id': -1,
      \ 'pty': v:true,
      \ 'breakpoints': {},
      \ 'curline': 0,
      \ 'bufnr': -1,
      \ 'winnr': -1,
      \ 'focus': v:false,
      \}

function s:gdb_job.parse_lines()
  for line in self.lines
    if line == ''
      " Empty line
    elseif line =~ '^=breakpoint-deleted'
      let number = matchlist(line, 'id="\([^"]*\)"')[1]
      call sign_unplace('gdb_breakpoints', {'id': self.breakpoints[number]})
      call sign_unplace('gdb_pending_breakpoints', {'id': self.breakpoints[number]})
      unlet self.breakpoints[number]
    elseif line =~ '^=breakpoint-created' || line =~ '^=breakpoint-modified' || line =~ '^\^done,bkpt='
      let number = matchlist(line, 'number="\([^"]*\)"')[1]
      let pending = matchlist(line, 'pending="\([^"]*\)"')
      if !empty(pending)
        let [file, lnum] = split(pending[1], ':')
      else
        let file = matchlist(line, 'file="\([^"]*\)"')[1]
        let lnum = matchlist(line, 'line="\([^"]*\)"')[1]
      endif
      if has_key(self.breakpoints, number)
        let id = self.breakpoints[number]
      else
        let id = 0
      endif
      let self.breakpoints[number] = sign_place(id, 'gdb_breakpoints', 'gdb_breakpoint', file, {'lnum': lnum, 'priority': 10})
    elseif line =~ '*stopped'
      if match(line, 'frame=') >= 0
        let file = matchlist(line, 'fullname="\([^"]*\)"')[1]
        if match(file, '/rustc') == 0
          continue
        endif
        let lnum = matchlist(line, 'line="\([^"]*\)"')[1]
        if nvim_get_current_win() == self.winnr
          let self.focus = v:true
        else
          let self.focus = v:false
        endif
        exec 'tab drop +' . lnum . ' ' . file
        call sign_unplace('gdb_status', {'id': self.curline})
        let self.curline = sign_place(0, 'gdb_status', 'gdb_curline', file, {'lnum': lnum, 'priority': 20})
        call sign_jump(self.curline, 'gdb_status', file)
        if self.focus
          call nvim_set_current_win(self.winnr)
        endif
      else
        call sign_unplace('gdb_status', {'id': self.curline})
        let self.curline = 0
      endif
    elseif line[0] == '~' || line[0] == '@' || line[0] == '&'
      " console output
    elseif line[0] == '^'
      " Result Records
    elseif line[0] == '=' || line[0] == '*'
      " Async Records
    elseif line =~ '(gdb)'
      " ready for input
      call self.restore()
    else
    endif
  endfor
  let self.lines = []
endfunction

function s:gdb_job.on_stdout(_id, data, _event)
  let self.cur .= a:data[0]
  if !empty(self.cur)
    call add(self.lines, self.cur)
    let self.cur = ''
  endif
  call extend(self.lines, a:data[1:])
  call self.parse_lines()
endfunction

function s:gdb_job.on_stderr(_id, data, _event)
endfunction

function s:on_exit(_id, code, _event)
  call jobstop(s:gdb_job.id)
  exec 'bdelete! ' . s:gdb_job.bufnr
  let s:gdb_job.id = -1
  let s:gdb_job.term_id = -1
  call s:gdb_job.save_status()
endfunction

function! s:gdb_job.restore()
  for bufname in nvim_list_bufs()
    for buffer in sign_getplaced(bufname, {'group': 'gdb_pending_breakpoints'})
      for sign in buffer.signs
        call self.send_cmd('-break-insert ' . bufname(buffer.bufnr) . ':' . sign.lnum)
      endfor
    endfor
  endfor
  call sign_unplace('gdb_pending_breakpoints')
endfunction

function! s:gdb_job.save_status()
  for bufname in nvim_list_bufs()
    for buffer in sign_getplaced(bufname, {'group': 'gdb_breakpoints'})
      for sign in buffer.signs
        call sign_place(0, 'gdb_pending_breakpoints', 'gdb_breakpoint', buffer.bufnr, {'lnum': sign.lnum, 'priority': 10})
      endfor
    endfor
  endfor
  call sign_unplace('gdb_breakpoints')
  let self.breakpoints = {}
endfunction

function! s:gdb_job.tab_enter()
  if self.winnr != -1
    if nvim_win_is_valid(self.winnr)
      if nvim_win_get_tabpage(self.winnr) != nvim_get_current_tabpage()
        call nvim_win_close(self.winnr, v:true)
        let other_win = win_getid()
        call s:OpenWindow()
        let self.winnr = win_getid()
        call nvim_win_set_buf(0, self.bufnr)
      endif
    endif
  endif
endfunction

augroup GDB_TABPAGE
  autocmd BufEnter * call s:gdb_job.tab_enter()
augroup END

function s:gdb_job.send_cmd(cmd)
  if self.id != -1
    call chansend(self.id, [a:cmd, ''])
    return 1
  else
    return 0
  endif
endfunction

function! s:OpenWindow()
  if get(g:, 'gdb_vertical', v:true)
    let min_gdb_width = get(g:, 'min_gdb_width', 40)
    let sign_col_width = get(g:, 'sign_col_width', 2)
    let width = max([winwidth(0) - &colorcolumn - &number * 3 - sign_col_width, min_gdb_width])
    exec 'botright' . width . 'vnew'
  else
    botright new
  endif
endfunction

function! OpenGdbMi3(cmd)
  if s:gdb_job.id == -1
    call s:OpenWindow()
    let s:gdb_job.bufnr = bufnr()
    let s:gdb_job.winnr = win_getid()
    let s:gdb_job.id = jobstart('tail -f /dev/null', s:gdb_job)
    let pty = nvim_get_chan_info(s:gdb_job.id)['pty']
    let gdb_cmd = 'rust-gdb '
    let gdb_cmd .= '-ex "new-ui mi3 ' . pty . '" '
    let gdb_cmd .= '--args ' . a:cmd
    let s:gdb_job.term_id = termopen(gdb_cmd, {'on_exit': function('s:on_exit')})
    setlocal nonumber
    setlocal norelativenumber
    setlocal signcolumn=no
    setlocal statusline=\ GDB\ Debugger\ 
    startinsert
  else
    exec 'buffer ' . s:gdb_job.bufnr
  endif
endfunction

" TODO: remove
function! Inspect()
  return s:gdb_job
endfunction

call sign_define('gdb_curline', {'text': '=>'})
call sign_define('gdb_breakpoint', {'text': ' !'})

command! -nargs=* Debug  call OpenGdbMi3(<q-args>)
command! DebugStep       call s:gdb_job.send_cmd('-exec-step')
command! DebugNext       call s:gdb_job.send_cmd('-exec-next')
command! DebugFinish     call s:gdb_job.send_cmd('-exec-finish')
command! DebugContinue   call s:gdb_job.send_cmd('-exec-continue')
command! DebugRun        call s:gdb_job.send_cmd('-exec-run')
command! DebugBreak      call ToggleBreakpoint()

