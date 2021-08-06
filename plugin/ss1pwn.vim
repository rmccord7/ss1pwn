fun! SS1Pwn()
  lua for k in pairs(package.loaded) do if k:match("^SS1Pwn") then package.loaded[k] = nil end end
  lua require('ss1pwn')
endfun

augroup SS1Pwn
  autocmd!
augroup END
