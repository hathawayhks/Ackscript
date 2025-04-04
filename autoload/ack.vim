if exists('g:autoloaded_ack') || &cp   finish endif
if exists('g:ack_use_dispatch')   
   if g:ack_use_dispatch && !exists(':Dispatch')     
     call s:Warn('Dispatch not loaded! Falling back to g:ack_use_dispatch = 0.')     
     let g:ack_use_dispatch = 0   
   endif 
else   
   let g:ack_use_dispatch = 0 
endif

function! ack#Ack(cmd, args) 
   call s:Init(a:cmd)   
   redraw    
   let l:grepprg = g:ackprg   
   let l:grepformat = '%f:%l:%c:%m,%f:%l:%m'  
   if s:SearchingFilepaths()     
     let l:grepprg = substitute(l:grepprg, '-H\|--column', '', 'g')     
     let l:grepformat = '%f'   
   endif    
   if empty(a:args)     
     if !g:ack_use_cword_for_empty_search       
       echo "Regular expression?."       
       return     
     endif   
   endif    
   let l:grepargs = empty(a:args) ? expand("<cword>") : a:args . join(a:000, ' ')    
   if l:grepargs == ""     
     echo "."     
     return   
   endif    
   let l:escaped_args = escape(l:grepargs, '|#%')    
   echo "Searching ..."    
   if g:ack_use_dispatch     
     call s:SearchWithDispatch(l:grepprg, l:escaped_args, l:grepformat)   
   else     
     call s:SearchWithGrep(a:cmd, l:grepprg, l:escaped_args, l:grepformat)   
   endif    
   call ack#ShowResults()   
   call s:Highlight(l:grepargs) 
endfunction

function! ack#AckFromSearch(cmd, args) 
   let search = getreg('/')   
   let search = substitute(search, '\(\\<\|\\>\)', '\\b', 'g')   
   call ack#Ack(a:cmd, '"' . search . '" ' . a:args) 
endfunction

function! ack#AckHelp(cmd, args) 
   let args = a:args . ' ' . s:GetDocLocations()   
   call ack#Ack(a:cmd, args) 
endfunction

function! ack#AckWindow(cmd, args) 
   let files = tabpagebuflist()    
   let files = filter(copy(sort(files)), 'index(files,v:val,v:key+1)==-1')   
   call map(files, "bufname(v:val)")    
   call filter(files, 'v:val != ""')    
   let files = map(files, "shellescape(fnamemodify(v:val, ':p'))")   
   let args = a:args . ' ' . join(files)    
   call ack#Ack(a:cmd, args) 
endfunction

function! ack#ShowResults() 
   let l:handler = s:UsingLocList() ? g:ack_lhandler : g:ack_qhandler   
   execute l:handler   
   call s:ApplyMappings()   
   redraw! 
endfunction

function! s:ApplyMappings() 
   if !s:UsingListMappings() || &filetype != 'qf'     
     return   
   endif    
   let l:wintype = s:UsingLocList() ? 'l' : 'c'   
   let l:closemap = ':' . l:wintype . 'close<CR>'   
   let g:ack_mappings.q = l:closemap    
   nnoremap <buffer> <silent> ? :call <SID>QuickHelp()<CR>    
   if g:ack_autoclose     
     for key_map in items(g:ack_mappings)       
       execute printf("nnoremap <buffer> <silent> %s %s", get(key_map, 0), get(key_map, 1) . l:closemap)     
     endfor      
     execute "nnoremap <buffer> <silent> <CR> <CR>" . l:closemap   
   else     
     for key_map in items(g:ack_mappings)       
       execute printf("nnoremap <buffer> <silent> %s %s", get(key_map, 0), get(key_map, 1))     
     endfor   
   endif    
   if exists("g:ackpreview") 
     nnoremap <buffer> <silent> j j<CR><C-W><C-P>     
     nnoremap <buffer> <silent> k k<CR><C-W><C-P>     
     nmap <buffer> <silent> <Down> j     
     nmap <buffer> <silent> <Up> k   
   endif 
endfunction

function! s:GetDocLocations() 
   let dp = ''   
   for p in split(&rtp, ',')     
     let p = p . '/doc/'     
     if isdirectory(p)       
       let dp = p . '*.txt ' . dp     
     endif   
   endfor    
   return dp 
endfunction

function! s:Highlight(args) 
   if !g:ackhighlight     
     return   
   endif    
   let @/ = matchstr(a:args, "\\v(-)\@<!(\<)\@<=\\w+|['\"]\\zs.{-}\\ze['\"]")   
   call feedkeys(":let &hlsearch=1 \| echo \<CR>", "n") 
endfunction

function! s:Init(cmd) 
   let s:searching_filepaths = (a:cmd =~# '-g$') ? 1 : 0   
   let s:using_loclist       = (a:cmd =~# '^l') ? 1 : 0    
   if g:ack_use_dispatch && s:using_loclist     
     call s:Warn('Dispatch does not support location lists! Proceeding with quickfix...')     
     let s:using_loclist = 0   
   endif 
endfunction

function! s:QuickHelp() 
   execute 'edit' globpath(&rtp, 'doc/ack_quick_help.txt')    
   silent normal gg   
   setlocal buftype=nofile bufhidden=hide nobuflisted   
   setlocal nomodifiable noswapfile   
   setlocal filetype=help   
   setlocal nonumber norelativenumber nowrap   
   setlocal foldmethod=diff foldlevel=20    
   nnoremap <buffer> <silent> ? :q!<CR>:call ack#ShowResults()<CR> 
endfunction

function! s:SearchWithDispatch(grepprg, grepargs, grepformat) 
   let l:makeprg_bak     = &l:makeprg   
   let l:errorformat_bak = &l:errorformat    
   if s:SearchingFilepaths()     
     let l:grepprg = a:grepprg . ' -g'   
   else     
     let l:grepprg = a:grepprg   
   endif    
   try     
     let &l:makeprg     = l:grepprg . ' ' . a:grepargs     
     let &l:errorformat = a:grepformat      
     Make   
   finally     
     let &l:makeprg     = l:makeprg_bak     
     let &l:errorformat = l:errorformat_bak   
   endtry 
endfunction

function! s:SearchWithGrep(grepcmd, grepprg, grepargs, grepformat) 
   let l:grepprg_bak    = &l:grepprg   
   let l:grepformat_bak = &grepformat    
   try     
     let &l:grepprg  = a:grepprg     
     let &grepformat = a:grepformat      
     silent execute a:grepcmd a:grepargs   
   finally     
     let &l:grepprg  = l:grepprg_bak     
     let &grepformat = l:grepformat_bak   
   endtry 
endfunction

function! s:SearchingFilepaths() 
   return get(s:, 'searching_filepaths', 0) 
endfunction

function! s:UsingListMappings() 
   if s:UsingLocList()     
     return g:ack_apply_lmappings   
   else     
     return g:ack_apply_qmappings   
   endif 
endfunction

function! s:UsingLocList() 
   return get(s:, 'using_loclist', 0) 
endfunction

function! s:Warn(msg) 
   echohl WarningMsg | echomsg 'Ack: ' . a:msg | echohl None 
endfunction

let g:autoloaded_ack = 1
