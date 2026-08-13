// tiny_lean_grammar.js — the artifact behind Result 6 of
// ../research/08-treesitter-ceiling.md
//
// A comments-and-strings-only tree-sitter grammar for Lean 4. Recognises doc
// comments, module doc comments, block comments, line comments and string
// literals; every other byte is an opaque `_code` token.
//
// Measured (tree-sitter CLI 0.26.12, 2026-08-12):
//   src/parser.c    11 KB   (full Julian/tree-sitter-lean: 44.3 MB)
//   parser.dylib   8.8 KB   (full grammar: 7.5 MB — 850x smaller)
//   Mathlib   8311/8311 files parse clean, 44564 bytes/ms (full: 13.6%, 2267 B/ms)
//   lean4 core 2485/2485 files parse clean, 43436 bytes/ms (full: 30.6%)
//   docstring recovery on a 150-file Mathlib sample: 99.6% (full grammar: 82.3%)
//
// Purpose: deliver `injections.scm` (markdown inside docstrings) — the one
// capability an LSP structurally cannot provide — without any exposure to
// Lean's extensible syntax. Pair with:
//
//   queries/lean/injections.scm
//     ((doc_comment) @injection.content (#set! injection.language "markdown"))
//     ((module_doc_comment) @injection.content (#set! injection.language "markdown"))
//
// KNOWN LIMITATIONS (this is a proof of concept, not a shippable artifact):
//   * does NOT handle Lean's NESTED block comments /- /- -/ -/ — needs a ~60
//     line external scanner, which is what Julian's src/scanner.c exists for
//   * does NOT handle Lean's backslash-newline string continuation; it fails
//     safe (the `_code` fallback absorbs it) rather than cascading, but the
//     string node is lost. NB: that same construct is what annihilates the
//     full grammar's structure — see Result 1.
//   * `raw strings` (r#"..."#) are not handled
//
// Minimal "comments and strings only" Lean grammar.
// Everything else is opaque. Purpose: deliver injections + comment/string
// highlighting at the lowest possible cost.
module.exports = grammar({
  name: 'leantiny',
  extras: $ => [],
  rules: {
    source_file: $ => repeat(choice(
      $.module_doc_comment,
      $.doc_comment,
      $.block_comment,
      $.line_comment,
      $.string,
      $._code
    )),
    module_doc_comment: $ => token(seq('/-!', repeat(choice(/[^-]/, /-[^\/]/)), '-/')),
    doc_comment:        $ => token(seq('/--', repeat(choice(/[^-]/, /-[^\/]/)), '-/')),
    block_comment:      $ => token(seq('/-',  repeat(choice(/[^-]/, /-[^\/]/)), '-/')),
    line_comment:       $ => token(seq('--', /[^\n]*/)),
    string:             $ => token(seq('"', repeat(choice(/[^"\\]/, /\\./)), '"')),
    _code:              $ => choice(
      token(prec(-1, /[^\/"\-]+/)),
      token(prec(-2, '/')),
      token(prec(-2, '-')),
      token(prec(-2, '"'))
    ),
  }
});
