" Name:         wabi
" Description:  wabi colorscheme template
" Author:       wabi
" License:      Same as Vim
" Last Change:  June 2026

if exists('g:loaded_matugen') | finish | endif
let g:loaded_matugen = 1


" Detect background based on terminal colors
if $BACKGROUND =~# 'light'
  set background=light
else
  set background=dark
endif

" hi clear
let g:colors_name = 'matugen'

let s:t_Co = &t_Co

" Terminal color setup
if (has('termguicolors') && &termguicolors) || has('gui_running')
  let s:is_dark = &background == 'dark'

  " Define terminal colors based on the background
  if s:is_dark
    let g:terminal_ansi_colors = ['16130b', 'ffb4ab', 'e4c36c', 'adcfad',
                                \ 'd5c5a0', 'adcfad', 'e4c36c', 'cfc5b4',
                                \ '231f17', 'ffb4ab', 'e4c36c', 'adcfad',
                                \ 'd5c5a0', 'adcfad', 'e4c36c', 'eae1d4']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['eae1d4', 'ffb4ab', 'e4c36c', 'adcfad',
                                \ 'd5c5a0', 'adcfad', 'e4c36c', '4c4639',
                                \ 'cfc5b4', 'ffb4ab', 'e4c36c', 'adcfad',
                                \ 'd5c5a0', 'adcfad', 'e4c36c', '16130b']
  endif

  " Nvim uses g:terminal_color_{0-15} instead
  for i in range(g:terminal_ansi_colors->len())
    let g:terminal_color_{i} = g:terminal_ansi_colors[i]
  endfor
endif

      " For Neovim compatibility
      if has('nvim')
        " Set Neovim specific terminal colors
        let g:terminal_color_0 = '#' . g:terminal_ansi_colors[0]
        let g:terminal_color_1 = '#' . g:terminal_ansi_colors[1]
        let g:terminal_color_2 = '#' . g:terminal_ansi_colors[2]
        let g:terminal_color_3 = '#' . g:terminal_ansi_colors[3]
        let g:terminal_color_4 = '#' . g:terminal_ansi_colors[4]
        let g:terminal_color_5 = '#' . g:terminal_ansi_colors[5]
        let g:terminal_color_6 = '#' . g:terminal_ansi_colors[6]
        let g:terminal_color_7 = '#' . g:terminal_ansi_colors[7]
        let g:terminal_color_8 = '#' . g:terminal_ansi_colors[8]
        let g:terminal_color_9 = '#' . g:terminal_ansi_colors[9]
        let g:terminal_color_10 = '#' . g:terminal_ansi_colors[10]
        let g:terminal_color_11 = '#' . g:terminal_ansi_colors[11]
        let g:terminal_color_12 = '#' . g:terminal_ansi_colors[12]
        let g:terminal_color_13 = '#' . g:terminal_ansi_colors[13]
        let g:terminal_color_14 = '#' . g:terminal_ansi_colors[14]
        let g:terminal_color_15 = '#' . g:terminal_ansi_colors[15]
      endif

" Function to dynamically invert colors for UI elements
function! s:inverse_color(color)
  " This function takes a hex color (without #) and returns its inverse
  " Convert hex to decimal values
  let r = str2nr(a:color[0:1], 16)
  let g = str2nr(a:color[2:3], 16)
  let b = str2nr(a:color[4:5], 16)

  " Calculate inverse (255 - value)
  let r_inv = 255 - r
  let g_inv = 255 - g
  let b_inv = 255 - b

  " Convert back to hex
  return printf('%02x%02x%02x', r_inv, g_inv, b_inv)
endfunction

" Function to be called for selection background
function! InverseSelectionBg()
  if &background == 'dark'
    return 'e4c36c'
  else
    return 'd5c5a0'
  endif
endfunction

" Add high-contrast dynamic selection highlighting using the inverse color function
augroup MatugenDynamicHighlight
  autocmd!
  " Update selection highlight when matugen colors change
  autocmd ColorScheme matugen call s:update_dynamic_highlights()
augroup END

