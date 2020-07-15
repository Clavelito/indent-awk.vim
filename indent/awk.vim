" Vim indent file
" Language:        AWK Script
" Author:          Clavelito <maromomo@hotmail.com>
" Last Change:     Wed, 15 Jul 2020 14:00:50 +0900
" Version:         1.86
"
" Description:
"                  let g:awk_indent_switch_labels = 0
"                          switch (label) {
"                          case /A/:
"
"                  let g:awk_indent_switch_labels = 1
"                          switch (label) {
"                              case /A/:
"                                                    (default: 1, disable: -1)
"
"                  let g:awk_indent_curly_braces = 0
"                          if (brace)
"                          {
"
"                  let g:awk_indent_curly_braces = 1
"                          if (brace)
"                              {
"                                                    (default: 0)
"
"                  let g:awk_indent_tail_bslash = 2
"                          function_name(  \
"                                        arg1, arg2, arg3)
"
"                  let g:awk_indent_tail_bslash = -2
"                          function_name(  \
"                              arg1, arg2, arg3)
"                                                    (default: 2, disable: 0)


if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetAwkIndent()
setlocal indentkeys=0{,},:,!^F,o,O,e,0-,0+,0/,0*,0%,0^,0=,0=**,0&,0<Bar>

let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists("*GetAwkIndent")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:before_slash1 = '[^])_a-zA-Z0-9[:blank:]]'
let s:before_slash2 = '\%(\%(^\|:\)\s*case\|\<printf\=\|\<return\)$'
let s:continue_tail = '\%(^\s*\%(case\|default\)\>.*\)\@<!:'
let s:continue_tail = '\\$\|\%(&&\|||\|,\|?\|'. s:continue_tail. '\)\s*$'

if !exists("g:awk_indent_switch_labels")
  let g:awk_indent_switch_labels = 1
endif

if !exists("g:awk_indent_curly_braces")
  let g:awk_indent_curly_braces = 0
endif

if !exists("g:awk_indent_tail_bslash")
  let g:awk_indent_tail_bslash = 2
endif

function GetAwkIndent()
  let lnum = prevnonblank(v:lnum - 1)
  if lnum == 0
    return 0
  endif

  let cline = getline(v:lnum)
  if cline =~# '^#'
    return 0
  endif

  let [line, lnum, ind] = s:ContinueLineIndent(lnum, cline)
  if line =~# s:continue_tail
    unlet! s:prev_lnum s:ncp_cnum
    return ind
  endif

  if cline =~# '^\s*else\>'
    let ind = s:CurrentElseIndent(line, lnum)
    unlet! s:prev_lnum s:ncp_cnum
    return ind
  endif

  let nnum = lnum
  let [line, lnum] = s:JoinContinueLine(line, lnum, 0)
  let [pline, pnum] = s:JoinContinueLine(line, lnum, 1)

  let ind = s:MorePrevLineIndent(pline, pnum, line, lnum)
  let ind = s:PrevLineIndent(line, lnum, nnum, ind)
  let ind = s:CurrentLineIndent(cline, line, lnum, pline, ind)
  unlet! s:prev_lnum s:ncp_cnum

  return ind
endfunction

