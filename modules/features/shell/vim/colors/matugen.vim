" Name:         wabi
" Description:  wabi colorscheme template
" Author:       wabi
" License:      Same as Vim
" Last Change:  June 2026

if exists('g:loaded_matugen') | finish | endif
let g:loaded_matugen = 1


" Set background based on wabi switcher
set background=dark

" hi clear
let g:colors_name = 'matugen'

let s:t_Co = &t_Co

" Terminal color setup
if (has('termguicolors') && &termguicolors) || has('gui_running')
  let s:is_dark = &background == 'dark'

  " Define terminal colors based on the background
  if s:is_dark
    let g:terminal_ansi_colors = ['17130b', 'ffb4ab', 'f0bf6d', 'b5cea4',
                                \ 'dbc3a1', 'b5cea4', 'f0bf6d', 'd2c4b4',
                                \ '241f17', 'ffb4ab', 'f0bf6d', 'b5cea4',
                                \ 'dbc3a1', 'b5cea4', 'f0bf6d', 'ece1d4']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['ece1d4', 'ffb4ab', 'f0bf6d', 'b5cea4',
                                \ 'dbc3a1', 'b5cea4', 'f0bf6d', '4e4539',
                                \ 'd2c4b4', 'ffb4ab', 'f0bf6d', 'b5cea4',
                                \ 'dbc3a1', 'b5cea4', 'f0bf6d', '17130b']
  endif

  " Nvim uses g:terminal_color_{0-15} instead
  for i in range(g:terminal_ansi_colors->len())
    let g:terminal_color_{i} = g:terminal_ansi_colors[i]
  endfor
