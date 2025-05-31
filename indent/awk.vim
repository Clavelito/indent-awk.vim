vim9script noclear

# Vim indent file
# Language:        AWK Script
# Author:          Clavelito <maromomo@hotmail.com>
# Last Change:     Sat, 31 May 2025 17:58:47 +0900
# Version:         3.13
# License:         http://www.apache.org/licenses/LICENSE-2.0
# Description:
#                  g:awk_indent_switch_labels = 0
#                        switch (label) {
#                        case /A/:
#
#                  g:awk_indent_switch_labels = 1
#                        switch (label) {
#                            case /A/:
#                                                    (default: 1, disable: -1)
#
#                  g:awk_indent_curly_braces = 0
#                        if (brace)
#                        {
#
#                  g:awk_indent_curly_braces = 1
#                        if (brace)
#                            {
#                                                    (default: 0)
#
#                  g:awk_indent_tail_bslash = 2
#                        function_name(  \
#                                      arg1, arg2, arg3)
#
#                  g:awk_indent_tail_bslash = -2
#                        function_name(  \
#                            arg1, arg2, arg3)
#                                                    (default: 2, disable: 0)
#
#                  g:awk_indent_stat_continue = 0
#                        if (pos <= shiftwidth &&
#                            continue_line)
#
#                  g:awk_indent_stat_continue = 2
#                        if (pos <= shiftwidth &&
#                                continue_line)
#                                                    (default: 2, disable: 0)


if exists('b:did_indent')
  finish
endif
b:did_indent = 1

setlocal indentexpr=g:GetAwkIndent()
setlocal indentkeys=0{,},:,!^F,o,O,e,0-,0+,0/,0*,0%,0^,0=,0=**
setlocal indentkeys+=0=-\ ,0=+\ ,0=/\ ,0=*\ ,0=%\ ,0=^\ ,0=**\ 
b:undo_indent = 'setlocal indentexpr< indentkeys<'

if exists('*g:GetAwkIndent')
  finish
endif
const cpo_save = &cpo
set cpo&vim

if !exists('g:awk_indent_switch_labels')
  g:awk_indent_switch_labels = 1
endif
if !exists('g:awk_indent_curly_braces')
  g:awk_indent_curly_braces = 0
endif
if !exists('g:awk_indent_tail_bslash')
  g:awk_indent_tail_bslash = 2
endif
if !exists('g:awk_indent_stat_continue')
  g:awk_indent_stat_continue = 2
endif

var ms: number
var pn: number

def g:GetAwkIndent(): number
  var cline = getline(v:lnum)
  if cline =~ '^#' || !PrevNonBlank(v:lnum)
    return 0
  endif
  # 0: line string, 1: line number
  var rlist = ContinueLineIndent(pn, cline)
  var ind = remove(rlist, 2)
  var sline = rlist[0]
  rlist = JoinContinueLine(rlist[1], rlist[0])
  var plist = JoinContinueLine(rlist[1])
  ind = MorePrevLineIndent(plist[0], plist[1], rlist[0], rlist[1], ind)
  ind = PrevLineIndent(rlist[0], rlist[1], sline, ind)
  ind = CurrentLineIndent(cline, rlist[0], rlist[1], plist[0], plist[1], ind)
  return ind
enddef

