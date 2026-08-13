; Markdown inside Lean's doc comments.
;
; This is the one highlighting capability the language server structurally
; cannot provide: `textDocument/semanticTokens` has no way to say "this range is
; markdown, run your markdown highlighter over it". See
; research/08-treesitter-ceiling.md, Result 2.
;
; The host grammar is `leantiny` — comments and strings only, every other byte
; opaque — NOT `Julian/tree-sitter-lean`. Measured over a 150-file Mathlib
; sample, the full grammar recovers 82.3% of docstrings because the rest are
; swallowed inside ERROR regions; leantiny recovers 99.6% and parses 8311/8311
; Mathlib files without an error node. See Result 6.
;
; The offsets strip the delimiters so markdown never sees `/-!` or `-/`; both
; openers are three bytes wide, and the closer is two.

((module_doc_comment) @injection.content
  (#set! injection.language "markdown")
  (#offset! @injection.content 0 3 0 -2))

((doc_comment) @injection.content
  (#set! injection.language "markdown")
  (#offset! @injection.content 0 3 0 -2))
