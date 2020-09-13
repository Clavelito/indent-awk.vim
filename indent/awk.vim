" Vim indent file
" Language:        AWK Script
" Author:          Clavelito <maromomo@hotmail.com>
" Last Change:     Mon, 14 Sep 2020 07:32:11 +0900
" Version:         2.0
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
"
"                  let g:awk_indent_stat_continue = 0
"                          if (pos <= shiftwidth &&
"                              continue_line)
"
"                  let g:awk_indent_stat_continue = 2
"                          if (pos <= shiftwidth &&
"                                  continue_line)
"                                                    (default: 2, disable: 0)


if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetAwkIndent()
setlocal indentkeys=0{,},:,!^F,o,O,e,0-,0+,0/,0*,0%,0^,0=,0=**
let b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists("*GetAwkIndent")
  finish
endif
let s:cpo_save = &cpo
set cpo&vim

let s:bfrsla = '\%([^])_a-zA-Z0-9[:blank:]]\|\<\%(case\|printf\=\|return\)\|^\)'

if !exists("g:awk_indent_switch_labels")
  let g:awk_indent_switch_labels = 1
endif
if !exists("g:awk_indent_curly_braces")
  let g:awk_indent_curly_braces = 0
endif
if !exists("g:awk_indent_tail_bslash")
  let g:awk_indent_tail_bslash = 2
endif
if !exists("g:awk_indent_stat_continue")
  let g:awk_indent_stat_continue = 2
endif

function GetAwkIndent()
  let cline = getline(v:lnum)
  if cline =~ '^#' || !s:PrevNonBlank(v:lnum)
    return 0
  endif
  let [line, lnum, ind] = s:ContinueLineIndent(s:pn, cline)
  let sline = line
  let snum = lnum
  let [line, lnum] = s:JoinContinueLine(lnum, line)
  let [pline, pnum] = s:JoinContinueLine(lnum)
  let ind = s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  let ind = s:PrevLineIndent(line, lnum, sline, snum, ind)
  let ind = s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)
  unlet! s:pn s:ms
  return ind
endfunction

function s:ContinueLineIndent(lnum, cline)
  let [pline, line, lnum, ind] = s:PreContinueLine(a:lnum)
  if line =~# '\<\h\w*\%(\<if\|\<while\)\@5<!\s*(\s*\\$'
    let ind = s:TailBslashIndent(line, ind)
  elseif line =~ '^\s*[*][*]=\@!.*\%(\w\|)\|\]\)\s*\\$'
    let ind += a:cline =~ '^\s*[*][*]' ? 0 : 1
  elseif line =~ '^\s*[-+/*%^=]=\@!.*\%(\w\|)\|\]\)\s*\\$'
    let ind -= a:cline =~ '^\s*[*][*]' ? 1 : 0
  elseif line =~ ')' && s:PairBalance(line, ')', '(') > 0
        \ && s:IsTailContinue(line) && s:IsTailContinue(pline)
    let ind = s:NestContinueIndent(line, lnum, '(', ')')
  elseif line =~ '\]' && s:PairBalance(line, '\]', '\[') > 0
        \ && s:IsTailContinue(line) && s:IsTailContinue(pline)
    let ind = s:NestContinueIndent(line, lnum, '\[', '\]')
  elseif line =~ '(' && s:IsTailContinue(line) && s:UnclosedPair(line, '(', ')')
    let ind = s:GetMatchWidth(s:CleanPair(line, '(', ')'), lnum,
          \ '\%(([^(]*\)\{'. (s:ms ? s:ms-1 : 0). '}'
          \. '\%((\s*\zs[^\\[:blank:]]\|(\zs.\)')
  elseif line =~ '\[.*\%(\\\|,\s*\)$' && s:UnclosedPair(line, '\[', '\]')
    let ind = s:GetMatchWidth(s:CleanPair(line, '\[', '\]'), lnum,
          \ '\%(\[[^[]*\)\{'. (s:ms ? s:ms-1 : 0). '}\[\s*\zs\S')
  elseif line =~ '[^<>=!]==\@!.*\%(\w\|)\|\]\)\s*\\$'
        \ && a:cline =~ '^\s*[-+/*%^=]'
    let ind = s:GetMatchWidth(line, lnum, '=')
    let ind -= a:cline =~ '^\s*[*][*]' ? 1 : 0
  elseif line =~ '[^<>=!]==\@!\s*[^\\[:blank:]]'
        \ && s:IsTailContinue(line, 1) && !s:IsTailContinue(pline)
    let ind = s:GetMatchWidth(line, lnum, '[^<>=!]=\s*\zs.')
  elseif line =~ '^\s\+\h\w*\s\+[^-+/*%^=\\[:blank:]]'
        \ && s:IsTailContinue(line, 1) && !s:IsTailContinue(pline)
    let ind = s:GetMatchWidth(line, lnum, '\h\w*\s\+\zs\S')
  elseif s:IsTailContinue(line, 1) && !s:IsTailContinue(pline)
    let ind += ind ? shiftwidth() : shiftwidth() * 2
  endif
  return [line, lnum, ind]