def ContinueLineIndent(alnum: number, cline: string): list<any>
  var plist = PreContinueLine(alnum)
  var pline = remove(plist, 0)
  var line = remove(plist, 0)
  var lnum = remove(plist, 0)
  var ind = remove(plist, 0)
  if line =~# '\<\h\w*\%(\<if\|\<while\)\@5<!\s*(\s*\\$'
    ind = TailBslashIndent(line, ind)
  elseif line =~ ')' && PairBalance(line, ')', '(') > 0
      && IsTailContinue(line) && IsTailContinue(pline)
    ind = NestContinueIndent(line, lnum, cline, '(', ')')
  elseif line =~ '\]' && PairBalance(line, '\]', '\[') > 0
      && IsTailContinue(line) && IsTailContinue(pline)
    ind = NestContinueIndent(line, lnum, cline, '\[', '\]')
  elseif line =~ '(' && IsTailContinue(line) && UnclosedPair(line, '(', ')')
    ind = OpenParenIndent(line, lnum, cline)
  elseif line =~ '\[.*\%(\\\|,\s*\)$' && UnclosedPair(line, '\[', '\]')
    ind = GetMatchWidth(CleanPair(line, '\[', '\]'), lnum,
          '\%(\[[^[]*\)\{' .. (ms > 0 ? ms - 1 : 0) .. '}\[\s*\zs\S')
  elseif line =~ '^\s*[*][*]=\@!.*\%(\w\|)\|\]\)\s*\\$'
    ind += 1
  elseif line =~ '[^<>=!]==\@!.*\%(\w\|)\|\]\|++\|--\)\s*\\$'
      && (cline =~ '^\s*=' || cline =~ '^\s*[-+/*%^][ ]\|^\s*[*][*][ ]')
    ind = GetMatchWidth(line, lnum, '=')
  elseif line =~ '[^<>=!]==\@!\s*[^\\[:blank:]]'
      && IsTailContinue(line, true) && !IsTailContinue(pline)
      || line =~ '[^<>=!]==\@!.*\%(\w\|)\|\]\|++\|--\)\s*\\$' && cline =~ '^\s*[-+/*%^]'
    ind = GetMatchWidth(line, lnum, '[^<>=!]=\s*\%(++\@!\|--\@!\)\=\zs.')
    ind = HeadOpIndent(line, cline, ind)
  elseif line =~ '^\s\+\h\w*\s\+[^-+/*%^=\\[:blank:]]'
      && IsTailContinue(line) && !IsTailContinue(pline)
    ind = GetMatchWidth(line, lnum, '\h\w*\s\+\zs\S')
  elseif IsTailContinue(line, true) && !IsTailContinue(pline)
    ind += ind > 0 ? shiftwidth() : shiftwidth() * 2
  endif
  return [line, lnum, ind]
enddef

