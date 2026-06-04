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
    let g:terminal_ansi_colors = ['12140e', 'ffb4ab', 'b3d089', 'a0d0cb',
                                \ 'c0cbac', 'a0d0cb', 'b3d089', 'c5c8b9',
                                \ '1e201a', 'ffb4ab', 'b3d089', 'a0d0cb',
                                \ 'c0cbac', 'a0d0cb', 'b3d089', 'e2e3d8']
  else
    " Lighter colors for light theme
    let g:terminal_ansi_colors = ['e2e3d8', 'ffb4ab', 'b3d089', 'a0d0cb',
                                \ 'c0cbac', 'a0d0cb', 'b3d089', '44483d',
                                \ 'c5c8b9', 'ffb4ab', 'b3d089', 'a0d0cb',
                                \ 'c0cbac', 'a0d0cb', 'b3d089', '12140e']
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
    return 'b3d089'
  else
    return 'c0cbac'
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
  hi Normal guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi Pmenu guibg=#44483d guifg=#e2e3d8 gui=NONE cterm=NONE
  hi StatusLine guifg=#e2e3d8 guibg=#44483d gui=NONE cterm=NONE
  hi StatusLineNC guifg=#c5c8b9 guibg=#1e201a gui=NONE cterm=NONE
  hi VertSplit guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#c5c8b9 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#1e201a guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#b3d089 guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#c5c8b9 guibg=#44483d gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#12140e guibg=#b3d089 gui=bold cterm=bold
  hi TabLineSeparator guifg=#b3d089 guibg=#44483d gui=NONE cterm=NONE

  " Interactive elements with dynamic contrast
  hi Search guifg=#1e201a guibg=#b3d089 gui=NONE cterm=NONE
  hi Visual guifg=#1e201a guibg=#b3d089 gui=NONE cterm=NONE
  hi MatchParen guifg=#1e201a guibg=#b3d089 gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#b3d089 guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#b3d089 guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#c5c8b9 guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#e2e3d8 guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#c5c8b9 guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#c5c8b9 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#1e201a guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#44483d gui=NONE cterm=NONE
  hi Cursor guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi lCursor guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi CursorIM guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi TermCursor guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi TermCursorNC guibg=#c5c8b9 guifg=#12140e gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#b3d089 guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#1e201a guibg=#b3d089 gui=NONE cterm=NONE
  hi IncSearch guifg=#1e201a guibg=#b3d089 gui=NONE cterm=NONE
  hi NormalNC guibg=#1e201a guifg=#c5c8b9 gui=NONE cterm=NONE
  hi Directory guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#1e201a guibg=#b3d089 gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#b3d089 guibg=#1e201a gui=NONE cterm=NONE
  hi FoldColumn guifg=#c5c8b9 guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#e2e3d8 guibg=#44483d gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#e2e3d8 gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#b3d089 guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#e2e3d8 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#b3d089 guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#b3d089 guifg=#12140e gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in dark mode
  hi WinBar guifg=#e2e3d8 guibg=#44483d gui=bold cterm=bold
  hi WinBarNC guifg=#c5c8b9 guibg=#1e201a gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#b3d089 guifg=#12140e gui=bold cterm=bold
  hi BufferTabpageFill guibg=#12140e guifg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferCurrent guifg=#e2e3d8 guibg=#b3d089 gui=bold cterm=bold
  hi BufferCurrentMod guifg=#e2e3d8 guibg=#b3d089 gui=bold cterm=bold
  hi BufferCurrentSign guifg=#b3d089 guibg=#1e201a gui=NONE cterm=NONE
  hi BufferVisible guifg=#e2e3d8 guibg=#44483d gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#c5c8b9 guibg=#44483d gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#b3d089 guibg=#1e201a gui=NONE cterm=NONE
  hi BufferInactive guifg=#c5c8b9 guibg=#1e201a gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#b3d089 guibg=#1e201a gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#b3d089 guibg=#1e201a gui=NONE cterm=NONE

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
  hi Normal guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi Pmenu guibg=#c5c8b9 guifg=#12140e gui=NONE cterm=NONE
  hi StatusLine guifg=#e2e3d8 guibg=#a0d0cb gui=NONE cterm=NONE
  hi StatusLineNC guifg=#12140e guibg=#c5c8b9 gui=NONE cterm=NONE
  hi VertSplit guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
  hi LineNr guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
  hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi FoldColumn guifg=#1e201a guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background including unfocused state
  hi NeoTreeNormal guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeFloatNormal guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeFloatBorder guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeWinSeparator guifg=#c5c8b9 guibg=NONE gui=NONE cterm=NONE

  " NeoTree with transparent background
  hi NeoTreeNormal guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#c0cbac guibg=NONE gui=bold cterm=bold

  " TabLine highlighting with complementary accents
  hi TabLine guifg=#12140e guibg=#c5c8b9 gui=NONE cterm=NONE
  hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE
  hi TabLineSel guifg=#e2e3d8 guibg=#c0cbac gui=bold cterm=bold
  hi TabLineSeparator guifg=#a0d0cb guibg=#c5c8b9 gui=NONE cterm=NONE

  " Interactive elements with complementary contrast
  hi Search guifg=#e2e3d8 guibg=#c0cbac gui=NONE cterm=NONE
  hi Visual guifg=#e2e3d8 guibg=#a0d0cb gui=NONE cterm=NONE
  hi MatchParen guifg=#e2e3d8 guibg=#c0cbac gui=bold cterm=bold

  " Menu item hover highlight
  hi CmpItemAbbrMatch guifg=#c0cbac guibg=NONE gui=bold cterm=bold
  hi CmpItemAbbrMatchFuzzy guifg=#c0cbac guibg=NONE gui=bold cterm=bold
  hi CmpItemMenu guifg=#1e201a guibg=NONE gui=italic cterm=italic
  hi CmpItemAbbr guifg=#12140e guibg=NONE gui=NONE cterm=NONE
  hi CmpItemAbbrDeprecated guifg=#44483d guibg=NONE gui=strikethrough cterm=strikethrough

  " Specific menu highlight groups
  hi WhichKey guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi WhichKeySeparator guifg=#44483d guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyGroup guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyDesc guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi WhichKeyFloat guibg=#c5c8b9 guifg=NONE gui=NONE cterm=NONE

  " Selection and hover highlights with inverted colors
  hi CursorColumn guifg=NONE guibg=#c5c8b9 gui=NONE cterm=NONE
  hi Cursor guibg=#12140e guifg=#e2e3d8 gui=NONE cterm=NONE
  hi lCursor guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi CursorIM guibg=#e2e3d8 guifg=#12140e gui=NONE cterm=NONE
  hi TermCursor guibg=#12140e guifg=#e2e3d8 gui=NONE cterm=NONE
  hi TermCursorNC guibg=#c5c8b9 guifg=#12140e gui=NONE cterm=NONE
  hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
  hi CursorLineNr guifg=#c0cbac guibg=NONE gui=bold cterm=bold

  hi QuickFixLine guifg=#e2e3d8 guibg=#c0cbac gui=NONE cterm=NONE
  hi IncSearch guifg=#e2e3d8 guibg=#c0cbac gui=NONE cterm=NONE
  hi NormalNC guibg=#e2e3d8 guifg=#1e201a gui=NONE cterm=NONE
  hi Directory guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi WildMenu guifg=#e2e3d8 guibg=#c0cbac gui=bold cterm=bold

  " Add highlight groups for focused items with inverted colors
  hi CursorLineFold guifg=#c0cbac guibg=#e2e3d8 gui=NONE cterm=NONE
  hi FoldColumn guifg=#1e201a guibg=NONE gui=NONE cterm=NONE
  hi Folded guifg=#12140e guibg=#c5c8b9 gui=italic cterm=italic

  " File explorer specific highlights
  hi NeoTreeNormal guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeEndOfBuffer guibg=NONE guifg=#12140e gui=NONE cterm=NONE
  hi NeoTreeRootName guifg=#c0cbac guibg=NONE gui=bold cterm=bold
  hi NeoTreeFileName guifg=#12140e guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeFileIcon guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryName guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeDirectoryIcon guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitModified guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitAdded guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitDeleted guifg=#ffb4ab guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeGitUntracked guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeIndentMarker guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE
  hi NeoTreeSymbolicLinkTarget guifg=#c0cbac guibg=NONE gui=NONE cterm=NONE

  " File explorer cursor highlights with strong contrast
  " hi NeoTreeCursorLine guibg=#c0cbac guifg=#e2e3d8 gui=bold cterm=bold
  " hi! link NeoTreeCursor NeoTreeCursorLine
  " hi! link NeoTreeCursorLineSign NeoTreeCursorLine

  " Use matugen colors for explorer snack in light mode
  hi WinBar guifg=#12140e guibg=#c5c8b9 gui=bold cterm=bold
  hi WinBarNC guifg=#1e201a guibg=#c5c8b9 gui=NONE cterm=NONE
  hi ExplorerSnack guibg=#c0cbac guifg=#e2e3d8 gui=bold cterm=bold
  hi BufferTabpageFill guibg=#e2e3d8 guifg=#44483d gui=NONE cterm=NONE
  hi BufferCurrent guifg=#e2e3d8 guibg=#c0cbac gui=bold cterm=bold
  hi BufferCurrentMod guifg=#e2e3d8 guibg=#c0cbac gui=bold cterm=bold
  hi BufferCurrentSign guifg=#c0cbac guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferVisible guifg=#12140e guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferVisibleMod guifg=#1e201a guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferVisibleSign guifg=#c0cbac guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferInactive guifg=#44483d guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferInactiveMod guifg=#c0cbac guibg=#c5c8b9 gui=NONE cterm=NONE
  hi BufferInactiveSign guifg=#c0cbac guibg=#c5c8b9 gui=NONE cterm=NONE

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
hi FloatBorder guifg=#a0d0cb guibg=NONE gui=NONE cterm=NONE
hi SignColumn guifg=NONE guibg=NONE gui=NONE cterm=NONE
hi DiffAdd guifg=#e2e3d8 guibg=#b3d089 gui=NONE cterm=NONE
hi DiffChange guifg=#e2e3d8 guibg=#a0d0cb gui=NONE cterm=NONE
hi DiffDelete guifg=#e2e3d8 guibg=#ffb4ab gui=NONE cterm=NONE
hi TabLineFill guifg=NONE guibg=NONE gui=NONE cterm=NONE

