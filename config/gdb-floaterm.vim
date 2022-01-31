
let g:min_gdb_width = 40

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

function! s:CheckBreakPointDefined(line)
  for buffer in sign_getplaced(expand('%'), {'group': 'breakpoints'})
    for sign in buffer.signs
      "call add(cmds, 'break ' . bufname(buffer.bufnr) . ':' . sign.lnum)
      if sign.lnum == a:line
        return v:true
      endif
    endfor
  endfor
  return v:false
endfunction

function! BreakPoint()
  if !s:gdb_job.send_cmd('-break-insert ' . expand('%') . ':' . line('.'))
    echo "Gdb is not open"
    call add(s:gdb_job.pending_breakpoints, '-break-insert ' . expand('%') . ':' . line('.'))
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

let s:gdb_job = {'cur': '', 'lines': [], 'id': -1, 'term_id': -1, 'pty': v:true, 'breakpoints': {}, 'pending_breakpoints': []}
function s:gdb_job.parse_lines()
  for line in self.lines
    if line == ''
      " Empty line
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
      let self.breakpoints[number] = sign_place(id, 'breakpoints', 'debugging_breakpoint', file, {'lnum': lnum, 'priority': 0})
    elseif line[0] == '~' || line[0] == '@' || line[0] == '&'
      " console output
    elseif line[0] == '^'
      " Result Records
    elseif line[0] == '=' || line[0] == '*'
      " Async Records
    elseif line =~ '(gdb)'
      " ready for input
      for br in self.pending_breakpoints
        call self.send_cmd(br)
      endfor
      let self.pending_breakpoints = []
    else
    endif
      call appendbufline(self.bufnr, '$', line)
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
function s:gdb_job.on_exit(_id, code, _event)
  let s:gdb_job.id = -1
endfunction

function s:gdb_job.send_cmd(cmd)
  if self.id != -1
    call chansend(self.id, [a:cmd, ''])
    return v:true
  else
    return v:false
  endif
endfunction

function! OpenGdbMi3(cmd)
  if s:gdb_job.id == -1
    let s:gdb_job.bufnr = bufnr()
    new
    let s:gdb_job.id = jobstart('tail -f /dev/null', s:gdb_job)
    let pty = nvim_get_chan_info(s:gdb_job.id)['pty']
    let s:gdb_job.term_id = termopen('rust-gdb -ex "new-ui mi3 ' . pty . '" ' . a:cmd, {})
    "call s:gdb_job.send_cmd('')
  endif
endfunction

function! Inspect()
  return s:gdb_job
endfunction

function! OpenGdb(cmd)
  " Sadly, Neovim doesn't let us get the current signcolumn width, so I've
  " just hardcoded 2 - It matches my signcolumn of `yes:1`, but it's not great
  let width = max([winwidth(0) - &colorcolumn - &number * 3 - 2, g:min_gdb_width])
  let gdb_window = floaterm#terminal#get_bufnr('gdb')
  let cur_filetype = &filetype
  if gdb_window == -1
    let cmd = s:get_cmd(a:cmd)
    let gdb_window = floaterm#new(v:false, cmd, {
      \ 'on_exit': function('<SID>ClearSigns'),
      \ }, {
      \ 'wintype': 'vsplit',
      \ 'width': width,
      \ 'position': 'right',
      \ 'name': 'gdb',
      \ 'title': 'Gnu DeBugger ' . matchstr(a:cmd, '/\w '),
      \ 'silent': v:true,
      \ })

    if cur_filetype == 'rust'
      let CargoJob = {'json': ''}
      function CargoJob.on_stdout(_job_id, data, _name)
        if a:data != ['']
          let self.json = self.json . join(a:data)
        else
          let dict = json_decode(self.json)
          let gdb_window = floaterm#terminal#get_bufnr('gdb')
          let cmds = []
          for buffer in sign_getplaced('', {'group': 'breakpoints'})
            for sign in buffer.signs
              call add(cmds, 'break ' . bufname(buffer.bufnr) . ':' . sign.lnum)
            endfor
          endfor
          call add(cmds, 'break ' . substitute(dict.name, '-', '_', '') . '::main')
          call add(cmds, 'run')
          call floaterm#terminal#send(gdb_window, cmds)
          call floaterm#terminal#open_existing(gdb_window)
        endif
      endfunction
      function CargoJob.on_stderr(_job_id, data, _name)
        "call input(a:data)
      endfunction
      let cargo_job = jobstart('cargo read-manifest', CargoJob)
    endif
  else
    call floaterm#show(v:false, gdb_window, 'gdb')
  endif
endfunction

call sign_define('debugging_curline', {'text': '=>'})
call sign_define('debugging_breakpoint', {'text': ' !'})
" 
" call sign_place(0, 'debugger', 'debugging_curline', buffer, {'lnum': linenr,
" 'priority': })

"let g:curline_sign = -1
let s:signs = {
  \ 'curline': -1,
  \ }

function! s:ClearSigns(...)
  call sign_unplace('debugger')
  "call sign_unplace('breakpoints')
endfunction

function! s:UpdateSign(name, buffer, line)
  call sign_unplace('debugger', {'id': s:signs[a:name]})
  let s:signs[a:name] = sign_place(0, 'debugger', 'debugging_' . a:name, a:buffer, {'lnum': a:line, 'priority': 0})
endfunction

function! Debugging(action, name)
  if a:action == 'open'
    let [name, line] = split(a:name, ':')
    exec 'tab drop ' . name
    call cursor(line, 0)
    FloatermHide
  elseif a:action == 'curline'
    let [name, line] = split(a:name, ':')
    exec 'tab drop ' . name
    call cursor(line, 0)
    call s:UpdateSign('curline', name, line)

    FloatermShow gdb
  elseif a:action == 'breakpoints'
    call sign_unplace('breakpoints')
    for [file, line] in a:name
      call sign_place(0, 'breakpoints', 'debugging_breakpoint', file, {'lnum': line, 'priority': 0})
    endfor
  else
    stopinsert
    echo 'Action ' . a:action . ' is not defined'
  endif
endfunction

command! -nargs=* Debug call OpenGdb(<q-args>)
