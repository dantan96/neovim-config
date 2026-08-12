" after/syntax/lean.vim — pull the propositional vocabulary out of lean.nvim's
" syntax file so proofs and data look different.
"
" WHY SYNTAX AND NOT SEMANTIC TOKENS: Lean's language server cannot tell us
" what is a Prop. Asked for textDocument/semanticTokens/full on a real mathlib
" file, leanls returns 542 tokens of exactly two types — `keyword` and
" `variable` — out of the 24 its legend advertises. There is no token type or
" modifier carrying a term's sort, so "colour everything whose type is Prop"
" is not implementable at all; the server simply does not say. What IS
" available is the propositional *vocabulary*, which is syntactic:
"
"   * `theorem` / `lemma` / `axiom` and the names they bind, versus `def`
"     (lean.nvim puts all of them in one leanDeclaration group, so `theorem
"     foo` and `def foo` are pixel-identical today);
"   * `Prop` itself, which shares leanSort with `Type` and `Sort`;
"   * the connectives and quantifiers, which share leanOp with `+` and `*`.
"
" Colours live in lua/plugins/themes.lua, next to the other Lean overrides.
" The `hi def link`s below are fallbacks: `def` does not overwrite a group the
" colorscheme already defined, so they only bite under a derived Ghostty
" profile, where themes.lua stands down.

" Re-binding a keyword moves it out of whichever group claimed it earlier, so
" ordering after lean.nvim's syntax/lean.vim is all that is needed. The
" nextgroup mirrors the original declaration rule; without it the bound name
" falls back to leanDeclarationName and stays Function-coloured.
syn keyword leanPropDeclaration theorem lemma axiom
      \ skipwhite nextgroup=leanPropName
syn match leanPropName ' *[^:({\[[:space:]]*' contained
syn match leanPropName ' *«[^»]*»' contained

" `example` binds no name, so no nextgroup: with one, the trailing spaces
" before `(x : ℝ)` would highlight as an empty declaration name.
syn keyword leanPropDeclaration example

" `Prop` out of leanSort; `Type` and `Sort` stay where they were.
syn keyword leanProp Prop

" Connectives and quantifiers out of leanOp. Deliberately unicode-only: the
" ASCII `=`, `<` and `>` are in leanOp as single characters, so claiming them
" would also recolour the `=` of `:=` and the angle brackets of `⟨_, _⟩`-free
" ASCII notation. Everything genuinely logical is unicode in mathlib anyway.
"
" `←` is deliberately absent despite being an arrow: in Lean source it is
" almost always the direction marker of `rw [← foo]`, which is on most tactic
" lines and is not a connective.
syn match leanLogicOp "[∀∃¬∧∨↔→≠≤≥∈∉⊆⊂∅]"

hi def link leanPropDeclaration   Statement
hi def link leanPropName          Type
hi def link leanProp              Type
hi def link leanLogicOp           Operator
