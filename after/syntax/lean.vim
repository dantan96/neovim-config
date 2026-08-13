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
" SIX, and the same six as `M.palette.rainbow` in namespace_hl.lua. A
" Vimscript file cannot read a Lua table, so this literal is the one place the
" two can drift: a seventh hue there would get a highlight group and a link and
" NO RULE THAT EVER MATCHES IT. tests/test_lean_namespaces.lua compares the two
" with `:syntax list`.
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

" ...but `∀ ∃ λ ↦` are not in that sentence. The server emits NO token for
" them — verified on `theorem coext' (h : ∀ s, sᶜ ∈ f ↔ sᶜ ∈ g)`, which
" produces tokens for `s`, `f` and `g` and nothing at the `∀`, and on
" `fun x ↦ f x`, which produces tokens for `fun`, `x` and `f` and nothing at
" the `↦`. lean.nvim lumps `λ ∀ ∃` into `leanOp` with `+`, `*` and `=`; this
" rule is defined later and so wins.
"
" `↦` ADDED IN THE THIRD RETUNE. It is not in lean.nvim's `leanOp` character
" class at all — that class is
"   [:=≠><λ←→↔∀∃∧∨¬≤≥▸·+*-/^;$|&%!×]
" — so before this it matched no rule anywhere and rendered as bare `Normal`.
" Dan: "`↦` renders uncoloured. It should not be." It joins the binder
" symbols rather than the operators because `fun … ↦ …` is one construct and
" this makes the whole gesture read as one thing.
"
" THE COST, stated because it is visible and nobody chose it: `←` and `→` are
" already sky via `leanOp`, so the arrows are now split across two colours by
" which of them happened to be in a 2015 regex. `⇒` (i.e. the `=>` ligature)
" stays sky for the same reason.
"
" FOURTH RETUNE: `→` is no longer sky — it is in `leanPropOp` below, so the
" arrow split is now deliberate and `←` is the only sky arrow left. See the
" cost note there.
syn match leanBinderSymbol "[λ∀∃↦]"

" ── the operator symbols ────────────────────────────────────────────────
" FOURTH RETUNE, and the whole of it is a syntax-layer change because there is
" nothing else at these columns. Measured (M21, `lsp_probe.py` on
" `OperatorSpecimen.lean`): THE SERVER EMITS NO SEMANTIC TOKEN FOR ANY
" OPERATOR SYMBOL WHATSOEVER — not for `∈`, `∩`, `→`, `≤`, `ᶜ`, `∣`, any of
" them. So unlike `ℕ` (B7), which is a `keyword` token and has to be fought
" for at priority 129, these columns belong to whoever defines the last
" matching syntax item. This file is sourced after lean.nvim's, so these win
" over `leanOp` by the "last defined wins" rule — the same mechanism
" `leanBinderSymbol` above already relies on and which is verified on the
" glass, not assumed.
"
" ── DeepPink: "binds a variable, or builds a proposition" ───────────────
" `#ff1493` already meant "binds a name" — `fun`, `have`, `∀`, `∃`, `↦`. Dan
" widened it, and the honest statement of what it now means is the UNION of
" two things rather than one phrase, because neither half covers his list:
"
"   * it BINDS A VARIABLE          — `fun ∀ ∃ ↦`, and `⋂ ⋃ ⨆ ⨅ ∑ ∏`, which
"                                    are binders too (`⋂ i, s i`);
"   * it BUILDS A PROPOSITION      — `∈ ∉`, the connectives `∧ ∨ ¬ ↔ →`, and
"                                    the relations `≠ ≤ < ≥ >` and `∣`.
"
" `∑` and `∏` produce a value, not a proposition; `∧` binds nothing. Writing
" the union is the point — a colour whose meaning nobody can state drifts, and
" a phrase that covers only half the set is how it starts.
"
" `∣` IS OURS TO PLACE and it went here, not to sky. Dan listed it with the
" set operators but left the call open ("if it reads as a relation rather than
" a set op"). `n ∣ m` is `Dvd.dvd`, a Prop-valued relation between numbers in
" exactly the position `n ≤ m` occupies; it is not set-theoretic notation and
" it never appears in `s ∩ t ⊆ sᶜ`. It is one character in one class if that
" reads wrong.
"
" ASCII `<` and `>` are single-glyph relations here — but they are also HALF
" OF `=>`, `<;>`, `<|>`, `->` and `<-`. Those are handled below.
" Relations (`≠ ≤ ≥ < >`) were pink briefly and Dan reverted it: they are
" furniture, not proposition structure. They stay sky via lean.nvim's own
" `leanOp`, so they are simply absent from this pattern.
syn match leanPropOp "[∈∉∧∨¬↔→⋂⋃⨆⨅∑∏∣]"

