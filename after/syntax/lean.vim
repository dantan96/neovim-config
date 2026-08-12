" after/syntax/lean.vim — colour the one thing in a Lean proof that nothing
" else colours: references to global constants, i.e. the lemma names.
"
" A proof line like
"
"   rw [← mul_assoc, inv_mul_cancel, one_mul]
"
" arrives with exactly one highlight on it. `rw` is a semantic token of type
" `keyword`; the three lemma names are not tokens at all, and lean.nvim's
" syntax file has no rule that reaches them, so they render as plain Normal
" text. Same for `apply inv_eq_of_mul_eq_one` and `exact eq_one_of_idem`.
" Confirmed against leanls on MIL/C02_Basics/S02: over the whole MyGroup
" section the server emits tokens for `theorem`, `by`, `rw`, `have`, `exact`,
" `apply` and for every LOCAL (a, b, c, G, h, idem) — and for nothing else.
"
" That asymmetry is what makes this work. The rule below claims every
" identifier, which would be far too much on its own; but locals carry a
" semantic token, and a semantic extmark outranks syntax, so every local is
" immediately painted back over by @lsp.type.variable.lean. What survives is
" precisely the set of names the server did NOT call a local variable — the
" global references. In a proof body those are the lemmas.
"
" The trade-off, stated plainly: the server does not distinguish a lemma from
" any other global, so `Nat`, `Finset` and the like are caught too. There is no
" signal available that separates them — leanls sends no token, no modifier and
" no type information for either.
"
" It also means an unattached buffer (file outside a Lean project, or the first
" second before the server answers) shows everything in the constant colour
" until the tokens arrive.

" Dotted names are one item so `Nat.succ_le_of_lt` does not fragment. Leading
" character is deliberately not \w: that would swallow leanNumber, which is
" defined earlier and would otherwise lose the tie.
syn match leanConstant "\<[A-Za-z_][A-Za-z0-9_'?!]*\%(\.[A-Za-z_][A-Za-z0-9_'?!]*\)*\>"

" ...but not module paths. `import Mathlib.Algebra.Ring.Defs` and
" `namespace MyGroup` are structure, not references, and were plain before.
" Defined after leanConstant so it wins the tie at the same start position.
syn match leanModulePath
      \ "\%(\<\%(import\|open\|namespace\|end\|export\|section\)\s\+\)\@<=[A-Za-z_][A-Za-z0-9_.'?!]*"

hi def link leanConstant  Function
hi def link leanModulePath Normal
