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
    let g:terminal_ansi_colors = ['19120c', 'ffb4ab', 'ffb77b', 'c4cb97',
                                \ 'e3c0a5', 'c4cb97', 'ffb77b', 'd6c3b6',
                                \ '261e18', 'ffb4ab', 'ffb77b', 'c4cb97',
                                \ 'e3c0a5', 'c4cb97', 'ffb77b', 'efe0d6']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['efe0d6', 'ffb4ab', 'ffb77b', 'c4cb97',
                                \ 'e3c0a5', 'c4cb97', 'ffb77b', '51443b',
                                \ 'd6c3b6', 'ffb4ab', 'ffb77b', 'c4cb97',
                                \ 'e3c0a5', 'c4cb97', 'ffb77b', '19120c']
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
    return 'ffb77b'
  else
    return 'e3c0a5'
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
  hi Normal guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi Pmenu guibg=#51443b guifg=#efe0d6 gui=NONE cterm=NONE
  hi StatusLine guifg=#efe0d6 guibg=#51443b gui=NONE cterm=NONE
  hi StatusLineNC guifg=#d6c3b6 guibg=#261e18 gui=NONE cterm=NONE
  hi VertSplit guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#d6c3b6 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#261e18 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#ffb77b guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#d6c3b6 guibg=#51443b gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#19120c guibg=#ffb77b gui=bold cterm=bold
  hi TabLineSeparator guifg=#ffb77b guibg=#51443b gui=NONE cterm=NONE

  " Interactive elements with dynamic contrast
  hi Search guifg=#261e18 guibg=#ffb77b gui=NONE cterm=NONE
  hi Visual guifg=#261e18 guibg=#ffb77b gui=NONE cterm=NONE
  hi MatchParen guifg=#261e18 guibg=#ffb77b gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#ffb77b guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#ffb77b guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#d6c3b6 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#efe0d6 guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#d6c3b6 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#d6c3b6 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#261e18 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#51443b gui=NONE cterm=NONE
  hi Cursor guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi lCursor guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi CursorIM guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi TermCursor guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d6c3b6 guifg=#19120c gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#ffb77b guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#261e18 guibg=#ffb77b gui=NONE cterm=NONE
  hi IncSearch guifg=#261e18 guibg=#ffb77b gui=NONE cterm=NONE
  hi NormalNC guibg=#261e18 guifg=#d6c3b6 gui=NONE cterm=NONE
  hi Directory guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#261e18 guibg=#ffb77b gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#ffb77b guibg=#261e18 gui=NONE cterm=NONE
  hi FoldColumn guifg=#d6c3b6 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#efe0d6 guibg=#51443b gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#efe0d6 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#ffb77b guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#efe0d6 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#ffb77b guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#ffb77b guifg=#19120c gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in dark mode
  hi WinBar guifg=#efe0d6 guibg=#51443b gui=bold cterm=bold
  hi WinBarNC guifg=#d6c3b6 guibg=#261e18 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#ffb77b guifg=#19120c gui=bold cterm=bold
  hi BufferTabpageFill guibg=#19120c guifg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#efe0d6 guibg=#ffb77b gui=bold cterm=bold
  hi BufferCurrentMod guifg=#efe0d6 guibg=#ffb77b gui=bold cterm=bold
  hi BufferCurrentSign guifg=#ffb77b guibg=#261e18 gui=NONE cterm=NONE
  hi BufferVisible guifg=#efe0d6 guibg=#51443b gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#d6c3b6 guibg=#51443b gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#ffb77b guibg=#261e18 gui=NONE cterm=NONE
  hi BufferInactive guifg=#d6c3b6 guibg=#261e18 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#ffb77b guibg=#261e18 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#ffb77b guibg=#261e18 gui=NONE cterm=NONE

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
  hi Normal guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi Pmenu guibg=#d6c3b6 guifg=#19120c gui=NONE cterm=NONE
  hi StatusLine guifg=#efe0d6 guibg=#c4cb97 gui=NONE cterm=NONE
  hi StatusLineNC guifg=#19120c guibg=#d6c3b6 gui=NONE cterm=NONE
  hi VertSplit guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#261e18 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#d6c3b6 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#e3c0a5 guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#19120c guibg=#d6c3b6 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#efe0d6 guibg=#e3c0a5 gui=bold cterm=bold
  hi TabLineSeparator guifg=#c4cb97 guibg=#d6c3b6 gui=NONE cterm=NONE

  " Interactive elements with complementary contrast
  hi Search guifg=#efe0d6 guibg=#e3c0a5 gui=NONE cterm=NONE
  hi Visual guifg=#efe0d6 guibg=#c4cb97 gui=NONE cterm=NONE
  hi MatchParen guifg=#efe0d6 guibg=#e3c0a5 gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#e3c0a5 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#e3c0a5 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#261e18 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#19120c guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#51443b guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#51443b guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#d6c3b6 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#d6c3b6 gui=NONE cterm=NONE
  hi Cursor guibg=#19120c guifg=#efe0d6 gui=NONE cterm=NONE
  hi lCursor guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi CursorIM guibg=#efe0d6 guifg=#19120c gui=NONE cterm=NONE
  hi TermCursor guibg=#19120c guifg=#efe0d6 gui=NONE cterm=NONE
  hi TermCursorNC guibg=#d6c3b6 guifg=#19120c gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#e3c0a5 guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#efe0d6 guibg=#e3c0a5 gui=NONE cterm=NONE
  hi IncSearch guifg=#efe0d6 guibg=#e3c0a5 gui=NONE cterm=NONE
  hi NormalNC guibg=#efe0d6 guifg=#261e18 gui=NONE cterm=NONE
  hi Directory guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#efe0d6 guibg=#e3c0a5 gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#e3c0a5 guibg=#efe0d6 gui=NONE cterm=NONE
  hi FoldColumn guifg=#261e18 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#19120c guibg=#d6c3b6 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#19120c gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#e3c0a5 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#19120c guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#e3c0a5 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#e3c0a5 guifg=#efe0d6 gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in light mode
  hi WinBar guifg=#19120c guibg=#d6c3b6 gui=bold cterm=bold
  hi WinBarNC guifg=#261e18 guibg=#d6c3b6 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#e3c0a5 guifg=#efe0d6 gui=bold cterm=bold
  hi BufferTabpageFill guibg=#efe0d6 guifg=#51443b gui=NONE cterm=NONE
  hi BufferCurrent guifg=#efe0d6 guibg=#e3c0a5 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#efe0d6 guibg=#e3c0a5 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#e3c0a5 guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferVisible guifg=#19120c guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#261e18 guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#e3c0a5 guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferInactive guifg=#51443b guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#e3c0a5 guibg=#d6c3b6 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#e3c0a5 guibg=#d6c3b6 gui=NONE cterm=NONE

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
hi FloatBorder guifg=#c4cb97 guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#efe0d6 guibg=#ffb77b gui=NONE cterm=NONE
hi DiffChange guifg=#efe0d6 guibg=#c4cb97 gui=NONE cterm=NONE
hi DiffDelete guifg=#efe0d6 guibg=#ffb4ab gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#c4cb97 guifg=#19120c gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#efe0d6 guibg=#c4cb97 gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#c4cb97 guifg=#19120c gui=bold cterm=bold
hi TelescopeMatching guifg=#ffb4ab guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#c4cb97 guifg=#19120c gui=bold

" Fix for LazyVim menu selection highlighting
hi Visual guibg=#ffb4ab guifg=#19120c gui=bold
hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
hi PmenuSel guibg=#ffb4ab guifg=#19120c gui=bold
hi WildMenu guibg=#ffb4ab guifg=#19120c gui=bold

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
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#efe0d6 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#d6c3b6 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#efe0d6 ctermbg=NONE

  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#efe0d6 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#d6c3b6 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#efe0d6 ctermbg=NONE

  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#c4cb97 guifg=#19120c gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#c4cb97 guifg=#19120c gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#e3c0a5 guifg=#efe0d6 gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#e3c0a5 guifg=#efe0d6 gui=bold cterm=bold |
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
