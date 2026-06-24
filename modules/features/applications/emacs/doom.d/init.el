;;; init.el -*- lexical-binding: t; -*-

;; This file controls what Doom modules are enabled and what order they load
;; in. Remember to run 'doom sync' after modifying it!

(doom! :input
       ;;layout            ; keyboard layout room for non-qwerty users
       ;;chinese
       ;;japanese
       ;;layout            ; map keys for layouts other than QWERTY

       :completion
       company           ; the ultimate code completion backend
       ;;helm              ; the *other* search engine for love and war
       ;;ido               ; the ancient text-matching engine
       ivy               ; a search engine for love and war
       ;;vertico           ; the modern search engine

       :ui
       ;;deft              ; edit search & manage plain-text notes
       doom              ; what makes Doom look like Doom
       doom-dashboard    ; a nifty welcome screen for Emacs
       doom-quit         ; aggressive confirmation before exiting Emacs
       ;;emoji             ; :)
       hl-line           ; highlight the current line
       ;;hydra             ; write custom dispatchers
       ;;indent-guides     ; visual guides for indent levels
       ;;ligatures         ; ligatures and symbols (e.g. Fira Code)
       ;;minimap           ; show a map of the active buffer
       modeline          ; a clean, modern modeline
       ;;nav-flash         ; flash the cursor line when jumping
       ;;neotree           ; a simple file tree sidebar
       ophints           ; highlight the selection/yank area
       ;;parentheses       ; highlight matching brackets
       ;;popup             ; tame popup windows (rules-based)
       ;;tabs              ; tabs at the top of windows (deprecated)
       ;;treemacs          ; a robust file tree sidebar
       ;;unicode           ; befriend all character sets
       ;;vc-gutter         ; show diff status in fringe
       ;;vi-tilde-fringe   ; show empty lines past end-of-buffer
       ;;window-select     ; visually switch windows
       workspaces        ; a workspace manager
       ;;zen               ; distraction-free coding

       :editor
       (evil +everywhere); come to the dark side, we have cookies
       file-templates    ; auto-template new files
       fold              ; fold code like paper planes
       ;;format            ; automated code formatting
       ;;god               ; run Emacs commands without modifier keys
       ;;lispy             ; vim-like keybindings for lisp
       ;;multiple-cursors  ; editing in many places at once
       ;;objed             ; text object-based editing
       ;;parinfer          ; lisp editing for humans
       ;;rotate-text       ; cycle through similar words
       snippets          ; templates for common boilerplate
       ;;word-wrap         ; soft wrapping with smart indentation

       :emacs
       dired             ; making dired pretty [also: (dired +icons)]
       electric          ; smarter indent on enter
       ;;ibuffer         ; interactive buffer management
       undo              ; persistent undo history
       vc                ; version-control integration

       :term
       vterm             ; the robust terminal emulator inside Emacs

       :tools
       direnv            ; integration with direnv
       editorconfig      ; keep settings consistent between editors
       eval              ; run code in code blocks
       ;;flycheck          ; real-time code checking
       ;;flymake           ; Emacs' built-in code checking
       ;;gist              ; manage gists
       lookup            ; look up stuff online / in manuals
       lsp               ; Language Server Protocol support
       magit             ; complete version control interface
       make              ; run makefile commands
       ;;pass              ; password store integration
       pdf               ; view PDF files
       ;;prodigy           ; manage external services
       ;;terraform         ; terraform files
       ;;tmux              ; interface with tmux
       ;;upload            ; upload files to FTP/SFTP

       :lang
       ;;common-lisp       ; lisping for the masses
       ;;data              ; database/query formats
       emacs-lisp        ; configure Emacs in Emacs Lisp
       ;;go                ; go lang
       ;;html              ; xml/html/css
       ;;javascript        ; web scripting
       ;;latex             ; write papers in LaTeX
       markdown          ; writing markdown files
       nix               ; Nix configuration files
       org               ; write papers, keep notes, organize tasks
       ;;python            ; python lang
       ;;rust              ; rust lang
       sh                ; shell script files

       :config
       (default +bindings +smartparens))
