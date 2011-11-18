
let s:dir = expand('<sfile>:p:h')

function! s:syspatch(oldfile, patchfile)
  let tmp = tempname()
  call system(printf('patch -s -o %s %s %s', shellescape(tmp), shellescape(a:oldfile), shellescape(a:patchfile)))
  let out = readfile(tmp, 'b')
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
  let c = patch#patch(readfile(oldfile, 'b'), readfile(cdiff, 'b'))
  let d = s:syspatch(oldfile, cdiff)
  let e = patch#patch(readfile(oldfile, 'b'), readfile(udiff, 'b'))
  let f = s:syspatch(oldfile, udiff)
  if a != b || c != d || e != f
    echoerr printf('%s failed', a:name)
  endif
endfunction

let i = 1
while filereadable(printf('%s/test%d_old.txt', s:dir, i))
  call s:test(printf('test%d', i))
  let i += 1
endwhile
