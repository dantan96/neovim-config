" after/syntax/lean.vim — the columns the language server never claims.
"
" Two of them, and they are the only two:
"
"   1. References to global constants, i.e. the lemma names in a proof.
"   2. Module paths — `import Mathlib.Order.Filter.Basic`, `namespace MyNat`,
"      `open Function Set Order`, `end MyNat`, `universe u v`.
"
" Measured with docs/lean-highlighting/tools/lsp_probe.py against the patched
" server. `import Mathlib.Data.Nat.GCD.Basic` yields exactly ONE token, of
" type `keyword`, covering the word `import`; the path is not a token at any
" position. Same for the name after `namespace`, `end`, `open`, `section` and
" `universe`. So no `@lsp.*` group and no palette work can reach them, and the
" syntax layer at priority 50 is unopposed here rather than merely losing more
" quietly.
"
" Everything with a foreground below links into `@lean.*` groups defined in
" lua/config/lean/namespace_hl.lua. They live there and not in `hi def link`
" because `:colorscheme` clears every group and that module carries the
" ColorScheme autocmd that puts them back.

" ── global constant references ──────────────────────────────────────────
" A proof line like
"
"   rw [← mul_assoc, inv_mul_cancel, one_mul]
"
" arrives with exactly one highlight on it. `rw` is a semantic token; the
" three lemma names are not tokens at all, and lean.nvim's syntax file has no
" rule that reaches them, so they render as plain Normal text.
"
" That asymmetry is what makes this work. The rule below claims every
" identifier, which would be far too much on its own; but locals carry a
" semantic token, and a semantic extmark outranks syntax, so every local is
" immediately painted back over by @lsp.type.variable.lean. What survives is
" precisely the set of names the server did NOT call a local variable.
"
" Dotted names are one item so `Nat.succ_le_of_lt` does not fragment. Leading
" character is deliberately not \w: that would swallow leanNumber, which is
" defined earlier and would otherwise lose the tie.
syn match leanConstant "\<[A-Za-z_][A-Za-z0-9_'?!]*\%(\.[A-Za-z_][A-Za-z0-9_'?!]*\)*\>"

" ── module paths ────────────────────────────────────────────────────────
" The previous version of this file matched the path with a lookbehind and
" then linked it to `Normal` — i.e. it deliberately kept these colourless.
" That is exactly the complaint being answered, and the lookbehind had two
" bugs besides: `open scoped Filter` painted `scoped` as the path, and
" `open Finset Nat BigOperators` reached only `Finset`.
"
" A region fixes both, and is the right shape for splitting a dotted path into
" its components anyway.
"
" ANCHORED TO THE START OF THE LINE, on purpose. A bare `\<end\>` would match
" the `end` in a projection like `Interval.end` — `.` is not a keyword
" character, so the word boundary is there — and would open a bogus path
" region in the middle of a term. Every construct this rule is for is written
" at the start of a line in Lean; `open Foo in` used mid-line is the one case
" not covered, and it is rare enough not to be worth the false positives.
"
" `variable` is NOT in the list even though it is a module keyword: its
" argument is a real binder list (`variable {α : Type*}`) whose names all
" carry semantic tokens, and treating them as path components would be wrong
" the moment the server is not attached. It gets the keyword colour only.
syn region leanPathArgs
      \ start="^\s*\%(import\|open\|export\|namespace\|end\|section\|universe\)\>\s\@="
      \ end="$" oneline keepend
      \ contains=leanModuleKeyword,leanPathQual,leanPathFinal,leanPathPrefix,leanPathDot,
      \leanComment,leanBlockComment,leanString

" Qualifiers that appear in these positions and are keywords, not names.
" `syn keyword` outranks `syn match` unconditionally, so this wins over the
" component rules below without depending on definition order.
syn keyword leanPathQual contained scoped in hiding renaming as all

" A component NOT followed by a dot: the name you actually mean.
" The character class is negative rather than \w so that Unicode identifiers
" (`Mathlib.Order.Ω`, `MIL.C05.S02`) are one component and not fragments. The
" excluded set is punctuation only, and it has to include `-`, `/` and `"` or
" a trailing `-- comment` and a `/- block -/` get eaten as path components:
" both leanComment and this rule match at the `-`, and this one is defined
" later, so it would win the tie.
syn match leanPathFinal "[^[:space:].,:;()⟨⟩«»{}/\"\[\]-]\+" contained

" A component followed by a dot: scaffolding. Defined AFTER leanPathFinal so
" that at a position where both could match — the `A` of `A.B` — this one wins
" the tie, which is the rule for two syn-match items at the same start.
syn match leanPathPrefix "[^[:space:].,:;()⟨⟩«»{}/\"\[\]-]\+\ze\." contained

syn match leanPathDot "\." contained

" ── keywords ────────────────────────────────────────────────────────────
" These DO carry a `keyword` semantic token, so at runtime the real paint
" comes from namespace_hl.lua's LspTokenUpdate handler at priority 129 and
" these rules never show. They exist for the cold-start window before the
" server answers, and for a Lean file opened outside a Lake project where no
" server ever starts — and they link to the same groups, so the two agree.
syn keyword leanModuleKeyword import open export namespace end section variable universe
syn keyword leanBinderKeyword fun let have show suffices match with do from

" ...but `∀ ∃ λ` are not in that sentence. The server emits NO token for them
" — verified on `theorem coext' (h : ∀ s, sᶜ ∈ f ↔ sᶜ ∈ g)`, which produces
" tokens for `s`, `f` and `g` and nothing at the `∀`. lean.nvim lumps them
" into `leanOp` with `+`, `*` and `=`; this rule is defined later and so wins.
syn match leanBinderKeyword "[λ∀∃]"

hi def link leanConstant        Function
hi def link leanModuleKeyword   @lean.path.keyword
hi def link leanBinderKeyword   @lean.binder.keyword
hi def link leanPathQual        @lean.path.keyword
hi def link leanPathPrefix      @lean.path.prefix
hi def link leanPathDot         @lean.path.dot
hi def link leanPathFinal       @lean.path.final