" ── sky: the set algebra, which is furniture ────────────────────────────
" Dan: "the set-theoretic operators that are *values* rather than structure".
" Three of these (`⊆ ⊂`) are Prop-valued and not values at all, so the line
" being drawn is not value-vs-proposition — it is that `s ∩ t ⊆ sᶜ ∪ u` reads
" as ONE gesture in one colour, with `∈` in pink as the bridge down to the
" element level. Recorded that way rather than reconciled, because the
" reconciliation would be wrong.
"
" These link to `Operator`, not to a hex: they are operators exactly like the
" ones lean.nvim already claims, and that should be true by construction and
" not by two copies of `#89dceb` agreeing.
syn match leanSetOp "[∩∪⊆⊂ᶜ]"
" Set difference, on its own line: `\` is special inside a `[]` collection
" unless `cpoptions` contains `l`, and getting that wrong fails silently.
" Single-quoted so the pattern really is `\\`, i.e. one literal backslash.
syn match leanSetOp '\\'

" ── yellow: the ascription colon ────────────────────────────────────────
" Instructed: *"make `:` yellow — `#f9e2af`"*. It is sky today, i.e. one of
" the 118 `leanOp` cells on a Filter screen, and it is the single most
" structural mark in Lean source — `(h : P)`, `theorem t : P`, `∀ x : α`. It
" is the character that says "the thing on the left has the type on the
" right", which is the one relation the whole palette is built to expose.
"
" `:=` AND `::` ARE NOT THIS. Dan: "keep them as they are unless they fall out
" of the same rule". They do fall out of it — a bare `:` match starts at the
" `:` of `:=` too — so they are named explicitly in the compound rule below,
" which is defined last and therefore wins at that column. `:=` is a
" definition and `::` is a list cons; neither is an ascription.
syn match leanTypeColon ":"

" ── the compound ASCII operators, kept whole ────────────────────────────
" DEFINED LAST, so it beats `leanPropOp` at the `<` or the `>`, and
" `leanTypeColon` at the `:` of `:=` and `::`.
"
" `=>` is `fun x => …`, and with a ligature font it draws as `⇒` across two
" cells. `<;>` is the tactic combinator, `<|>` is `orElse`, `<|` and `|>` are
" the pipes, `->` and `<-` are the ASCII arrows. None of them is a relation,
" and colouring the `>` of `=>` pink while its `=` stays sky is a two-colour
" ligature — which reads as a rendering fault, not as a distinction. They keep
" lean.nvim's own operator group so that they are furniture, whole.
"
" Vim's alternation is FIRST match, not longest, so `<|>` must precede `<|`.
syn match leanOp ":=\|::\|=>\|<;>\|<|>\|<|\||>\|->\|<-"

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
" Same reasoning as `leanBinderSymbol`: token-free by measurement, so nothing
" can outrank them and nothing they set can leak.
hi def link leanPropOp          @lean.op.prop
" Reverted: the colon was yellow briefly. Back to `Operator` like every
" other piece of punctuation.
hi def link leanTypeColon       Operator
hi def link leanSetOp           Operator
for s:i in range(1, 6)
  execute 'hi def link leanPathC' . s:i . ' @lean.path.c' . s:i
  execute 'hi def link leanPathF' . s:i . ' @lean.path.f' . s:i
  execute 'hi def link leanPathDot' . s:i . ' @lean.path.dot'
endfor
unlet s:i