def MorePrevLineIndent(pline: string, pnum: number,
      line: string, lnum: number, aind: number): number
  if IsTailContinue(line)
    return aind
  endif
  var plist = PreMorePrevLine(pline, pnum, line, lnum)
  var ind = remove(plist, -1)
  while plist[1] > 0 && indent(plist[1]) <= ind
      && ((plist[0] =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*$'
      || plist[0] =~# '^\s*switch\s*(.*)\s*$' && IsOptSwitchEnable())
      && NoStrAfterParen(plist[0])
      || plist[0] =~# '^\s*\%(}\=\s*else\|do\)\s*$')
    ind = indent(plist[1])
    if plist[0] =~# '^\s*do\s*$'
      break
    elseif plist[0] =~# '^\s*}\=\s*else\>'
      plist[1] = GetIfLine(plist[1])
      plist[0] = getline(plist[1])
    endif
    plist = JoinContinueLine(plist[1])
  endwhile
  return ind
enddef

def PrevLineIndent(line: string, lnum: number, sline: string, aind: number): number
  var ind = aind
  if line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\|while\)\s*(.*)\s*{\s*$'
      || (line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\)\s*(.*)\s*$'
      || line =~# '^\s*while\s*(.*)\s*$' && !GetDoLine(lnum, true)
      || line =~# '^\s*switch\s*(.*)\s*$' && IsOptSwitchEnable())
      && NoStrAfterParen(line)
      || line =~# '^\s*\%(}\=\s*else\|do\)\s*{\=\s*$'
      || line =~# '^\s*\%(case\|default\)\>' && IsOptSwitchEnable()
      || line =~ '^\s*{\s*$'
      || line =~ '{' && UnclosedPair(line, '{', '}')
    ind = indent(lnum) + shiftwidth()
  elseif line =~# '^\s*\%(if\|while\)\s*(' && sline !~ '^\s*\%(&&\|||\)'
      && CleanPair(line, '(', ')') =~# '^\s*\%(if\|while\)\s*('
    ind = StatContinueIndent(lnum, ind)
  elseif line =~# '^\s*for\s*(.*;\s*$' && CleanPair(line, '(', ')') =~# '^\s*for\s*('
    ind = GetMatchWidth(line, lnum, '(\s*\zs\S')
  endif
  return ind
enddef

def CurrentLineIndent(cline: string, line: string, lnum: number,
      pline: string, pnum: number, aind: number): number
  var ind = aind
  if cline =~ '^\s*}'
    ind = indent(GetStartBraceLine(0)[1])
  elseif cline =~# '^\s*\%(case\|default\)\>' && IsOptSwitchEnable()
      && !(g:awk_indent_switch_labels
      && (line =~# '^\s*switch\s*(.*)\s*{\s*$'
      || pline =~# '^\s*switch\s*(.*)\s*$' && line =~ '^\s*{\s*$'
      && NoStrAfterParen(pline)))
      && !(line =~ '^\s*}'
      && GetStartBraceLine(lnum)[0] =~# '^\s*case\>'
      || IsTailCloseBrace(line)
      && GetStartBraceLine(lnum, ms)[0] =~# '^\s*case\>')
      && !(line =~# '^\s*break\>'
      && (pline =~ '^\s*}'
      && GetStartBraceLine(pnum)[0] =~# '^\s*case\>'
      || IsTailCloseBrace(pline)
      && GetStartBraceLine(pnum, ms)[0] =~# '^\s*case\>'))
    ind -= shiftwidth()
  elseif cline =~ '^\s*{'
      && (line =~ '\\$'
      || !g:awk_indent_curly_braces
      && UnclosedPair(HideStrComment(cline), '{', '}')
      && ((line =~# '^\s*\%(if\|}\=\s*else\s\+if\|for\)\s*(.*)\s*$'
      || line =~# '^\s*while\s*(.*)\s*$' && !GetDoLine(lnum, true)
      || line =~# '^\s*switch\s*(.*)\s*$' && IsOptSwitchEnable())
      && NoStrAfterParen(line)
      || line =~# '^\s*\%(}\=\s*else\|do\)\s*$'))
    ind = indent(lnum)
  elseif cline =~# '^\s*else\>'
    ind = ElseIndent(line, lnum)
  elseif cline =~ '^\s*[*][*]'
    ind -= 1
  endif
  return ind
enddef

def PreContinueLine(lnum: number): list<any>
  var rlist = SkipCommentLine(lnum, getline(lnum))
  insert(rlist, SkipCommentLine(rlist[1])[0])
  add(rlist, indent(rlist[2]))
  return rlist
enddef

def JoinContinueLine(lnum: number, ...line: list<string>): list<any>
  var rlist: list<any>
  if empty(line)
    rlist = SkipCommentLine(lnum)
  else
    rlist[0] = line[0]
    rlist[1] = lnum
  endif
  pn = rlist[1]
  while PrevNonBlank(pn)
    var pline = getline(pn)
    if pline =~ '^\s*#'
      continue
    endif
    pline = HideStrComment(pline)
    if rlist[0] =~ ')' && PairBalance(rlist[0], ')', '(') > 0 && pline =~ ';\s*$'
    elseif !IsTailContinue(pline)
      break
    endif
    rlist[1] = pn
    rlist[0] = pline .. rlist[0]
  endwhile
  return rlist
enddef

def SkipCommentLine(alnum: number, ...aline: list<string>): list<any>
  var lnum: number
  var line: string
  if empty(aline) && PrevNonBlank(alnum)
    lnum = pn
    line = getline(lnum)
  elseif empty(aline)
    lnum = 0
    line = ''
  else
    lnum = alnum
    line = aline[0]
  endif
  while lnum > 0 && line =~ '^\s*#' && PrevNonBlank(lnum)
    lnum = pn
    line = getline(lnum)
  endwhile
  line = HideStrComment(line)
  return [line, lnum]
enddef

def PrevNonBlank(lnum: number): bool
  pn = prevnonblank(lnum - 1)
  return pn > 0
enddef

def PreMorePrevLine(pline: string, pnum: number, line: string, lnum: number): list<any>
  var plist = [pline, pnum]
  var rlist = [line, lnum]
  if IsTailCloseBrace(line)
    rlist = GetStartBraceLine(lnum, ms)
  elseif line =~# '^\s*}\=\s*while\>'
    rlist[1] = GetDoLine(lnum)
    rlist[0] = getline(rlist[1])
  elseif line =~# '^\s*}\=\s*else\>'
    rlist[1] = GetIfLine(lnum)
    rlist[0] = getline(rlist[1])
  elseif line =~ '^\s\+}'
    rlist = GetStartBraceLine(lnum)
  endif
  if rlist[0] =~# '^\s*do\>' && !GetDoLine(lnum, rlist[1] == lnum ? false : true)
    plist[1] = 0
  elseif rlist[1] != lnum
    plist = JoinContinueLine(rlist[1])
  endif
  add(plist, indent(rlist[1]))
  return plist
enddef

def GetStartBraceLine(alnum: number, ...col: list<any>): list<any>
  var pos = getpos('.')
  cursor(alnum, !empty(col) ? col[0] : 1)
  var lnum = searchpair('{', '', '}', 'bW', 'IsStrComment()')
  setpos('.', pos)
  var rlist = ['', alnum]
  if lnum > 0
    rlist = JoinContinueLine(lnum, getline(lnum))
    if rlist[1] > 0 && len(col) < 2 && rlist[0] =~# '^\s*}\=\s*else\>'
      rlist[1] = GetIfLine(rlist[1])
      rlist[0] = getline(rlist[1])
    endif
  endif
  return rlist
enddef

def AvoidExpr(flag: number): bool
  if flag == 1
    return indent('.') >= indent(pn) || IsStrComment()
  elseif flag == 2
    return indent('.') > indent(pn)
        || getline('.') =~# '^\s*}\=\s*else\s\+if\>'
        || IsStrComment()
  endif
  return indent('.') > indent(pn) || IsStrComment()
enddef

def GetIfLine(alnum: number, ...line: list<string>): number
  var lnum: number
  var pos = getpos('.')
  pn = alnum
  cursor(!empty(line) ? 0 : alnum, 1)
  if !empty(line) && (line[0] =~# '^\s*\%(}\|if\>\|else\>\)'
      || line[0] =~ '^\s*{' && UnclosedPair(HideStrComment(line[0]), '{', '}'))
    lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW', 'AvoidExpr(0)')
  elseif !empty(line)
    lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW', 'AvoidExpr(1)')
  else
    lnum = searchpair('\C\<if\>', '', '\C\<else\>', 'bW', 'AvoidExpr(2)')
  endif
  setpos('.', pos)
  if lnum > 0
    return lnum
  endif
  return !empty(line) ? 0 : alnum
enddef

def GetDoLine(alnum: number, ...flag: list<bool>): number
  var pos = getpos('.')
  cursor(!empty(flag) && !flag[0] ? 0 : alnum, 1)
  var lnum = SearchDoLoop(alnum)
  setpos('.', pos)
  if lnum > 0
    return lnum
  endif
  return !empty(flag) ? 0 : alnum
enddef

def SearchDoLoop(snum: number): number
  var onum = 0
  while search('\C^\s*do\>\ze\%(\_s*#.*\_$\)*\%(\_s*{\ze\)\=', 'ebW') > 0
    var pos = getpos('.')
    pn = pos[1]
    var lnum = searchpair('\C\<do\>', '', '\C^\s*\zs\<while\>\|[};]\s*\zs\<while\>', 'W', 'AvoidExpr(0)', snum)
    setpos('.', pos)
    if lnum < onum || lnum < 1
      break
    elseif lnum == snum
      if getline('.') =~# '^\s*do\>'
        onum = pos[1]
      else
        onum = search('\C^\s*do\>', 'bW')
      endif
      break
    endif
  endwhile
  return onum
enddef

def TailBslashIndent(l: string, i: number): number
  var ind = strdisplaywidth(strpart(l, 0, match(l, '(\zs\s*\\$')))
  var len = strdisplaywidth(strpart(l, 0, strlen(l) - 1)) - ind
  if g:awk_indent_tail_bslash < 0 && len >= g:awk_indent_tail_bslash * -1
      || g:awk_indent_tail_bslash > 0 && len < g:awk_indent_tail_bslash
    ind = i > 0 ? i + shiftwidth() : shiftwidth() * 2
  endif
  return ind
enddef

def NestContinueIndent(l: string, n: number, cl: string, i1: string, i2: string): number
  var pos = getpos('.')
  cursor(n, matchend(CleanPair(l, i1, i2), '^.*' .. i2))
  var p = searchpairpos(i1, '', i2, 'bW', 'IsStrComment()')
  setpos('.', pos)
  if !p[0] || !p[1] || p[0] == n
    return indent(n)
  endif
  var str = CleanPair(strpart(HideStrComment(getline(p[0])), 0, p[1]), i1, i2)
  if !PairBalance(str, i1, i2) && UnclosedPair(str, i1, i2)
    return NestContinueIndent(str, p[0], cl, i1, i2)
  elseif str =~ i1 .. '.'
    var ind = GetMatchWidth(str, p[0], '^.*' .. i1 .. '\%(\s*\zs\S.\|\zs.\)')
    return HeadOpIndent(l, cl, ind)
  elseif str =~ '^\s*[-+/*%^]' && cl =~ '^\s*[-+/*%^]'
    return GetMatchWidth(str, p[0], '[-+/*%^]\zs=\|^\s*[*]\zs[*]\|[-+/%*^=]')
  elseif str =~ '[^<>=!]==\@!.'
    var ind = GetMatchWidth(str, p[0], '[^<>=!]=\s*\zs.')
    return HeadOpIndent(l, cl, ind)
  elseif str =~# '^\s*\%(return\|printf\=\).'
    return GetMatchWidth(str, p[0], '^\s*\h\w*\>\s*\zs.')
  endif
  return indent(p[0])
enddef

def OpenParenIndent(l: string, n: number, cl: string): number
  var pt = '\%(([^(]*\)\{' .. (ms > 0 ? ms - 1 : 0) .. '}'
  var line = CleanPair(l, '(', ')')
  var ind = GetMatchWidth(line, n, pt .. '(\%(\s*\%(++\@!\|--\@!\)\=\zs[^\\[:blank:]]\|\zs.\)')
  if line =~ '\%([^-+/*%^=,&|([:blank:]]\|++\|--\)\s*\\$'
    var ind2 = GetMatchWidth(line, n, pt .. '(\zs.')
    if line =~ '[^<>=!]==\@!\|^\s*[-+/*%^]' && cl =~ '^\s*[-+/*%^][ ]\|^\s*[*][*][ ]'
      ind = HeadOpIndent(l, cl, ind > ind2 + 1 ? ind2 + 1 : ind)
    elseif line =~ '[^<>=!]==\@!\|^\s*[-+/*%^]' && cl =~ '^\s*[-+/*%^]'
      ind = HeadOpIndent(l, cl, ind)
    elseif line =~ '^\s*\%(&&\|||\)' || ind - 2 > ind2
      ind -= 3
    endif
  endif
  return ind
enddef

def HeadOpIndent(line: string, cline: string, aind: number): number
  var ind = aind
  if line =~ '[-+/*%^=~]\s*\\$' && line !~ '\%(++\|--\)\s*\\$'
  elseif cline =~ '^\s*[-+/*%^][ ]\|^\s*[*][*][ ]'
    ind -= 2
  elseif cline =~ '^\s*[-+/*%^]'
    ind -= 1
  endif
  return ind
enddef

def StatContinueIndent(n: number, i: number): number
  if g:awk_indent_stat_continue > 0 && i - indent(n) <= shiftwidth()
    return indent(n) + float2nr(shiftwidth() * g:awk_indent_stat_continue)
  endif
  return i
enddef

def ElseIndent(l: string, n: number): number
  var rlist = [l, n]
  if IsTailCloseBrace(l)
    rlist = GetStartBraceLine(n, ms, true)
  endif
  return indent(GetIfLine(rlist[1], rlist[0]))
enddef

def IsTailContinue(line: string, ...f: list<bool>): bool
  return !empty(f) ? line =~ '\%([^<>=!]==\@!\)\@2<!' .. pt2 : line =~ pt2
enddef

def IsTailCloseBrace(line: string): bool
  ms = line =~ '\S\s*;\=\s*}' && PairBalance(line, '}', '{') > 0
         ? matchend(line, '\S\%(\s*;\=\s*}\)\+') : 0
  return ms > 0
enddef

def UnclosedPair(l: string, i1: string, i2: string): bool
  ms = PairBalance(l, i1, i2)
  return ms > 0 || !ms && len(split(split(l, i1, true)[-1], i2, true)) == 1
enddef

def PairBalance(line: string, i1: string, i2: string): number
  return len(split(line, i1, true)) - len(split(line, i2, true))
enddef

def GetMatchWidth(line: string, lnum: number, item: string): number
  return strdisplaywidth(strpart(getline(lnum), 0, match(line, item)))
enddef

def IsOptSwitchEnable(): bool
  return g:awk_indent_switch_labels > -1
enddef

def NoStrAfterParen(aline: string): bool
  var line = CleanPair(strpart(aline, matchend(aline, '(')), '(', ')')
  return matchstr(line, ').*$') =~ '^)\s*$'
enddef

def CleanPair(aline: string, i1: string, i2: string): string
  var line = aline
  var last = ''
  while last != line
    last = line
    line = substitute(line, i1 .. '[^' .. i1 .. i2 .. ']*' .. i2, rpt, 'g')
  endwhile
  return line
enddef

def HideStrComment(aline: string): string
  if aline !~ '[#"/]'
    return aline
  endif
  var line = substitute(aline, '\\\@1<!\%(\\\\\)*\\.', rpt, 'g')
  line = substitute(line, pt1, rpt, 'g')
  line = substitute(line, '[#"].*$', '', '')
  return line
enddef

def IsStrComment(): bool
  var line = HideStrComment(getline('.'))
  return strlen(line) < col('.') || strpart(line, 0, col('.')) =~# 'x$'
enddef

const bfrsla = '\%([^])_a-zA-Z0-9[:blank:]]\|\<\%(case\|printf\=\|return\)\|^\)'
const pt0 = '\%(\[\^\]\|\[\]\|\[\)\%(\[\([:=.]\)[^]:=.]\+\1\]\|[^]]\)*\]\|[^/[]'
const pt1 = '"[^"]*"\|' .. bfrsla .. '\s*\C\zs/\%(' .. pt0 .. '\)*/'
const rpt = '\=repeat("x", strlen(submatch(0)))'
const pt2 = '\\$\|\%(&&\|||\|,\|?\|\C\%(\<\%(case\|default\)\>.*\)\@<!:\)\s*$'

&cpo = cpo_save
# vim: set sts=2 sw=2 expandtab:
