" Vim syntax file
" Language:	Tera templates
" Maintainer:	Matthew Pomes <the10thwiz@gmail.com>
" Last Change:	

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let filename = expand('%')
  if matchend(filename, '.html.tera') == strlen(filename)
    let main_syntax = 'html'
    runtime! syntax/html.vim
  elseif matchend(filename, '.js.tera') == strlen(filename)
    let main_syntax = 'javascript'
    runtime! syntax/javascript.vim
  elseif matchend(filename, '.css.tera') == strlen(filename)
    let main_syntax = 'css'
    runtime! syntax/css.vim
  else
    let main_syntax = ''
  endif
endif

unlet b:current_syntax

syn case match

syn match teraError "%}\|}}\|#}"

syn keyword teraStatement contained for in endfor
syn keyword teraStatement contained block endblock extends
syn keyword teraStatement contained filter endfilter
syn keyword teraStatement contained macro endmacro
syn keyword teraStatement contained raw endraw
syn keyword teraStatement contained import as include
syn keyword teraStatement contained set set_global
syn keyword teraStatement contained if elif else endif and or not is
syn keyword teraTest contained defined undefined odd even string number divisibleby iterable object
syn keyword teraTest contained starting_with ending_with containing matching 
syn keyword teraFilter contained safe filter

syn region teraString contained start=/"/ skip=/\\"/ end=/"/
syn region teraString contained start=/'/ skip=/\\'|\\\\/ end=/'/
syn keyword teraLiteral contained true True false False
syn keyword teraTodo contained todo TODO

syn region teraTagBlock start="{%" end="%}" contains=teraStatement,teraTest,teraFilter,teraAssign,@teraArgument,teraTagError display containedin=ALLBUT,@teraBlocks
syn region teraVarBlock start="{{" end="}}" contains=teraFilter,@teraArgument,teraVarError display containedin=ALLBUT,@teraBlocks
syn region teraComment start="{#" end="#}" contains=teraTodo containedin=ALLBUT,@teraBlocks

syn match teraTagError contained "#}\|{{\|[^%]}}\|[&#]"
syn match teraVarError contained "#}\|{%\|%}\|[<>!&#]"

syn match teraVar contained /[a-zA-Z][a-zA-Z0-9]*/
syn match teraNum contained /[0-9][0-9]*\.\?[0-9]*/

syn match teraAssign contained /\(\(set\|set_global\) [^=]*\)\@<==/
syn match teraOp contained /==\|<\|>\|<=\|>=\|!=\|[+*/|~]\|::\|{\@<!%}\@!/

syn cluster teraBlocks add=teraTagBlock,teraVarBlock,teraComment
syn cluster teraArgument add=teraLiteral,teraVar,teraNum,teraString,teraOp

hi def link teraTagBlock PreProc
hi def link teraVarBlock PreProc
hi def link teraStatement Statement
hi def link teraAssign Statement
hi def link teraFilter Special
hi def link teraTest Special
hi def link teraString String
hi def link teraTagError Error
hi def link teraVarError Error
hi def link teraError Error
hi def link teraComment Comment
hi def link teraTodo Todo
hi def link teraVar Identifier
hi def link teraNum Constant
hi def link teraOp Operator

let b:current_syntax = "tera"
