;;; init.el -*- lexical-binding: t; -*-
;; Doom module selection. After editing, run `doom sync`.

(doom! :input

       :completion
       (corfu +orderless +icons)
       (vertico +icons)

       :ui
       doom
       dashboard
       hl-todo
       (ligatures +extra)
       modeline
       ophints
       (popup +defaults)
       treemacs
       vc-gutter
       vi-tilde-fringe
       workspaces

       :editor
       (evil +everywhere)
       file-templates
       fold
       (format +onsave)
       snippets

       :emacs
       (dired +icons)
       electric
       (ibuffer +icons)
       undo
       vc

       :term
       vterm

       :checkers
       syntax
       (spell +flyspell)

       :tools
       (eval +overlay)
       lookup
       (lsp +eglot)
       (magit)
       tree-sitter

       :lang
       (cc +lsp +tree-sitter)
       data
       emacs-lisp
       (go +lsp +tree-sitter)
       (json +lsp)
       (markdown)
       (python +lsp +pyright +tree-sitter)
       (rust +lsp +tree-sitter)
       (sh +lsp +tree-sitter)
       (swift +lsp)
       (yaml +lsp)

       :config
       (default +bindings +smartparens))
