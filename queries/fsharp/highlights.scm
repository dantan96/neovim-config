;; extends

; Everything standard comes from nvim-treesitter's maintained fsharp
; queries (the grammar is ionide/tree-sitter-fsharp upstream on the main
; branch). This file only ADDS the custom captures that
; after/ftplugin/fsharp.lua colors. The old full replacement query
; targeted a pre-2024 grammar and no longer parsed.

; Cons operator, colored via @operator.cons.fsharp (pink). It appears as
; two different nodes: an (infix_op) in expressions and an anonymous "::"
; inside (cons_pattern) in match arms — the latter is what the base
; query's blanket `pattern: (_) @constant` painted orange. Priority 110
; so it beats the plugin's captures (default 100) and F#'s semantic
; tokens (lowered to 95 by config/fsharp/semantic_priority.lua).
((infix_op) @operator.cons.fsharp
  (#eq? @operator.cons.fsharp "::")
  (#set! priority 110))

(cons_pattern
  "::" @operator.cons.fsharp
  (#set! priority 110))

; Option DU cases, colored via @enum.member.fsharp (pink).
((identifier) @enum.member.fsharp
  (#any-of? @enum.member.fsharp "Some" "None"))
