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
    let g:terminal_ansi_colors = ['17130b', 'ffb4ab', 'ebc16c', 'b2cfa8',
                                \ 'd9c4a0', 'b2cfa8', 'ebc16c', 'd1c5b4',
                                \ '241f17', 'ffb4ab', 'ebc16c', 'b2cfa8',
                                \ 'd9c4a0', 'b2cfa8', 'ebc16c', 'ebe1d4']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['ebe1d4', 'ffb4ab', 'ebc16c', 'b2cfa8',
                                \ 'd9c4a0', 'b2cfa8', 'ebc16c', '4d4639',
                                \ 'd1c5b4', 'ffb4ab', 'ebc16c', 'b2cfa8',
                                \ 'd9c4a0', 'b2cfa8', 'ebc16c', '17130b']
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
    return 'ebc16c'
  else
    return 'd9c4a0'
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
  hi Normal guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi Pmenu guibg=#4d4639 guifg=#ebe1d4 gui=NONE cterm=NONE
  hi StatusLine guifg=#ebe1d4 guibg=#4d4639 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#d1c5b4 guibg=#241f17 gui=NONE cterm=NONE
  hi VertSplit guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#d1c5b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#241f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#ebc16c guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#d1c5b4 guibg=#4d4639 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#17130b guibg=#ebc16c gui=bold cterm=bold
  hi TabLineSeparator guifg=#ebc16c guibg=#4d4639 gui=NONE cterm=NONE

  " Interactive elements with dynamic contrast
  hi Search guifg=#241f17 guibg=#ebc16c gui=NONE cterm=NONE
  hi Visual guifg=#241f17 guibg=#ebc16c gui=NONE cterm=NONE
  hi MatchParen guifg=#241f17 guibg=#ebc16c gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#ebc16c guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#ebc16c guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#d1c5b4 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#ebe1d4 guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#d1c5b4 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#d1c5b4 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#241f17 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#4d4639 gui=NONE cterm=NONE
  hi Cursor guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi lCursor guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorIM guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursor guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d1c5b4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#ebc16c guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#241f17 guibg=#ebc16c gui=NONE cterm=NONE
  hi IncSearch guifg=#241f17 guibg=#ebc16c gui=NONE cterm=NONE
  hi NormalNC guibg=#241f17 guifg=#d1c5b4 gui=NONE cterm=NONE
  hi Directory guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#241f17 guibg=#ebc16c gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#ebc16c guibg=#241f17 gui=NONE cterm=NONE
  hi FoldColumn guifg=#d1c5b4 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#ebe1d4 guibg=#4d4639 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#ebe1d4 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#ebc16c guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#ebe1d4 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#ebc16c guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#ebc16c guifg=#17130b gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in dark mode
  hi WinBar guifg=#ebe1d4 guibg=#4d4639 gui=bold cterm=bold
  hi WinBarNC guifg=#d1c5b4 guibg=#241f17 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#ebc16c guifg=#17130b gui=bold cterm=bold
  hi BufferTabpageFill guibg=#17130b guifg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#ebe1d4 guibg=#ebc16c gui=bold cterm=bold
  hi BufferCurrentMod guifg=#ebe1d4 guibg=#ebc16c gui=bold cterm=bold
  hi BufferCurrentSign guifg=#ebc16c guibg=#241f17 gui=NONE cterm=NONE
  hi BufferVisible guifg=#ebe1d4 guibg=#4d4639 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#d1c5b4 guibg=#4d4639 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#ebc16c guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactive guifg=#d1c5b4 guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#ebc16c guibg=#241f17 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#ebc16c guibg=#241f17 gui=NONE cterm=NONE

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
  hi Pmenu guibg=#d1c5b4 guifg=#17130b gui=NONE cterm=NONE
  hi StatusLine guifg=#ebe1d4 guibg=#b2cfa8 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#17130b guibg=#d1c5b4 gui=NONE cterm=NONE
  hi VertSplit guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#241f17 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#d1c5b4 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#d9c4a0 guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#17130b guibg=#d1c5b4 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#ebe1d4 guibg=#d9c4a0 gui=bold cterm=bold
  hi TabLineSeparator guifg=#b2cfa8 guibg=#d1c5b4 gui=NONE cterm=NONE

  " Interactive elements with complementary contrast
  hi Search guifg=#ebe1d4 guibg=#d9c4a0 gui=NONE cterm=NONE
  hi Visual guifg=#ebe1d4 guibg=#b2cfa8 gui=NONE cterm=NONE
  hi MatchParen guifg=#ebe1d4 guibg=#d9c4a0 gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#d9c4a0 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#d9c4a0 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#241f17 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#17130b guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#4d4639 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#4d4639 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#d1c5b4 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#d1c5b4 gui=NONE cterm=NONE
  hi Cursor guibg=#17130b guifg=#ebe1d4 gui=NONE cterm=NONE
  hi lCursor guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorIM guibg=#ebe1d4 guifg=#17130b gui=NONE cterm=NONE
  hi TermCursor guibg=#17130b guifg=#ebe1d4 gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d1c5b4 guifg=#17130b gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#d9c4a0 guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#ebe1d4 guibg=#d9c4a0 gui=NONE cterm=NONE
  hi IncSearch guifg=#ebe1d4 guibg=#d9c4a0 gui=NONE cterm=NONE
  hi NormalNC guibg=#ebe1d4 guifg=#241f17 gui=NONE cterm=NONE
  hi Directory guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#ebe1d4 guibg=#d9c4a0 gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#d9c4a0 guibg=#ebe1d4 gui=NONE cterm=NONE
  hi FoldColumn guifg=#241f17 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#17130b guibg=#d1c5b4 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#17130b gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#d9c4a0 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#17130b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#d9c4a0 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#d9c4a0 guifg=#ebe1d4 gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in light mode
  hi WinBar guifg=#17130b guibg=#d1c5b4 gui=bold cterm=bold
  hi WinBarNC guifg=#241f17 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#d9c4a0 guifg=#ebe1d4 gui=bold cterm=bold
  hi BufferTabpageFill guibg=#ebe1d4 guifg=#4d4639 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#ebe1d4 guibg=#d9c4a0 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#ebe1d4 guibg=#d9c4a0 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#d9c4a0 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferVisible guifg=#17130b guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#241f17 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#d9c4a0 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferInactive guifg=#4d4639 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#d9c4a0 guibg=#d1c5b4 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#d9c4a0 guibg=#d1c5b4 gui=NONE cterm=NONE

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
hi FloatBorder guifg=#b2cfa8 guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#ebe1d4 guibg=#ebc16c gui=NONE cterm=NONE
hi DiffChange guifg=#ebe1d4 guibg=#b2cfa8 gui=NONE cterm=NONE
hi DiffDelete guifg=#ebe1d4 guibg=#ffb4ab gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#b2cfa8 guifg=#17130b gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#ebe1d4 guibg=#b2cfa8 gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#b2cfa8 guifg=#17130b gui=bold cterm=bold
hi TelescopeMatching guifg=#ffb4ab guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#b2cfa8 guifg=#17130b gui=bold

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
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#ebe1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#d1c5b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#ebe1d4 ctermbg=NONE

  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#ebe1d4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#d1c5b4 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#ebe1d4 ctermbg=NONE

  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#b2cfa8 guifg=#17130b gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#b2cfa8 guifg=#17130b gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#d9c4a0 guifg=#ebe1d4 gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#d9c4a0 guifg=#ebe1d4 gui=bold cterm=bold |
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
