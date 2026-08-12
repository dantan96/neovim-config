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
" REACHED BY `nextgroup`, NOT BY MATCHING THE KEYWORD INSIDE THE REGION.
" That was the first design and it silently did nothing: a `syn keyword`
" unconditionally outranks a `syn match` or `syn region` at the same position
" (`:h :syn-priority`), so `leanModuleKeyword` at column 0 stopped a region
" whose start pattern also began at column 0 from ever opening. `synstack()`
" showed `leanConstant` on every path component and the region absent — the
" rule read as perfectly correct and painted nothing.
"
" With `nextgroup` the keyword is matched normally and hands over to a
" `contained` region that starts at the first non-blank after it, so the two
" never compete for a position.
"
" `variable` is deliberately NOT one of the handing-over keywords: its
" argument is a real binder list (`variable {α : Type*}`) whose names all
" carry semantic tokens, and treating them as path components would be wrong
" the moment the server is not attached. It gets the keyword colour only.
" ── the rainbow, and why it is a nextgroup CHAIN and not a region ───────
" Dan: "things like `Mathlib.Data.Real.Basic` should have been rainbow
" coloured, starting from red ('Mathlib'), orange ('data'), etc."
"
" The colour must key on POSITION, not on the text — there is no list of known
" namespace names here and there is not going to be one. A `syn region` with
" `contains=` cannot express that: items inside a region match wherever they
" fit and know nothing about how many came before. A `nextgroup` chain can,
" because each link names the next position explicitly.
"
" Two groups per position: `leanPathC{i}` for a component followed by a dot,
" `leanPathF{i}` for the last one, which is bold. `F` is defined BEFORE `C` at
" each position so that where both could match — the `A` of `A.B` — `C` wins,
" which is the "last defined wins at the same start" rule (`:h :syn-priority`)
" that the old leanPathFinal/leanPathPrefix pair already relied on.
"
" `F` restarts the cycle rather than terminating it, so `open Function Set
" Order` colours all three names and each starts at red. The cycle is six
" long; the deepest path in MIL is five.
"
" VERIFIED, not assumed — this is exactly the shape B9 describes, where a
" plausible construction silently painted nothing. `synID()` per column on
"
"   import Mathlib.Data.Real.Basic
"   import Data.Mathlib.Basic.Real
"
" gives the same group at the same component index on both lines, and
" tests/test_lean_namespaces.lua asserts it.
syn keyword leanModuleKeyword import open export namespace end section universe
      \ skipwhite nextgroup=leanPathQual,leanPathF1,leanPathC1
syn keyword leanModuleKeyword variable

" Qualifiers that appear in these positions and are keywords, not names.
" `syn keyword` outranks `syn match` unconditionally, so this wins over the
" component rules below without depending on definition order. It hands on to
" the same set, so `open scoped Filter` reaches `Filter`.
syn keyword leanPathQual contained scoped in hiding renaming as all
      \ skipwhite nextgroup=leanPathQual,leanPathF1,leanPathC1

" The character class is negative rather than \w so that Unicode identifiers
" (`Mathlib.Order.Ω`, `MIL.C05.S02`) are one component and not fragments. The
" excluded set is punctuation only, and it has to include `-`, `/` and `"` or
" a trailing `-- comment` and a `/- block -/` get eaten as path components.
let s:leanPathComponent = '[^[:space:].,:;()⟨⟩«»{}/"\[\]-]\+'
for s:i in range(1, 6)
  let s:next = s:i % 6 + 1
  execute 'syn match leanPathF' . s:i . ' "' . s:leanPathComponent . '" contained'
        \ . ' skipwhite nextgroup=leanPathQual,leanPathF1,leanPathC1'
  execute 'syn match leanPathC' . s:i . ' "' . s:leanPathComponent . '\ze\." contained'
        \ . ' nextgroup=leanPathDot' . s:i
  execute 'syn match leanPathDot' . s:i . ' "\." contained'
        \ . ' nextgroup=leanPathF' . s:next . ',leanPathC' . s:next
endfor
unlet s:i s:next s:leanPathComponent

" ── keywords ────────────────────────────────────────────────────────────
" These DO carry a `keyword` semantic token, so at runtime the real paint
" comes from namespace_hl.lua's LspTokenUpdate handler at priority 129 and
" these rules never show. They exist for the cold-start window before the
" server answers, and for a Lean file opened outside a Lake project where no
" server ever starts — and they link to the same groups, so the two agree.
" (`leanModuleKeyword` is declared above, where the path region it hands over
" to is defined.)
syn keyword leanBinderKeyword fun let have show suffices match with do from

" ...but `∀ ∃ λ` are not in that sentence. The server emits NO token for them
" — verified on `theorem coext' (h : ∀ s, sᶜ ∈ f ↔ sᶜ ∈ g)`, which produces
" tokens for `s`, `f` and `g` and nothing at the `∀`. lean.nvim lumps them
" into `leanOp` with `+`, `*` and `=`; this rule is defined later and so wins.
syn match leanBinderSymbol "[λ∀∃]"

hi def link leanConstant        Function
" The keyword rules link to the ATTRIBUTE-FREE floor groups, not to the ones
" namespace_hl.lua applies at 129. Neovim composes per attribute, so a bold set
" here at priority 50 survives a semantic mark at 125 taking the foreground —
" measured: `scoped` and a tactic-position `have` both rendered mauve-BOLD,
" mauve correctly from @lsp.type.keyword.lean and bold leaking from this file.
" `∀ ∃ λ` are exempt because the server emits no token for them at all.
hi def link leanModuleKeyword   @lean.path.floor
hi def link leanBinderKeyword   @lean.binder.floor
hi def link leanBinderSymbol    @lean.binder.keyword
hi def link leanPathQual        @lean.path.floor
for s:i in range(1, 6)
  execute 'hi def link leanPathC' . s:i . ' @lean.path.c' . s:i
  execute 'hi def link leanPathF' . s:i . ' @lean.path.f' . s:i
  execute 'hi def link leanPathDot' . s:i . ' @lean.path.dot'
endfor
unlet s:i