function! s:update_dynamic_highlights()
  let l:bg_color = synIDattr(synIDtrans(hlID('Normal')), 'bg#')
  if l:bg_color != ''
    let l:bg_color = l:bg_color[1:] " Remove # from hex color
    let l:inverse = s:inverse_color(l:bg_color)

    " Apply inverse color to selection highlights
    execute 'highlight! CursorSelection guifg=' . l:bg_color . ' guibg=#' . l:inverse

    " Link dynamic highlights to various selection groups
    highlight! link NeoTreeCursorLine CursorSelection
    highlight! link TelescopeSelection CursorSelection
    highlight! link CmpItemSelected CursorSelection
    highlight! link PmenuSel CursorSelection
    highlight! link WinSeparator VertSplit
  endif
endfunction

" Make selection visible right away for current colorscheme
call s:update_dynamic_highlights()

" Conditional highlighting based on background
if &background == 'dark'
  " Base UI elements with transparent backgrounds
  hi Normal guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi Pmenu guibg=#4c4639 guifg=#eae1d4 gui=NONE cterm=NONE
  hi StatusLine guifg=#eae1d4 guibg=#4c4639 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#cfc5b4 guibg=#231f17 gui=NONE cterm=NONE
  hi VertSplit guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#cfc5b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#231f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#e4c36c guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#cfc5b4 guibg=#4c4639 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#16130b guibg=#e4c36c gui=bold cterm=bold
  hi TabLineSeparator guifg=#e4c36c guibg=#4c4639 gui=NONE cterm=NONE

  " Interactive elements with dynamic contrast
  hi Search guifg=#231f17 guibg=#e4c36c gui=NONE cterm=NONE
  hi Visual guifg=#231f17 guibg=#e4c36c gui=NONE cterm=NONE
  hi MatchParen guifg=#231f17 guibg=#e4c36c gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#e4c36c guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#e4c36c guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#cfc5b4 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#eae1d4 guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#cfc5b4 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#cfc5b4 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#231f17 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#4c4639 gui=NONE cterm=NONE
  hi Cursor guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi lCursor guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi CursorIM guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi TermCursor guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi TermCursorNC guibg=#cfc5b4 guifg=#16130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#e4c36c guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#231f17 guibg=#e4c36c gui=NONE cterm=NONE
  hi IncSearch guifg=#231f17 guibg=#e4c36c gui=NONE cterm=NONE
  hi NormalNC guibg=#231f17 guifg=#cfc5b4 gui=NONE cterm=NONE
  hi Directory guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#231f17 guibg=#e4c36c gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#e4c36c guibg=#231f17 gui=NONE cterm=NONE
  hi FoldColumn guifg=#cfc5b4 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#eae1d4 guibg=#4c4639 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#eae1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#e4c36c guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#eae1d4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#e4c36c guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#e4c36c guifg=#16130b gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in dark mode
  hi WinBar guifg=#eae1d4 guibg=#4c4639 gui=bold cterm=bold
  hi WinBarNC guifg=#cfc5b4 guibg=#231f17 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#e4c36c guifg=#16130b gui=bold cterm=bold
  hi BufferTabpageFill guibg=#16130b guifg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#eae1d4 guibg=#e4c36c gui=bold cterm=bold
  hi BufferCurrentMod guifg=#eae1d4 guibg=#e4c36c gui=bold cterm=bold
  hi BufferCurrentSign guifg=#e4c36c guibg=#231f17 gui=NONE cterm=NONE
  hi BufferVisible guifg=#eae1d4 guibg=#4c4639 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#cfc5b4 guibg=#4c4639 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#e4c36c guibg=#231f17 gui=NONE cterm=NONE
  hi BufferInactive guifg=#cfc5b4 guibg=#231f17 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#e4c36c guibg=#231f17 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#e4c36c guibg=#231f17 gui=NONE cterm=NONE

  " Fix link colors to make them more visible
  hi link Hyperlink NONE
  hi link markdownLinkText NONE
  hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline cterm=underline
  hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline

  " Add more direct highlights for badges in markdown
  hi markdownH1 guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkTextDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold cterm=bold