function s:ContinueLineIndent(lnum, cline)
  let [pline, line, lnum, ind] = s:PreContinueLine(a:lnum)
  if line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|}\=\s*while\)\>'
        \ && line =~# '\\$\|\%(&&\|||\)\s*$'
        \ && s:NoClosedPair(lnum, '(', ')', lnum)
    let ind = s:GetMatchWidth(line, lnum, s:ncp_cnum)
  elseif line =~# '^\s*[*][*]=\@!.*\%(\w\|)\|\]\)\s*\\$'
    let ind += a:cline =~# '^\s*[*][*]' ? 0 : 1
  elseif line =~# '^\s*[-+/*%^]=\@!.*\%(\w\|)\|\]\)\s*\\$'
    let ind -= a:cline =~# '^\s*[*][*]' ? 1 : 0
  elseif line =~# ')' && line =~# '\\$\|\%(&&\|||\|,\)\s*$'
        \ && pline =~# '\\$\|\%(&&\|||\|,\)\s*$'
        \ && s:PairBalance(line, ')', '(') > 0
    let ind = s:NestContinueLineIndent(line, lnum, ')', '(')
  elseif line =~# '\[.*\%(\\\|,\s*\)$'
        \ && s:NoClosedPair(lnum, '\M[', '\M]', lnum)
    let ind = s:GetMatchWidth(line, lnum, s:ncp_cnum)
  elseif line =~# '\]' && line =~# '\\$\|,\s*$' && pline =~# '\\$\|,\s*$'
        \ && s:PairBalance(line, '\M]', '\M[') > 0
    let ind = s:NestContinueLineIndent(line, lnum, ']', '[')
  elseif line =~# '\<\%(function\|func\)\s\+\h\w*\s*('. s:TailBslash()
        \ && s:NoClosedPair(lnum, '(', ')', lnum)
    let ind = shiftwidth() * 2 > s:ncp_cnum || !g:awk_indent_tail_bslash
          \ ? s:ncp_cnum : shiftwidth() * 2
  elseif line =~# '('
        \ && line =~# s:continue_tail && s:NoClosedPair(lnum, '(', ')', lnum)
    let ind = s:GetMatchWidth(line, lnum, s:ncp_cnum)
  elseif line =~# '[-+/*%^]\===\@!.*\%(\w\|)\|\]\)\s*\\$'
        \ && a:cline =~# '^\s*[-+/*%^=]'
    let ind = s:GetMatchWidth(line, lnum, a:cline =~# '^\s*[*][*]' ? '.=' : '=')
  elseif line =~# '[^<>=!]==\@!'
        \ && line =~# '=\@1<!'. s:continue_tail && pline !~# s:continue_tail
    let ind = s:GetMatchWidth(line, lnum, '[^<>=!]=\s*\zs\S')
  elseif ind && line =~# '^\s\+\h\w*\s\+[^[:blank:]\\]'
        \ && line =~# '=\@1<!'. s:continue_tail && pline !~# s:continue_tail
    let ind = s:GetMatchWidth(line, lnum, '\h\w*\s\+\zs\S')
  elseif line =~# '\\$' && a:cline =~# '^\s*{'
    let ind = indent(get(s:JoinContinueLine(line, lnum, 0), 1))
  elseif ind && line =~# '=\@1<!\\$' && pline !~# s:continue_tail
    let ind += shiftwidth()
  elseif !ind && line =~# '\\$\|\%(&&\|||\)\s*$'
        \ && pline !~# '\\$\|\%(&&\|||\)\s*$'
    let ind += shiftwidth() * 2
  endif

  return [line, lnum, ind]
endfunction

function s:MorePrevLineIndent(pline, pnum, line, lnum)
  let [pline, pnum, ind] = s:PreMorePrevLine(a:pline, a:pnum, a:line, a:lnum)
  while pnum && indent(pnum) <= ind
        \ &&
        \ ((pline =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*$'
        \ || pline =~# '^\s*switch\s*(.*)\s*$'
        \ && g:awk_indent_switch_labels > -1)
        \ && s:AfterParenPairNoStr(pnum)
        \ || pline =~# '^\s*}\=\s*else\s*$'
        \ || pline =~# '^\s*do\s*$')
    let ind = indent(pnum)
    if pline =~# '^\s*do\s*$'
      break
    elseif pline =~# '^\s*}\=\s*else\>'
      let [pline, pnum] = s:GetIfLine(pline, pnum)
    endif
    let [pline, pnum] = s:JoinContinueLine(pline, pnum, 1)
  endwhile

  return ind
endfunction

function s:PrevLineIndent(line, lnum, nnum, ind)
  let ind = a:ind
  if a:line =~# '^\s*}\=\s*while\s*(.*)' && s:GetDoLine(a:lnum, 1)
  elseif a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*{\s*$'
        \ || (a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*$'
        \ || a:line =~# '^\s*switch\s*(.*)\s*$'
        \ && g:awk_indent_switch_labels > -1)
        \ && s:AfterParenPairNoStr(a:lnum)
        \ || a:line =~# '^\s*\%(}\=\s*else\|do\)\s*{\=\s*$'
        \ || a:line =~# '^\s*\%(case\|default\)\>'
        \ && g:awk_indent_switch_labels > -1
        \ || a:line =~# '^\s*{\s*$'
        \ || a:line =~# '{' && s:NoClosedPair(a:lnum, '{', '}', a:nnum)
    let ind = indent(a:lnum) + shiftwidth()
  endif

  return ind
endfunction

function s:CurrentLineIndent(cline, line, lnum, pline, ind)
  let ind = a:ind
  if a:cline =~# '^\s*}'
    let ind = s:CloseBraceIndent(a:cline, ind)
  elseif a:cline =~# '^\s*{\s*\%(#.*\)\=$' && !g:awk_indent_curly_braces
        \ &&
        \ ((a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\)\s*(.*)'
        \ || a:line =~# '^\s*switch\s*(.*)' && g:awk_indent_switch_labels > -1
        \ || a:line =~# '^\s*while\s*(.*)' && !s:GetDoLine(a:lnum, 1))
        \ && s:AfterParenPairNoStr(a:lnum)
        \ || a:line =~# '^\s*\%(}\=\s*else\|do\)\s*$')
    let ind -= shiftwidth()
  elseif a:cline =~# '^\s*\%(case\|default\)\>'
        \ && g:awk_indent_switch_labels > -1
        \ &&
        \ !((a:line =~# '^\s*switch\>'
        \ || a:line =~# '^\s*{\s*$' && a:pline =~# '^\s*switch\>')
        \ && g:awk_indent_switch_labels
        \ || (a:line =~# '^\s*}\s*;\=\s*$'
        \ || a:line =~# '\S\s*}\s*;\=\s*$' && a:line !~# '^\s*case\>')
        \ && get(s:GetStartBraceLine(a:line, a:lnum), 0) =~# '^\s*case\>')
    let ind -= shiftwidth()
  endif

  return ind
endfunction

function s:PreContinueLine(lnum)
  let [line, lnum] = s:SkipCommentLine(getline(a:lnum), a:lnum, 0)
  let pline = s:GetHideStringLine(get(s:SkipCommentLine(line, lnum, 1), 0))
  let line = s:GetHideStringLine(line, 1)
  let ind = indent(lnum)

  return [pline, line, lnum, ind]
endfunction

function s:JoinContinueLine(line, lnum, prev)
  let [line, lnum] = s:SkipCommentLine(a:line, a:lnum, a:prev)
  let line = s:GetHideStringLine(line)
  let pnum = lnum
  while pnum && s:GetPrevNonBlank(pnum)
    let pnum = s:prev_lnum
    let pline = getline(pnum)
    if pline =~# '^\s*#'
      continue
    endif
    let pline = s:GetHideStringLine(pline)
    if pline !~# s:continue_tail
      break
    endif
    let lnum = pnum
    let line = pline. line
  endwhile

  return [line, lnum]
endfunction

function s:SkipCommentLine(line, lnum, prev)
  if a:prev && s:GetPrevNonBlank(a:lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  elseif a:prev
    let lnum = 0
    let line = ""
  else
    let line = a:line
    let lnum = a:lnum
  endif
  while lnum && line =~# '^\s*#' && s:GetPrevNonBlank(lnum)
    let lnum = s:prev_lnum
    let line = getline(lnum)
  endwhile

  return [line, lnum]
endfunction

function s:GetPrevNonBlank(lnum)
  let s:prev_lnum = prevnonblank(a:lnum - 1)

  return s:prev_lnum
endfunction

function s:PreMorePrevLine(pline, pnum, line, lnum)
  let pline = a:pline
  let pnum = a:pnum
  let line = a:line
  let lnum = a:lnum
  if line =~# '^\s\+}\%(\s*\%(else\|while\)\>\)\@!'
        \ || line =~# '\S\s*}\s*;\=\s*$' && s:PairBalance(line, '}', '{') > 0
    let [line, lnum] = s:GetStartBraceLine(line, lnum)
  elseif line =~# '^\s*}\=\s*else\>'
    let [line, lnum] = s:GetIfLine(line, lnum)
  elseif line =~# '^\s*}\=\s*while\>'
    let [line, lnum] = s:GetDoLine(lnum)
  endif
  if line =~# '^\s*do\>' && !s:GetDoLine(a:lnum, lnum == a:lnum ? 0 : 1)
    let pnum = 0
  elseif lnum != a:lnum
    let [pline, pnum] = s:JoinContinueLine(line, lnum, 1)
  endif
  let ind = indent(lnum)

  return [pline, pnum, ind]
endfunction

function s:GetStartBraceLine(line, lnum)
  let line = a:line
  let lnum = a:lnum
  let [line, lnum] = s:GetStartPairLine(line, '}', '{', lnum, 0)
  if line =~# '^\s*}\=\s*else\>'
    let [line, lnum] = s:GetIfLine(line, lnum)
  endif

  return [line, lnum]
endfunction

function s:GetStartPairLine(line, item1, item2, lnum, part)
  let save_cursor = getpos(".")
  if a:lnum == v:lnum
    call cursor(0, col("$"))
    let lnum = search(a:item1, 'cbW', a:lnum)
  else
    call cursor(0, 1)
    let lnum = search(a:item1, 'bW', a:lnum)
  endif
  while lnum > 0
    while lnum && s:InsideAwkItemOrCommentStr()
      let lnum = search(a:item1, 'bW', a:lnum)
    endwhile
    if lnum
      let lnum = searchpair(
            \ a:item2, '', a:item1, 'bW', 's:InsideAwkItemOrCommentStr()')
    endif
    if lnum > 0 && lnum == a:lnum && a:part
      let lnum = search(a:item1, 'bW', a:lnum)
    else
      break
    endif
  endwhile
  if lnum > 0 && a:part
    let line = strpart(getline(lnum), 0, col(".") - 1)
  elseif lnum > 0
    let [line, lnum] = s:JoinContinueLine(getline(lnum), lnum, 0)
  else
    let line = a:line
    let lnum = a:lnum
  endif
  call setpos(".", save_cursor)

  return [line, lnum]
endfunction

function s:GetIfLine(line, lnum, ...)
  if a:0 && a:line !~# '^\s*\%(}\|if\>\|else\>\|{\s*\%(#.*\)\=$\)'
    let expr = 'indent(".") >= indent(a:lnum)'
  elseif a:0
    let expr = 'indent(".") > indent(a:lnum)'
  else
    let expr = 'indent(".") > indent(a:lnum)'
          \. '|| getline(".") =~# "^\\s*}\\=\\s*else\\s\\+if\\>"'
  endif
  let save_cursor = getpos(".")
  call cursor(a:0 ? 0 : a:lnum, 1)
  let lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW',
        \ 'eval(expr) || s:InsideAwkItemOrCommentStr()')
  call setpos(".", save_cursor)
  if lnum > 0
    let line = getline(lnum)
  else
    let line = a:line
    let lnum = a:lnum
  endif

  return a:0 ? lnum : [line, lnum]
endfunction

function s:GetDoLine(lnum, ...)
  let save_cursor = getpos(".")
  call cursor(a:0 && !a:1 ? 0 : a:lnum, 1)
  let lnum = s:SearchDoLoop(a:lnum)
  call setpos(".", save_cursor)
  if lnum
    let line = getline(lnum)
  else
    let line = ""
    let lnum = a:0 ? 0 : a:lnum
  endif

  return a:0 ? lnum : [line, lnum]
endfunction

function s:SearchDoLoop(snum)
  let lnum = 0
  let onum = 0
  while search('\C^\s*do\>', 'ebW')
    let save_cursor = getpos(".")
    let lnum = searchpair('\C\<do\>', '', '\C\<while\>', 'W',
          \ 'indent(".") > indent(get(save_cursor, 1))'
          \. '|| s:InsideAwkItemOrCommentStr()', a:snum)
    if lnum < onum || lnum < 1
      let lnum = 0
      break
    elseif lnum == a:snum
      let lnum = get(save_cursor, 1)
      break
    else
      let onum = lnum
      let lnum = 0
    endif
    call setpos(".", save_cursor)
  endwhile

  return lnum
endfunction

function s:NoClosedPair(lnum, item1, item2, nnum)
  let enum = 0
  let s:ncp_cnum = 0
  let save_cursor = getpos(".")
  call cursor(a:nnum, strlen(getline(a:nnum)))
  let snum = search(a:item1, 'cbW', a:lnum)
  while snum
    if s:InsideAwkItemOrCommentStr()
      let snum = search(a:item1, 'bW', a:lnum)
      continue
    endif
    let s:ncp_cnum = col(".")
    let enum = searchpair(
          \ a:item1, '', a:item2, 'W', 's:InsideAwkItemOrCommentStr()')
    if snum == enum
      call cursor(snum, s:ncp_cnum)
      let s:ncp_cnum = 0
      let snum = search(a:item1, 'bW', a:lnum)
      continue
    endif
    break
  endwhile
  call setpos(".", save_cursor)

  return s:ncp_cnum
endfunction

function s:TailBslash()
  if g:awk_indent_tail_bslash > 0
    let str = '\s\{,'.(g:awk_indent_tail_bslash - 1).'}\\$'
  elseif g:awk_indent_tail_bslash < 0
    let str = '\s\{'.(g:awk_indent_tail_bslash * -1).',}\\$'
  else
    let str = '\s*\\$'
  endif

  return str
endfunction

function s:LessOrMore(line, msum, lnum)
  return indent(a:lnum) + shiftwidth()
        \ < strdisplaywidth(strpart(a:line, 0, a:msum))
endfunction

function s:GetMatchWidth(line, lnum, item)
  let line = getline(a:lnum)
  if type(a:item) == type("")
    let msum = match(line, a:item)
    if a:line =~# '\\$' && strpart(line, msum) =~# '^\s*\\$'
          \ && s:LessOrMore(line, msum, a:lnum)
      let ind = indent(a:lnum) + shiftwidth()
    else
      let ind = strdisplaywidth(strpart(line, 0, msum))
    endif
  else
    let msum = match(strpart(line, a:item), '\S')
    if a:line =~# '\\$'
          \ && (g:awk_indent_tail_bslash > 0
          \ && msum < g:awk_indent_tail_bslash
          \ || g:awk_indent_tail_bslash < 0
          \ && msum >= g:awk_indent_tail_bslash * -1)
          \ && strpart(line, a:item) =~# '^\s*\\$'
          \ && s:LessOrMore(line, a:item, a:lnum)
      let ind = indent(a:lnum) + shiftwidth()
    elseif a:line =~# '\\$' && strpart(line, a:item) =~# '^\s*\\$'
      let ind = strdisplaywidth(strpart(line, 0, a:item))
    else
      if a:line =~# '\\$' && msum > 2 && getline(v:lnum) =~# '^\s*[&|]'
        let msum = msum - 3
      endif
      let ind = strdisplaywidth(strpart(line, 0, a:item + msum))
    endif
  endif

  return ind
endfunction

function s:CloseBraceIndent(cline, ind)
  let [line, lnum] = s:GetStartPairLine(a:cline, '}', '{', v:lnum, 0)
  if line =~# '^\s*{\s*$' || line =~# '^\s*switch\s*(.*)\s*{\s*$'
    return indent(lnum)
  else
    return a:ind - shiftwidth()
  endif
endfunction

function s:CurrentElseIndent(line, lnum)
  let line = a:line
  let lnum = a:lnum
  if line =~# '\S\s*}\s*;\=\s*$' && s:PairBalance(line, '}', '{') > 0
    let [line, lnum] = s:GetStartPairLine(line, '}', '{', lnum, 0)
  endif

  return indent(s:GetIfLine(line, lnum, 1))
endfunction

function s:NestContinueLineIndent(line, lnum, i1, i2)
  let [line, lnum] = s:GetStartPairLine(a:line, '\M'.a:i1, '\M'.a:i2, a:lnum, 1)
  if lnum == a:lnum
    return indent(lnum)
  endif

  let sline = split(line, '\zs')
  let i = len(sline)
  let idx = []
  let sum = 0
  let save_cursor = getpos(".")
  while i && empty(idx)
    if sline[i] ==# a:i2
      call cursor(lnum, byteidx(line, i))
      if !s:InsideAwkItemOrCommentStr()
        if !sum
          let idx += [byteidx(line, i)+1]
        endif
        let sum += 1
      endif
    elseif sline[i] ==# a:i1
      call cursor(lnum, byteidx(line, i))
      if !s:InsideAwkItemOrCommentStr()
        let sum -= 1
      endif
    endif
    let i -= 1
  endwhile
  call setpos(".", save_cursor)

  if len(idx)
    return s:GetMatchWidth(line, lnum, idx[0])
  elseif sum < 0
    return s:NestContinueLineIndent(line, lnum, a:i1, a:i2)
  elseif line =~# '[^<>=!]==\@!'
    return s:GetMatchWidth(line, lnum, '[^<>=!]=\s*\zs\S')
  elseif line =~# '^\s*\%(return\|printf\=\)\>'
    return s:GetMatchWidth(line, lnum, '\h\w*\%(\s\+\|(\s*\)\zs\S')
  else
    return indent(lnum)
  endif
endfunction

function s:PairBalance(line, i1, i2)
  return len(split(a:line, a:i1, 1)) - len(split(a:line, a:i2, 1))
endfunction

function s:GetHideStringLine(line, ...)
  return a:line =~# (a:0 ? '["/#]' : '#')
        \ ? s:InsideAwkItemOrCommentStr(a:line, a:0) : a:line
endfunction

function s:InsideAwkItemOrCommentStr(...)
  let line = a:0 ? a:1 : strpart(getline("."), 0, col("."))
  let sum = match(line, '\S')
  let slash = 0
  let dquote = 0
  let bracket = 0
  let laststr = ""
  let blank = sum
  let rt_line = matchstr(line, '^\s*')
  let slist = split(line, '\zs')
  let cnum = len(slist)
  while sum < cnum
    let str = slist[sum]
    if str ==# '#' && !slash && !dquote
      return a:0 ? rt_line : 1
    elseif str ==# '\' && (slash || dquote) && slist[sum + 1] ==# '\'
      let str = laststr
      let sum += 1
    elseif str ==# '[' && slash && !bracket && laststr !=# '\'
      let bracket = 1
      if slist[sum + 1] ==# '^' && slist[sum + 2] ==# ']'
        let str = ']'
        let sum += 2
      elseif slist[sum + 1] ==# ']'
        let str = ']'
        let sum += 1
      endif
    elseif str ==# '[' && slash && bracket && laststr !=# '\'
      if slist[sum + 1] =~# '[:.=]'
        let ep = matchend(join(slist[sum : -1], ""), '\[\([:.=]\)[^]:.=]\+\1\]')
        let [str, sum] = ep > -1 ? ["]", sum + ep - 1] : [str, sum]
      endif
    elseif str ==# ']' && (slash || dquote) && bracket && laststr !=# '\'
      let bracket = 0
    elseif str ==# '/' && !slash && !dquote
          \ && (!(sum - blank)
          \ || slist[sum - blank - 1] =~# s:before_slash1
          \ || join(slist[0 : sum - blank - 1], "") =~# s:before_slash2)
      let slash = 1
      let rt_line = rt_line. str
    elseif str ==# '/' && slash && laststr !=# '\' && !bracket
      let slash = 0
    elseif str ==# '"' && !dquote && !slash
      let dquote = 1
      let rt_line = rt_line. str
    elseif str ==# '"' && dquote && laststr !=# '\'
      let dquote = 0
    endif
    let blank = str =~# '\s' ? blank + 1 : 0
    let laststr = str
    let sum += 1
    if !slash && !dquote
      let rt_line = rt_line. str
    elseif a:0 && sum == cnum && (slash || dquote) && rt_line =~# '^\s*/'
      let rt_line = matchstr(line, '^\s*/')
      let rt_line .= s:GetHideStringLine(strpart(line, strlen(rt_line)), a:2)
    endif
  endwhile

  return a:0 ? rt_line : slash || dquote
endfunction

function s:AfterParenPairNoStr(lnum)
  let enum = 0
  let estr = ""
  let save_cursor = getpos(".")
  call cursor(a:lnum, 1)
  let snum = search('(', 'W', a:lnum)
  while snum && s:InsideAwkItemOrCommentStr()
    let snum = search('(', 'W', a:lnum)
  endwhile
  if snum
    let enum = searchpair('(', '', ')', 'W', 's:InsideAwkItemOrCommentStr()')
  endif
  if enum > 0
    let estr = strpart(getline(enum), col("."))
  endif
  call setpos(".", save_cursor)

  return enum > 0 && estr =~# '^\s*\%(#.*\)\=$' ? 1 : 0
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: set sts=2 sw=2 expandtab:
