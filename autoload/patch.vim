" http://en.wikipedia.org/wiki/Patch_%28Unix%29
" http://en.wikipedia.org/wiki/Diff
" http://pubs.opengroup.org/onlinepubs/9699919799/utilities/diff.html

let s:save_cpo = &cpo
set cpo&vim

function patch#patchexpr()
  let in = readfile(v:fname_in, 'b')
  let diff = readfile(v:fname_diff, 'b')
  let out = patch#patch(in, diff)
  call writefile(out, v:fname_out, 'b')
endfunction

function patch#patch(in, diff)
  let patch = s:Patch.new(a:diff)
  let out = patch.apply(a:in)
  return out
endfunction

let s:COM = 0
let s:ADD = 1
let s:DEL = 2

let s:Patch = {}

function s:Patch.new(...)
  let obj = deepcopy(self)
  call call(obj.__init__, a:000, obj)
  return obj
endfunction

function s:Patch.__init__(diff)
  let self.diffs = self.parse(a:diff)
endfunction

function s:Patch.apply(in)
  let old = a:in
  let new = copy(old)
  for [oldstart, newstart, edit] in self.diffs
    let oldlnum = oldstart
    let newlnum = newstart
    for [cmd, line] in edit
      if cmd == s:ADD
        call insert(new, line, newlnum)
        let newlnum += 1
      elseif cmd == s:DEL
        if new[newlnum] !=# line
          throw 'error: del'
        endif
        call remove(new, newlnum)
        let oldlnum += 1
      elseif cmd == s:COM
        if old[oldlnum] !=# new[newlnum]
          throw 'error: com'
        endif
        let oldlnum += 1
        let newlnum += 1
      endif
    endfor
  endfor
  return new
endfunction

" @return [[old-lnum, new-lnum, edit], ...]
function s:Patch.parse(diff)
  let type = self.detect(a:diff)
  if type == 'normal'
    return self.parse_normal(a:diff)
  elseif type == 'context'
    return self.parse_context(a:diff)
  elseif type == 'unified'
    return self.parse_unified(a:diff)
  else
    throw 'unknown'
  endif
endfunction

function s:Patch.parse_normal(diff)
  let res = []
  let i = 0
  while i < len(a:diff)
    let m = matchlist(a:diff[i], '\v^(\d+)%(,(\d+))?([adc])(\d+)%(,(\d+))?$')
    let i += 1
    if empty(m)
      continue
    endif
    let oldstart = m[1] - 1
    let oldend = (m[2] == '' ? oldstart : m[2] - 1)
    let cmd = m[3]
    let newstart = m[4] - 1
    let newend = (m[5] == '' ? newstart : m[5] - 1)
    let oldcount = oldend - oldstart + 1
    let newcount = newend - newstart + 1
    let edit = []
    if cmd == 'a'
      for j in range(newcount)
        let m = matchlist(a:diff[i], '^> \(.*\)$')
        let i += 1
        call add(edit, [s:ADD, m[1]])
      endfor
    elseif cmd == 'd'
      let newstart += 1
      for j in range(oldcount)
        let m = matchlist(a:diff[i], '^< \(.*\)$')
        let i += 1
        call add(edit, [s:DEL, m[1]])
      endfor
    elseif cmd == 'c'
      for j in range(oldcount)
        let m = matchlist(a:diff[i], '^< \(.*\)$')
        let i += 1
        call add(edit, [s:DEL, m[1]])
      endfor
      let m = matchlist(a:diff[i], '^---$')
      if empty(m)
        throw 'parse error'
      endif
      let i += 1
      for j in range(newcount)
        let m = matchlist(a:diff[i], '^> \(.*\)$')
        let i += 1
        call add(edit, [s:ADD, m[1]])
      endfor
    else
      throw 'parse error'
    endif
    call add(res, [oldstart, newstart, edit])
  endwhile
  return res
endfunction

function s:Patch.parse_context(diff)
  let res = []
  let i = 0
  while i < len(a:diff)
    let m = matchlist(a:diff[i], '^\*\*\* ')
    let i += 1
    if empty(m)
      continue
    endif
    let m = matchlist(a:diff[i], '^--- ')
    let i += 1
    if empty(m)
      throw 'parse error'
    endif
    while i < len(a:diff)
      let m = matchlist(a:diff[i], '^\*\{15}$')
      if empty(m)
        break
      endif
      let i += 1
      let m = matchlist(a:diff[i], '\v^\*\*\* (\d+)%(,(\d+))? \*\*\*\*$')
      let i += 1
      if empty(m)
        throw 'parse error'
      endif
      if m[2] != ''
        let oldend = m[2] - 1
        let oldstart = m[1] - 1
      else
        let oldend = m[1] - 1
        let oldstart = oldend
      endif
      let old = []
      while a:diff[i] =~ '^. '
        call add(old, a:diff[i])
        let i += 1
      endwhile
      let m = matchlist(a:diff[i], '\v^--- (\d+)%(,(\d+))? ----$')
      let i += 1
      if empty(m)
        throw 'parse error'
      endif
      if m[2] != ''
        let newend = m[2] - 1
        let newstart = m[1] - 1
      else
        let newend = m[1] - 1
        let newstart = newend
      endif
      let new = []
      while a:diff[i] =~ '^. '
        call add(new, a:diff[i])
        let i += 1
      endwhile
      " XXX: adjust
      if empty(old) && oldstart == oldend
        let oldstart += 1
      endif
      if empty(new) && newstart == newend
        let newstart += 1
      endif
      let oldi = 0
      let newi = 0
      let edit = []
      while oldi < len(old) || newi < len(new)
        if oldi < len(old) && newi < len(new)
          let oldm = matchlist(old[oldi], '^\(.\) \(.*\)$')
          let newm = matchlist(new[newi], '^\(.\) \(.*\)$')
          if oldm[1] == '-'
            call add(edit, [s:DEL, oldm[2]])
            let oldi += 1
          elseif newm[1] == '+'
            call add(edit, [s:ADD, newm[2]])
            let newi += 1
          elseif oldm[1] == ' ' && newm[1] == ' '
            if oldm[2] !=# newm[2]
              throw 'parse error'
            endif
            call add(edit, [s:COM, oldm[2]])
            let oldi += 1
            let newi += 1
          elseif oldm[1] == '!' && newm[1] == '!'
            while oldi < len(old)
              let oldm = matchlist(old[oldi], '^\(.\) \(.*\)$')
              if oldm[1] != '!'
                break
              endif
              call add(edit, [s:DEL, oldm[2]])
              let oldi += 1
            endwhile
            while newi < len(new)
              let newm = matchlist(new[newi], '^\(.\) \(.*\)$')
              if newm[1] != '!'
                break
              endif
              call add(edit, [s:ADD, newm[2]])
              let newi += 1
            endwhile
          else
            throw 'parse error'
          endif
        elseif oldi < len(old)
          let oldm = matchlist(old[oldi], '^\(.\) \(.*\)$')
          if oldm[1] == '-'
            call add(edit, [s:DEL, oldm[2]])
            let oldi += 1
          elseif oldm[1] == ' '
            call add(edit, [s:COM, oldm[2]])
            let oldi += 1
          else
            throw 'parse error'
          endif
        else
          let newm = matchlist(new[newi], '^\(.\) \(.*\)$')
          if newm[1] == '+'
            call add(edit, [s:ADD, newm[2]])
            let newi += 1
          elseif newm[1] == ' '
            call add(edit, [s:COM, newm[2]])
            let newi += 1
          else
            throw 'parse error'
          endif
        endif
      endwhile
      call add(res, [oldstart, newstart, edit])
    endwhile
  endwhile
  return res
endfunction

function s:Patch.parse_unified(diff)
  let res = []
  let i = 0
  while i < len(a:diff)
    let m = matchlist(a:diff[i], '^--- ')
    let i += 1
    if empty(m)
      continue
    endif
    let m = matchlist(a:diff[i], '^+++ ')
    let i += 1
    if empty(m)
      throw 'parse error'
    endif
    while 1
      let m = matchlist(a:diff[i], '\v^\@\@ -(\d+)%(,(\d+))? \+(\d+)%(,(\d+))? \@\@$')
      if empty(m)
        break
      endif
      let i += 1
      let oldstart = m[1] - 1
      let oldcount = (m[2] == '' ? 1 : m[2] + 0)
      if oldcount == 0
        let oldstart += 1
      endif
      let newstart = m[3] - 1
      let newcount = (m[4] == '' ? 1 : m[4] + 0)
      if newcount == 0
        let newstart += 1
      endif
      let edit = []
      while oldcount > 0 || newcount > 0
        let m = matchlist(a:diff[i], '^\(.\)\(.*\)$')
        let i += 1
        if m[1] == ' '
          call add(edit, [s:COM, m[2]])
          let oldcount -= 1
          let newcount -= 1
        elseif m[1] == '+'
          call add(edit, [s:ADD, m[2]])
          let newcount -= 1
        elseif m[1] == '-'
          call add(edit, [s:DEL, m[2]])
          let oldcount -= 1
        else
          throw 'parse error'
        endif
      endwhile
      call add(res, [oldstart, newstart, edit])
    endwhile
  endwhile
  return res
endfunction

function s:Patch.detect(diff)
  let i = 0
  while i < len(a:diff)
    if a:diff[i] =~# '^--- ' && i + 1 < len(a:diff) && a:diff[i + 1] =~# '^+++'
      return 'unified'
    elseif a:diff[i] =~# '^\*\*\* ' && i + 1 < len(a:diff) && a:diff[i + 1] =~# '^---'
      return 'context'
    endif
    let i += 1
  endwhile
  return 'normal'
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