else
  " Light theme with transparent backgrounds
  hi Normal guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi Pmenu guibg=#cfc5b4 guifg=#16130b gui=NONE cterm=NONE
  hi StatusLine guifg=#eae1d4 guibg=#adcfad gui=NONE cterm=NONE
  hi StatusLineNC guifg=#16130b guibg=#cfc5b4 gui=NONE cterm=NONE
  hi VertSplit guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#231f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#cfc5b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#d5c5a0 guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#16130b guibg=#cfc5b4 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#eae1d4 guibg=#d5c5a0 gui=bold cterm=bold
  hi TabLineSeparator guifg=#adcfad guibg=#cfc5b4 gui=NONE cterm=NONE

  " Interactive elements with complementary contrast
  hi Search guifg=#eae1d4 guibg=#d5c5a0 gui=NONE cterm=NONE
  hi Visual guifg=#eae1d4 guibg=#adcfad gui=NONE cterm=NONE
  hi MatchParen guifg=#eae1d4 guibg=#d5c5a0 gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#d5c5a0 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#d5c5a0 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#231f17 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#16130b guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#4c4639 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#4c4639 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#cfc5b4 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#cfc5b4 gui=NONE cterm=NONE
  hi Cursor guibg=#16130b guifg=#eae1d4 gui=NONE cterm=NONE
  hi lCursor guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi CursorIM guibg=#eae1d4 guifg=#16130b gui=NONE cterm=NONE
  hi TermCursor guibg=#16130b guifg=#eae1d4 gui=NONE cterm=NONE
  hi TermCursorNC guibg=#cfc5b4 guifg=#16130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#d5c5a0 guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#eae1d4 guibg=#d5c5a0 gui=NONE cterm=NONE
  hi IncSearch guifg=#eae1d4 guibg=#d5c5a0 gui=NONE cterm=NONE
  hi NormalNC guibg=#eae1d4 guifg=#231f17 gui=NONE cterm=NONE
  hi Directory guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#eae1d4 guibg=#d5c5a0 gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#d5c5a0 guibg=#eae1d4 gui=NONE cterm=NONE
  hi FoldColumn guifg=#231f17 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#16130b guibg=#cfc5b4 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#16130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#d5c5a0 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#16130b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#d5c5a0 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#d5c5a0 guifg=#eae1d4 gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in light mode
  hi WinBar guifg=#16130b guibg=#cfc5b4 gui=bold cterm=bold
  hi WinBarNC guifg=#231f17 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#d5c5a0 guifg=#eae1d4 gui=bold cterm=bold
  hi BufferTabpageFill guibg=#eae1d4 guifg=#4c4639 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#eae1d4 guibg=#d5c5a0 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#eae1d4 guibg=#d5c5a0 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#d5c5a0 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferVisible guifg=#16130b guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#231f17 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#d5c5a0 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferInactive guifg=#4c4639 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#d5c5a0 guibg=#cfc5b4 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#d5c5a0 guibg=#cfc5b4 gui=NONE cterm=NONE

  " Fix link colors to make them more visible
  hi link Hyperlink NONE
  hi link markdownLinkText NONE
  hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline
  hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline cterm=underline
  hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline

  " Add more direct highlights for badges in markdown
  hi markdownH1 guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownLinkTextDelimiter guifg=#FF00FF guibg=NONE gui=bold cterm=bold
  hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold cterm=bold
endif

" UI elements that are the same in both themes with transparent backgrounds
hi NormalFloat guibg=NONE guifg=NONE gui=NONE cterm=NONE
hi FloatBorder guifg=#adcfad guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#eae1d4 guibg=#e4c36c gui=NONE cterm=NONE
hi DiffChange guifg=#eae1d4 guibg=#adcfad gui=NONE cterm=NONE
hi DiffDelete guifg=#eae1d4 guibg=#ffb4ab gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#adcfad guifg=#16130b gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#eae1d4 guibg=#adcfad gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#adcfad guifg=#16130b gui=bold cterm=bold
hi TelescopeMatching guifg=#ffb4ab guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#adcfad guifg=#16130b gui=bold

" Fix for LazyVim menu selection highlighting
hi Visual guibg=#ffb4ab guifg=#16130b gui=bold
hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
hi PmenuSel guibg=#ffb4ab guifg=#16130b gui=bold
hi WildMenu guibg=#ffb4ab guifg=#16130b gui=bold

