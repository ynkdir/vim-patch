" TODO:
" $ patch -o - test12_old.txt test12.context
" $ patching file test12_old.txt
" $ patch: **** replacement text or line numbers mangled in hunk at line 8

let s:dir = expand('<sfile>:p:h')

function! s:syspatch(oldfile, patchfile)
  let tmp = tempname()
  call system(printf('patch -s -o %s %s %s', shellescape(tmp), shellescape(a:oldfile), shellescape(a:patchfile)))
  let out = readfile(tmp, 'b')
  call delete(tmp)
  return out
endfunction

function! s:test(name)
  echo a:name
  let oldfile = printf('%s/%s_old.txt', s:dir, a:name)
  let newfile = printf('%s/%s_new.txt', s:dir, a:name)
  let ndiff = printf('%s/%s.normal', s:dir, a:name)
  let cdiff = printf('%s/%s.context', s:dir, a:name)
  let udiff = printf('%s/%s.unified', s:dir, a:name)
  let a = patch#patch(readfile(oldfile, 'b'), readfile(ndiff, 'b'))
  let b = s:syspatch(oldfile, ndiff)
  if a != b
    echo a
    echo b
    echoerr printf('%s normal failed', a:name)
  endif
  let c = patch#patch(readfile(oldfile, 'b'), readfile(cdiff, 'b'))
  let d = s:syspatch(oldfile, cdiff)
  if c != d
    echo c
    echo d
    echoerr printf('%s context failed', a:name)
  endif
  let e = patch#patch(readfile(oldfile, 'b'), readfile(udiff, 'b'))
  let f = s:syspatch(oldfile, udiff)
  if e != f
    echo e
    echo f
    echoerr printf('%s unified failed', a:name)
  endif
endfunction

let i = 1
while filereadable(printf('%s/test%d_old.txt', s:dir, i))
  call s:test(printf('test%d', i))
  let i += 1
endwhile