" Fix selection highlighting with proper color derivatives
hi TelescopeSelection guibg=#a0d0cb guifg=#12140e gui=bold cterm=bold
hi TelescopeSelectionCaret guifg=#e2e3d8 guibg=#a0d0cb gui=bold cterm=bold
hi TelescopeMultiSelection guibg=#a0d0cb guifg=#12140e gui=bold cterm=bold
hi TelescopeMatching guifg=#ffb4ab guibg=NONE gui=bold cterm=bold

" Minimal fix for explorer selection highlighting
hi NeoTreeCursorLine guibg=#a0d0cb guifg=#12140e gui=bold

" Fix for LazyVim menu selection highlighting
hi Visual guibg=#ffb4ab guifg=#12140e gui=bold
hi CursorLine guibg=NONE ctermbg=NONE gui=underline cterm=underline
hi PmenuSel guibg=#ffb4ab guifg=#12140e gui=bold
hi WildMenu guibg=#ffb4ab guifg=#12140e gui=bold

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
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormal guibg=NONE guifg=#e2e3d8 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeNormalNC guibg=NONE guifg=#c5c8b9 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NeoTreeEndOfBuffer guibg=NONE guifg=#e2e3d8 ctermbg=NONE

  " Also fix NvimTree for NvChad
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormal guibg=NONE guifg=#e2e3d8 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeNormalNC guibg=NONE guifg=#c5c8b9 ctermbg=NONE
  autocmd ColorScheme,VimEnter,WinEnter,BufEnter * hi NvimTreeEndOfBuffer guibg=NONE guifg=#e2e3d8 ctermbg=NONE

  " Apply highlight based on current theme
  autocmd ColorScheme,VimEnter * if &background == 'dark' |
    \ hi NeoTreeCursorLine guibg=#a0d0cb guifg=#12140e gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#a0d0cb guifg=#12140e gui=bold cterm=bold |
    \ else |
    \ hi NeoTreeCursorLine guibg=#c0cbac guifg=#e2e3d8 gui=bold cterm=bold |
    \ hi NvimTreeCursorLine guibg=#c0cbac guifg=#e2e3d8 gui=bold cterm=bold |
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