endif

      " For Neovim compatibility
      if has('nvim') && exists('g:terminal_ansi_colors')
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
    return 'f0bf6d'
  else
    return 'dbc3a1'
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
  hi Normal guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi Pmenu guibg=#4e4539 guifg=#ece1d4 gui=NONE cterm=NONE
  hi StatusLine guifg=#ece1d4 guibg=#4e4539 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#d2c4b4 guibg=#241f17 gui=NONE cterm=NONE
  hi VertSplit guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#d2c4b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#241f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#f0bf6d guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#d2c4b4 guibg=#4e4539 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#17130b guibg=#f0bf6d gui=bold cterm=bold
  hi TabLineSeparator guifg=#f0bf6d guibg=#4e4539 gui=NONE cterm=NONE

  " Interactive elements with dynamic contrast
  hi Search guifg=#241f17 guibg=#f0bf6d gui=NONE cterm=NONE
  hi Visual guifg=#241f17 guibg=#f0bf6d gui=NONE cterm=NONE
  hi MatchParen guifg=#241f17 guibg=#f0bf6d gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#f0bf6d guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#f0bf6d guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#d2c4b4 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#ece1d4 guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#d2c4b4 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#d2c4b4 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#241f17 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#4e4539 gui=NONE cterm=NONE
  hi Cursor guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi lCursor guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorIM guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursor guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d2c4b4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#f0bf6d guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#241f17 guibg=#f0bf6d gui=NONE cterm=NONE
  hi IncSearch guifg=#241f17 guibg=#f0bf6d gui=NONE cterm=NONE
  hi NormalNC guibg=#241f17 guifg=#d2c4b4 gui=NONE cterm=NONE
  hi Directory guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#241f17 guibg=#f0bf6d gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#f0bf6d guibg=#241f17 gui=NONE cterm=NONE
  hi FoldColumn guifg=#d2c4b4 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#ece1d4 guibg=#4e4539 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ece1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#f0bf6d guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#ece1d4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#f0bf6d guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#f0bf6d guifg=#17130b gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in dark mode
  hi WinBar guifg=#ece1d4 guibg=#4e4539 gui=bold cterm=bold
  hi WinBarNC guifg=#d2c4b4 guibg=#241f17 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#f0bf6d guifg=#17130b gui=bold cterm=bold
  hi BufferTabpageFill guibg=#17130b guifg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#ece1d4 guibg=#f0bf6d gui=bold cterm=bold
  hi BufferCurrentMod guifg=#ece1d4 guibg=#f0bf6d gui=bold cterm=bold
  hi BufferCurrentSign guifg=#f0bf6d guibg=#241f17 gui=NONE cterm=NONE
  hi BufferVisible guifg=#ece1d4 guibg=#4e4539 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#d2c4b4 guibg=#4e4539 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#f0bf6d guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactive guifg=#d2c4b4 guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#f0bf6d guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#f0bf6d guibg=#241f17 gui=NONE cterm=NONE

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
  hi Normal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi Pmenu guibg=#d2c4b4 guifg=#17130b gui=NONE cterm=NONE
  hi StatusLine guifg=#ece1d4 guibg=#b5cea4 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#17130b guibg=#d2c4b4 gui=NONE cterm=NONE
  hi VertSplit guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#241f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#d2c4b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#dbc3a1 guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#17130b guibg=#d2c4b4 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#ece1d4 guibg=#dbc3a1 gui=bold cterm=bold
  hi TabLineSeparator guifg=#b5cea4 guibg=#d2c4b4 gui=NONE cterm=NONE

  " Interactive elements with complementary contrast
  hi Search guifg=#ece1d4 guibg=#dbc3a1 gui=NONE cterm=NONE
  hi Visual guifg=#ece1d4 guibg=#b5cea4 gui=NONE cterm=NONE
  hi MatchParen guifg=#ece1d4 guibg=#dbc3a1 gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#dbc3a1 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#dbc3a1 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#241f17 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#17130b guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#4e4539 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#4e4539 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#d2c4b4 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#d2c4b4 gui=NONE cterm=NONE
  hi Cursor guibg=#17130b guifg=#ece1d4 gui=NONE cterm=NONE
  hi lCursor guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorIM guibg=#ece1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursor guibg=#17130b guifg=#ece1d4 gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d2c4b4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#dbc3a1 guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#ece1d4 guibg=#dbc3a1 gui=NONE cterm=NONE
  hi IncSearch guifg=#ece1d4 guibg=#dbc3a1 gui=NONE cterm=NONE
  hi NormalNC guibg=#ece1d4 guifg=#241f17 gui=NONE cterm=NONE
  hi Directory guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#ece1d4 guibg=#dbc3a1 gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#dbc3a1 guibg=#ece1d4 gui=NONE cterm=NONE
  hi FoldColumn guifg=#241f17 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#17130b guibg=#d2c4b4 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#dbc3a1 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#17130b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#dbc3a1 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#dbc3a1 guifg=#ece1d4 gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in light mode
  hi WinBar guifg=#17130b guibg=#d2c4b4 gui=bold cterm=bold
  hi WinBarNC guifg=#241f17 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#dbc3a1 guifg=#ece1d4 gui=bold cterm=bold
  hi BufferTabpageFill guibg=#ece1d4 guifg=#4e4539 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#ece1d4 guibg=#dbc3a1 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#ece1d4 guibg=#dbc3a1 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#dbc3a1 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferVisible guifg=#17130b guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#241f17 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#dbc3a1 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferInactive guifg=#4e4539 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#dbc3a1 guibg=#d2c4b4 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#dbc3a1 guibg=#d2c4b4 gui=NONE cterm=NONE

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
hi FloatBorder guifg=#b5cea4 guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#ece1d4 guibg=#f0bf6d gui=NONE cterm=NONE
hi DiffChange guifg=#ece1d4 guibg=#b5cea4 gui=NONE cterm=NONE
hi DiffDelete guifg=#ece1d4 guibg=#ffb4ab gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#b5cea4 guifg=#17130b gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#ece1d4 guibg=#b5cea4 gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#b5cea4 guifg=#17130b gui=bold cterm=bold
hi TelescopeMatching guifg=#ffb4ab guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#b5cea4 guifg=#17130b gui=bold

" Fix for LazyVim menu selection highlighting
hi Visual guibg=#ffb4ab guifg=#17130b gui=bold
hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
hi PmenuSel guibg=#ffb4ab guifg=#17130b gui=bold
hi WildMenu guibg=#ffb4ab guifg=#17130b gui=bold

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
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#ece1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#d2c4b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#ece1d4 ctermbg=NONE

  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#ece1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#d2c4b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#ece1d4 ctermbg=NONE

  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#b5cea4 guifg=#17130b gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#b5cea4 guifg=#17130b gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#dbc3a1 guifg=#ece1d4 gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#dbc3a1 guifg=#ece1d4 gui=bold cterm=bold |
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