" Create improved autocommands to ensure highlighting persists with NeoTree focus fixes
augroup MatugenSelectionFix
  autocmd!
  " Force these persistent highlights with transparent backgrounds where possible
  autocmd ColorScheme * if &background == 'dark' |
    \ hi Normal guibg=NONE |
    \ hi NeoTreeNormal guibg=NONE |
    \ hi SignColumn guibg=NONE |
    \ hi NormalFloat guibg=NONE |
    \ hi FloatBorder guibg=NONE |
    \ hi TabLineFill guibg=NONE |
    \ else |
    \ hi Normal guibg=NONE |
    \ hi NeoTreeNormal guibg=NONE |
    \ hi SignColumn guibg=NONE |
    \ hi NormalFloat guibg=NONE |
    \ hi FloatBorder guibg=NONE |
    \ hi TabLineFill guibg=NONE |
    \ endif

  " Force NeoTree background to be transparent even when unfocused
  autocmd WinEnter,WinLeave,BufEnter,BufLeave * if &ft == 'neo-tree' || &ft == 'NvimTree' |
    \ hi NeoTreeNormal guibg=NONE |
    \ hi NeoTreeEndOfBuffer guibg=NONE |
    \ endif

  " Fix NeoTree unfocus issue specifically in LazyVim
  autocmd VimEnter,ColorScheme * hi link NeoTreeNormalNC NeoTreeNormal

  " Make CursorLine less obtrusive by using underline instead of background
  autocmd ColorScheme * hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline

  " Make links visible across modes
  autocmd ColorScheme * if &background == 'dark' |
    \ hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline |
    \ hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold |
    \ else |
    \ hi Underlined guifg=#FF00FF guibg=NONE gui=bold,underline cterm=bold,underline |
    \ hi Special guifg=#FF00FF guibg=NONE gui=bold cterm=bold |
    \ endif

  " Fix markdown links specifically
  autocmd FileType markdown hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline,bold
  autocmd FileType markdown hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline
augroup END

" Create a more aggressive fix for NeoTree background in LazyVim
augroup FixNeoTreeBackground
  autocmd!
  " Force NONE background for NeoTree at various points to override tokyonight fallback
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#eae1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#cfc5b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#eae1d4 ctermbg=NONE

  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#eae1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#cfc5b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#eae1d4 ctermbg=NONE

  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#adcfad guifg=#16130b gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#adcfad guifg=#16130b gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#d5c5a0 guifg=#eae1d4 gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#d5c5a0 guifg=#eae1d4 gui=bold cterm=bold |
    \ endif

  " Force execution after other plugins have loaded
  autocmd VimEnter * doautocmd ColorScheme
augroup END

" Add custom autocommand specifically for LazyVim markdown links
augroup LazyVimMarkdownFix
  autocmd!
  " Force link visibility in LazyVim with stronger override
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownUrl MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLinkText MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLink MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! def link markdownLinkDelimiter MagentaLink
  autocmd FileType markdown,markdown.mdx,markdown.gfm hi! MagentaLink guifg=#FF00FF gui=bold,underline

  " Apply when LazyVim is detected
  autocmd User LazyVimStarted doautocmd FileType markdown
  autocmd VimEnter * if exists('g:loaded_lazy') | doautocmd FileType markdown | endif
augroup END

" Add custom autocommand specifically for markdown files with links
augroup MarkdownLinkFix
  autocmd!
  " Use bright hardcoded magenta that will definitely be visible
  autocmd FileType markdown hi markdownUrl guifg=#FF00FF guibg=NONE gui=underline,bold
  autocmd FileType markdown hi markdownLinkText guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi markdownIdDeclaration guifg=#FF00FF guibg=NONE gui=bold
  autocmd FileType markdown hi htmlLink guifg=#FF00FF guibg=NONE gui=bold,underline

  " Force these highlights right after vim loads
  autocmd VimEnter * if &ft == 'markdown' | doautocmd FileType markdown | endif
augroup END

" Remove possibly conflicting previous autocommands
augroup LazyVimFix
  autocmd!
augroup END

augroup MinimalExplorerFix
  autocmd!
augroup END
