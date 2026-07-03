;; extends

; Everything standard comes from nvim-treesitter's maintained fsharp
; queries (the grammar is ionide/tree-sitter-fsharp upstream on the main
; branch). This file only ADDS the custom captures that
; after/ftplugin/fsharp.lua colors. The old full replacement query
; targeted a pre-2024 grammar and no longer parsed.

; Cons operator, colored via @operator.fsharp (teal).
((infix_op) @operator.fsharp
  (#eq? @operator.fsharp "::"))

; Option DU cases, colored via @enum.member.fsharp (pink).
((identifier) @enum.member.fsharp
  (#any-of? @enum.member.fsharp "Some" "None"))