endfunction

function s:MorePrevLineIndent(pline, pnum, line, lnum, ind)
  if s:IsTailContinue(a:line)
    return a:ind
  endif
  let [pline, pnum, ind] = s:PreMorePrevLine(a:pline, a:pnum, a:line, a:lnum)
  while pnum && indent(pnum) <= ind
        \ && ((pline =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*$'
        \ || pline =~# '^\s*switch\s*(.*)\s*$' && s:IsOptSwitchEnable())
        \ && s:NoStrAfterParen(pline)
        \ || pline =~# '^\s*\%(}\=\s*else\|do\)\s*$')
    let ind = indent(pnum)
    if pline =~# '^\s*do\s*$'
      break
    elseif pline =~# '^\s*}\=\s*else\>'
      let [pline, pnum] = s:GetIfLine(pnum)
    endif
    let [pline, pnum] = s:JoinContinueLine(pnum)
  endwhile
  return ind
endfunction

function s:PrevLineIndent(line, lnum, sline, snum, ind)
  let ind = a:ind
  if a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*{\s*$'
        \ || (a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\)\s*(.*)\s*$'
        \ || a:line =~# '^\s*while\s*(.*)\s*$' && !s:GetDoLine(a:lnum, 1)
        \ || a:line =~# '^\s*switch\s*(.*)\s*$' && s:IsOptSwitchEnable())
        \ && s:NoStrAfterParen(a:line)
        \ || a:line =~# '^\s*\%(}\=\s*else\|do\)\s*{\=\s*$'
        \ || a:line =~# '^\s*\%(case\|default\)\>' && s:IsOptSwitchEnable()
        \ || a:line =~ '^\s*{\s*$'
        \ || a:line =~ '{' && s:UnclosedPair(a:line, '{', '}')
    let ind = indent(a:lnum) + shiftwidth()
  elseif a:line  =~# '\<\%(if\|while\)\s*('
        \ && s:CleanPair(a:line, '(', ')') =~# '\<\%(if\|while\)\s*('
        \ && s:UnclosedPair(a:line, '(', ')') && a:sline !~ '^\s*\%(&&\|||\)'
        \ && !(a:snum != a:lnum && ind > indent(a:snum))
    let ind = s:StatContinueIndent(a:line, a:lnum, a:snum, ind)
  endif
  return ind
endfunction

function s:CurrentLineIndent(cline, line, lnum, pline, pnum, ind)
  let ind = a:ind
  if a:cline =~ '^\s*}'
    let ind = indent(s:GetStartBraceLine(0)[1])
  elseif a:cline =~# '^\s*\%(case\|default\)\>' && s:IsOptSwitchEnable()
        \ && !(g:awk_indent_switch_labels
        \ && (a:line =~# '^\s*switch\s*(.*)\s*{\s*$'
        \ || a:pline =~# '^\s*switch\s*(.*)\s*$' && a:line =~ '^\s*{\s*$'
        \ && s:NoStrAfterParen(a:pline)))
        \ && !(a:line =~ '^\s*}'
        \ && s:GetStartBraceLine(a:lnum)[0] =~# '^\s*case\>'
        \ || s:IsTailCloseBrace(a:line)
        \ && s:GetStartBraceLine(a:lnum, s:ms)[0] =~# '^\s*case\>')
        \ && !(a:line =~# '^\s*break\>'
        \ && (a:pline =~ '^\s*}'
        \ && s:GetStartBraceLine(a:pnum)[0] =~# '^\s*case\>'
        \ || s:IsTailCloseBrace(a:pline)
        \ && s:GetStartBraceLine(a:pnum, s:ms)[0] =~# '^\s*case\>'))
    let ind -= shiftwidth()
  elseif a:cline =~ '^\s*{\s*\%(#.*\)\=$'
        \ && (a:line =~ '\\$'
        \ || !g:awk_indent_curly_braces
        \ && ((a:line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\)\s*(.*)\s*$'
        \ || a:line =~# '^\s*while\s*(.*)\s*$' && !s:GetDoLine(a:lnum, 1)
        \ || a:line =~# '^\s*switch\s*(.*)\s*$' && s:IsOptSwitchEnable())
        \ && s:NoStrAfterParen(a:line)
        \ || a:line =~# '^\s*\%(}\=\s*else\|do\)\s*$'))
    let ind = indent(a:lnum)
  elseif a:cline =~# '^\s*else\>'
    let ind = s:ElseIndent(a:line, a:lnum)
  endif
  return ind
endfunction

function s:PreContinueLine(lnum)
  let [line, lnum] = s:SkipCommentLine(a:lnum, getline(a:lnum))
  let pline = s:SkipCommentLine(lnum)[0]
  let ind = indent(lnum)
  return [pline, line, lnum, ind]
endfunction

function s:JoinContinueLine(lnum, ...)
  let [line, lnum] = a:0 ? [a:1, a:lnum] : s:SkipCommentLine(a:lnum)
  let s:pn = lnum
  while s:PrevNonBlank(s:pn)
    let pline = getline(s:pn)
    if pline =~ '^\s*#'
      continue
    endif
    let pline = s:HideStrComment(pline)
    if !s:IsTailContinue(pline)
      break
    endif
    let lnum = s:pn
    let line = pline. line
  endwhile
  return [line, lnum]
endfunction

function s:SkipCommentLine(lnum, ...)
  if !a:0 && s:PrevNonBlank(a:lnum)
    let lnum = s:pn
    let line = getline(lnum)
  elseif !a:0
    let lnum = 0
    let line = ""
  else
    let lnum = a:lnum
    let line = a:1
  endif
  while lnum && line =~ '^\s*#' && s:PrevNonBlank(lnum)
    let lnum = s:pn
    let line = getline(lnum)
  endwhile
  let line = s:HideStrComment(line)
  return [line, lnum]
endfunction

function s:PrevNonBlank(lnum)
  let s:pn = prevnonblank(a:lnum - 1)
  return s:pn
endfunction

function s:PreMorePrevLine(pline, pnum, line, lnum)
  let pline = a:pline
  let pnum = a:pnum
  let line = a:line
  let lnum = a:lnum
  if s:IsTailCloseBrace(line)
    let [line, lnum] = s:GetStartBraceLine(lnum, s:ms)
  elseif line =~# '^\s*}\=\s*while\>'
    let [line, lnum] = s:GetDoLine(lnum)
  elseif line =~# '^\s*}\=\s*else\>'
    let [line, lnum] = s:GetIfLine(lnum)
  elseif line =~ '^\s\+}'
    let [line, lnum] = s:GetStartBraceLine(lnum)
  endif
  if line =~# '^\s*do\>' && !s:GetDoLine(a:lnum, lnum == a:lnum ? 0 : 1)
    let pnum = 0
  elseif lnum != a:lnum
    let [pline, pnum] = s:JoinContinueLine(lnum)
  endif
  let ind = indent(lnum)
  return [pline, pnum, ind]
endfunction

function s:GetStartBraceLine(lnum, ...)
  let pos = getpos(".")
  call cursor(a:lnum, a:0 ? a:1 : 1)
  let lnum = searchpair('{', '', '}', 'bW', 's:IsStrComment()')
  call setpos(".", pos)
  if lnum > 0
    let [line, lnum] = s:JoinContinueLine(lnum, getline(lnum))
    if a:lnum > 0 && a:0 < 2 && line =~# '^\s*}\=\s*else\>'
      let [line, lnum] = s:GetIfLine(lnum)
    endif
  else
    let line = ""
    let lnum = a:lnum
  endif
  return [line, lnum]
endfunction

function s:GetIfLine(lnum, ...)
  if a:0 && a:1 =~# '^\s*\%(}\|if\>\|else\>\|{\s*\%(#.*\)\=$\)'
    let expr = 'indent(".") > indent(a:lnum)'
  elseif a:0
    let expr = 'indent(".") >= indent(a:lnum)'
  else
    let expr = 'indent(".") > indent(a:lnum)'
          \. '|| getline(".") =~# "^\\s*}\\=\\s*else\\s\\+if\\>"'
  endif
  let pos = getpos(".")
  call cursor(a:0 ? 0 : a:lnum, 1)
  let lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW',
        \ 'eval(expr) || s:IsStrComment()')
  call setpos(".", pos)
  if lnum > 0
    let line = getline(lnum)
  else
    let line = ""
    let lnum = a:0 ? 0 : a:lnum
  endif
  return a:0 ? lnum : [line, lnum]
endfunction

function s:GetDoLine(lnum, ...)
  let pos = getpos(".")
  call cursor(a:0 && !a:1 ? 0 : a:lnum, 1)
  let lnum = s:SearchDoLoop(a:lnum)
  call setpos(".", pos)
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
    let pos = getpos(".")
    let lnum = searchpair('\C\<do\>', '', '\C\<while\>', 'W',
          \ 'indent(".") > indent(pos[1]) || s:IsStrComment()', a:snum)
    if lnum < onum || lnum < 1
      let lnum = 0
      break
    elseif lnum == a:snum
      let lnum = pos[1]
      break
    endif
    let onum = lnum
    let lnum = 0
    call setpos(".", pos)
  endwhile
  return lnum
endfunction

function s:TailBslashIndent(l, i)
  let ind = strdisplaywidth(a:l[0 : match(a:l, '(\s*\\$')])
  let len = strdisplaywidth(a:l[0 : -2]) - ind
  if g:awk_indent_tail_bslash < 0 && len >= g:awk_indent_tail_bslash * -1
        \ || g:awk_indent_tail_bslash > 0 && len < g:awk_indent_tail_bslash
    let ind = a:i ? a:i + shiftwidth() : shiftwidth() * 2
  endif
  return ind
endfunction

function s:NestContinueIndent(l, n, i1, i2)
  let pos = getpos(".")
  call cursor(a:n, matchend(s:CleanPair(a:l, a:i1, a:i2), '^.*'. a:i2))
  let p = searchpairpos(a:i1, '', a:i2, 'bW', 's:IsStrComment()')
  call setpos(".", pos)
  if !(p[0] && p[1]) || p[0] == a:n
    return indent(a:n)
  endif
  let str = s:CleanPair(s:HideStrComment(getline(p[0]))[0 : p[1]-1], a:i1, a:i2)
  if str =~ a:i1. '.'
    return s:GetMatchWidth(str, p[0], '^.*'. a:i1. '\%(\s*\zs\S.\|\zs.\)')
  elseif str =~ '[^<>=!]==\@!.'
    return s:GetMatchWidth(str, p[0], '[^<>=!]=\s*\zs.')
  elseif str =~# '^\s*\%(return\|printf\=\).'
    return s:GetMatchWidth(str, p[0], '^\s*\h\w*\>\s*\zs.')
  endif
  return indent(p[0])
endfunction

function s:StatContinueIndent(l, n, s, i)
  let ind = a:i
  if a:n == a:s && s:ms == 1 && a:i - s:GetMatchWidth(a:l, a:n, '(\zs.') > 2
    let ind -= 3
  elseif a:n != a:s && s:ms == 1
    let ind = s:GetMatchWidth(a:l, a:n,'(\s*\zs[^\\([:blank:]]\|(\zs.')
  endif
  if g:awk_indent_stat_continue > 0 && ind - indent(a:n) <= shiftwidth()
    let ind = indent(a:n) + float2nr(shiftwidth() * g:awk_indent_stat_continue)
  endif
  return ind
endfunction

function s:ElseIndent(l, n)
  let line = a:l
  let lnum = a:n
  if s:IsTailCloseBrace(line)
    let [line, lnum] = s:GetStartBraceLine(lnum, s:ms, 1)
  endif
  return indent(s:GetIfLine(lnum, line))
endfunction

function s:IsTailContinue(line, ...)
  let pt = '\\$\|\%(&&\|||\|,\|?\|\C\%(\<\%(case\|default\)\>.*\)\@<!:\)\s*$'
  return a:0 ? a:line =~ '=\@1<!'. pt : a:line =~ pt
endfunction

function s:IsTailCloseBrace(line)
  let s:ms = a:line =~ '\S\s*;\=\s*}' && s:PairBalance(a:line, '}', '{') > 0
        \ ? matchend(a:line, '\S\%(\s*;\=\s*}\)\+') : 0
  return s:ms
endfunction

function s:UnclosedPair(l, i1, i2)
  let s:ms = s:PairBalance(a:l, a:i1, a:i2)
  return s:ms > 0 || !s:ms && len(split(split(a:l, a:i1, 1)[-1], a:i2, 1)) == 1
endfunction

function s:PairBalance(line, i1, i2)
  return len(split(a:line, a:i1, 1)) - len(split(a:line, a:i2, 1))
endfunction

function s:GetMatchWidth(line, lnum, item)
  return strdisplaywidth(strpart(getline(a:lnum), 0, match(a:line, a:item)))
endfunction

function s:IsOptSwitchEnable()
  return g:awk_indent_switch_labels > -1
endfunction

function s:NoStrAfterParen(line)
  let line = s:CleanPair(a:line[matchend(a:line, '(') : -1], '(', ')')
  return matchstr(line, ').*$') =~ '^)\s*$'
endfunction

function s:CleanPair(line, i1, i2)
  let line = a:line
  let last = ""
  while last != line
    let last = line
    let line = substitute(line, a:i1. '[^'. a:i1. a:i2. ']*'. a:i2,
          \ '\=repeat("x", strlen(submatch(0)))', 'g')
  endwhile
  return line
endfunction

function s:HideStrComment(line)
  if a:line !~ '[#"/]'
    return a:line
  endif
  let rp = '\=repeat("x", strlen(submatch(0)))'
  let pt = '\%(\[\^\]\|\[\]\|\[\)\%(\[\([:=.]\)[^]:=.]\+\1\]\|[^]]\)*\]\|[^/]'
  let pt = '"[^"]*"\|'. s:bfrsla. '\s*\C\zs/\%('. pt. '\)*/'
  let line = substitute(a:line, '\\\@1<!\%(\\\\\)*\\.', rp, 'g')
  let line = substitute(line, pt, rp, 'g')
  let line = substitute(line, '[#"].*$', '', '')
  return line
endfunction

function s:IsStrComment()
  let line = getline(".")
  let cnum = col(".")
  let sum = match(line, '\S')
  let slash = 0
  let dquote = 0
  let bracket = 0
  let laststr = ""
  while sum < cnum
    let str = line[sum]
    if str == '#' && !slash && !dquote
      return 1
    elseif str == '\' && (slash || dquote) && line[sum + 1] == '\'
      let str = laststr
      let sum += 1
    elseif str == '[' && slash && !bracket && laststr != '\'
      let bracket = 1
      if line[sum + 1 : sum + 2] == '^]'
        let sum += 2
      elseif line[sum + 1] == ']'
        let sum += 1
      endif
    elseif str == '[' && slash && bracket && laststr != '\'
      if line[sum + 1] =~ '[:=.]'
        let esum = matchend(line[sum : -1], '^\[\([:=.]\)[^]:=.]\+\1\]')
        let sum += esum > -1 ? esum - 1 : 0
      endif
    elseif str == ']' && slash && bracket && laststr != '\'
      let bracket = 0
    elseif str == '/' && !slash && !dquote && line[0 : sum] =~# s:bfrsla.'\s*/$'
      let slash = 1
    elseif str == '/' && slash && !bracket && laststr != '\'
      let slash = 0
    elseif str == '"' && !dquote && !slash
      let dquote = 1
    elseif str == '"' && dquote && laststr != '\'
      let dquote = 0
    endif
    let laststr = str
    let sum += 1
  endwhile
  return slash || dquote
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: set sts=2 sw=2 expandtab:
