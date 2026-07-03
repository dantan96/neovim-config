;; extends

; Increase priority for delimiter punctuation. Without the ";; extends"
; modeline above, Neovim silently DROPS this file: a non-extends query
; file that comes after the base query in runtimepath is discarded by
; vim.treesitter.query.get_files().
([
  ","
  ";"
  ":"
  "."
] @punctuation.delimiter
  (#set! "priority" 150))
