# Lean 4 Cheat Sheet

Open with `\?` in any Lean buffer. `q` closes. Local leader is `\`.

Everything below was verified against a real mathlib project, except the row
marked *unverified*.

Loogle takes a type pattern, not a name fragment: `Nat.add_comm` or
`?a * ?b = ?b * ?a`. Queries it cannot parse return no results rather than
erroring — a short prefix mid-typing is normally just noise.

## Infoview & goals

| Keys | Action |
|------|--------|
| `\i` | Toggle the infoview |
| `\<Tab>` | Jump into the infoview window |
| `\p` | Pause / unpause pin updates |
| `\x` | Place a pin at the cursor |
| `\c` | Clear all pins |
| `\v` | Change infoview view options |
| `\w` / `\W` | Enable / disable widgets |
| `\s` | Accept the first "Try this" suggestion |
| `\r` | Restart the Lean server for this file |

### Diff pins

| Keys | Action |
|------|--------|
| `\dx` | Set a diff pin |
| `\dc` | Clear diff pins |
| `\dd` | Toggle auto-diff mode |
| `\dt` | Toggle auto-diff without clearing |

## Inside the infoview window

| Keys | Action |
|------|--------|
| `<CR>` / `K` | Click the interactive element |
| `gK` | Select widget |
| `<Tab>` / `<S-Tab>` | Enter tooltip / back to parent |
| `<Esc>` or `C` | Clear all tooltips |
| `gd` `gD` `gy` | Go to definition / declaration / type |
| `]g` `[g` | Next / previous goal |
| `]h` `[h` | Next / previous hypothesis |
| `]s` `[s` | Next / previous suggestion |
| `]l` `[l` | Next / previous link |
| `]t` `[t` | Next / previous trace |
| `\g` | Jump to the first goal |
| `\/` | Search trace messages |
| `\<Tab>` | Jump back to the Lean file |

## Language server

| Keys | Action |
|------|--------|
| `K` | Interactive hover (lean.nvim overrides the default) |
| `<C-]>` | Go to definition (via `tagfunc`); `<C-t>` to come back |
| `gO` | Document symbols |
| `grn` | Rename (also `\n`) |
| `gra` | Code action (also `\a`) |
| `grr` | References (also `\f`) |
| `gri` | Implementation |
| `grt` | Type definition — every constituent type constant of a compound type |
| `\D` | **Declaration** — Lean also returns the *parser and elaborator* of the symbol, which `gd` does not |
| `\b` | Open this file's book page in the browser (`:LeanBook`) |
| `\h` | Toggle inlay hints for this buffer (on by default) |
| `[d` `]d` | Previous / next diagnostic |

`grn` `gra` `grr` `gri` `grt` are Neovim's own LSP maps and work here like
anywhere else. They used to be dead: mini.operators' replace operator owned the
`gr` prefix and its setup **deletes** those five built-ins. The operator now
lives at `gR` (`gRR` for a line, `gR` in visual mode), which is the only thing
that moved. `\n` `\a` `\f` remain as aliases, so the whole Lean vocabulary is
still reachable from `\`.

Occurrence highlighting is automatic: rest the cursor on an identifier in
normal mode and every *semantically* identical occurrence lights up — which `*`
cannot do, because Lean shadows (`obtain ⟨x, hx⟩ := h` introduces an `x` that is
not the outer `x`). Highlights clear on the next cursor move. Off inside the
infoview.

A 💡 in the sign column means a code action is available on that line — that is
how `#guard_msgs` repair, missing-import suggestions and the Batteries
instance/match/induction skeletons are delivered. Press `gra`.

The thin bar down the right edge of the window is satellite.nvim: elaboration
progress and diagnostics for the **whole file**, not just the visible lines the
sign column can reach. Red marks are errors below the fold.

Lean's only inlay hints are **auto-bound implicits** — the ` {α}` the
elaborator inserted where you wrote none. If one shows up on a name you meant
to be a real constant (`nat` where you wanted `Nat`), that is the bug it exists
to catch.

## Module hierarchy

Which files does this one pull in, and who pulls in this one? MIL chapters open
with a wall of `import Mathlib.…`; these answer "is the lemma I want already in
scope?" without grepping `.lake/packages`.

| Keys | Action |
|------|--------|
| `\mi` | Imports of this module, as a tree (`:LeanModuleImports`) |
| `\mI` | Modules that import this one (`:LeanModuleImportedBy`) |

## Finding lemmas — the pickers

| Keys | Action |
|------|--------|
| `\ll` | Loogle: search mathlib by **type pattern** (needs network) |
| `\lw` | Workspace symbols: fuzzy over every declaration in the project |
| `\la` | Unicode abbreviations: search the `\…` table by name |

`\lw` is the one to reach for with a half-remembered name. Ranking is mediocre;
scroll. See *Finding lemmas* below for when to prefer `exact?` over any of them.

Two footnotes on this group. These are **normal-mode** maps, so `\l` here does
not collide with the insert-mode abbreviation `\l` → `←` further down. And `\la`
carries a known upstream bug: picking an abbreviation whose expansion contains
a `$CURSOR` placeholder inserts the literal text `$CURSOR`, because the picker
calls `nvim_put` on the raw replacement instead of routing it through
`abbreviations.convert`. Most entries are unaffected.

## Folding

Folds come from the language server, so they follow declarations rather than
indentation. Every fold starts open.

| Keys | Action |
|------|--------|
| `za` | Toggle the fold at the cursor |
| `zc` / `zo` | Close / open one level |
| `zM` / `zR` | Close all / open all |
| `zj` / `zk` | Move to the next / previous fold |

## Commands

| Command | Action |
|---------|--------|
| `:LeanGoal` | Goal at the cursor, in a popup |
| `:LeanTermGoal` | Term-mode type information |
| `:LeanLineDiagnostics` | Diagnostics for the current line |
| `:LeanRestartFile` | Restart the server for this file |
| `:LeanRefreshFileDependencies` | Re-read changed imports |
| `:LeanSorryFill` | Fill in `sorry` placeholders |
| `:LeanAbbreviationsReverseLookup` | How do I type the character under the cursor? |
| `:LeanInfoviewToggle` | Toggle the infoview |
| `:LeanInfoviewAddPin` / `…ClearPins` | Manage pins |
| `:LeanGotoInfoview` | Jump into the infoview |
| `:LeanModuleImports` / `:LeanModuleImportedBy` | Import trees (`\mi` / `\mI`) |
| `:Telescope loogle` | Search mathlib by type signature (`\ll`, needs network) |
| `:Telescope lean_abbreviations` | The `\…` table, searchable (`\la`) |

## Finding lemmas

Loogle needs a type pattern. These do not — prefer them.

| What you have | Use | Notes |
|---|---|---|
| A goal | `exact?` | Searches for a lemma that closes it. `\s` accepts the suggestion. |
| A goal you want to rewrite | `rw?` | Lists every applicable rewrite **with the resulting goal** under each. |
| Words, not syntax | `#leansearch "…?"` | Natural language. Query must end `.` or `?`. Sends to leansearch.net. |
| A half-remembered name | `\lw` | Fuzzy name search over the whole project. Ranking is mediocre; scroll. |
| A proof state | `#statesearch` | Same family as `#leansearch`. |
| A type pattern | `\ll` or `#loogle` | See the commands table above. |
| Nothing specific | `:Telescope live_grep` in `.lake/packages/mathlib` | Crude, surprisingly effective. |

`exact?` is the one to reach for by default: it needs no query at all, just a
cursor on the goal. `rw?` is the one people forget — showing the post-rewrite
goal for each candidate makes it a browser, not just a search.

`#leansearch`, `#statesearch` and `#loogle` are commands from the
LeanSearchClient package (already in mathlib's dependency tree). All three
send your query to an external service.

## Unicode abbreviations

Type the sequence in insert mode; it expands on the next non-matching
character (usually space). `\\` on a character tells you how to type it.

| Type | Get | | Type | Get |
|------|-----|-|------|-----|
| `\to` | → | | `\alpha` | α |
| `\l` | ← | | `\beta` | β |
| `\iff` | ↔ | | `\gamma` | γ |
| `\not` | ¬ | | `\lambda` | λ |
| `\and` | ∧ | | `\epsilon` | ε |
| `\or` | ∨ | | `\delta` | δ |
| `\forall` | ∀ | | `\Gamma` | Γ |
| `\ex` | ∃ | | `\Sigma` | Σ |
| `\in` | ∈ | | `\N` | ℕ |
| `\notin` | ∉ | | `\Z` | ℤ |
| `\sub` | ⊆ | | `\Q` | ℚ |
| `\cup` | ∪ | | `\R` | ℝ |
| `\cap` | ∩ | | `\C` | ℂ |
| `\empty` | ∅ | | `\inv` | ⁻¹ |
| `\ne` | ≠ | | `\comp` | ∘ |
| `\le` `\ge` | ≤ ≥ | | `\times` | × |
| `\<>` | ⟨⟩ | | `\sum` | ∑ |
| `\.` | · | | `\prod` | ∏ |
| `\mapsto` | ↦ | | `\1` `\2` | ₁ ₂ |

Greedy matching: `\bN` gives βN, not ℕ, because `\b` → β wins. Use `\N`.

## Toolchain (shell)

| Command | Action |
|---------|--------|
| `lake build` | Build the project |
| `lake exe cache get` | Fetch prebuilt mathlib oleans |
| `lake update` | Update dependencies |
| `elan show` | Active toolchain |
| `elan self update` | Update elan itself |

### Rich semantic tokens

Two Lean toolchains are installed. `lean4-rich` (a directory override on
`~/LeanCourse/MathematicsInLean`) is a local build whose server sends a much
finer token legend — token types for `theorem`, `axiom`, `opaque`, `recursor`
and `tactic`, and 31 modifiers including the `propWorld`/`dataWorld`/
`polyWorld` and `element`/`sort`/`former` axes. Stock releases send 24 types
and 10 modifiers. `lean --version` cannot tell them apart; both report commit
`d024af0996`.

Nothing needs configuring: the editor reads the legend the server actually
sent and decides. `:LeanRichTokens status` shows **both** halves — the
toolchain elan resolved *and* what arrived on the wire — because those can
disagree.

| Command | Action |
|---------|--------|
| `:LeanRichTokens status` | Toolchain, legend, and the mode in effect |
| `:LeanRichTokens off` | Force standard mode (`vim.g.lean_rich_tokens = false`) |
| `:LeanRichTokens on` | Force rich mode; warns if the legend has no rich names |
| `:LeanRichTokens toggle` | Flip whichever is in effect |
| `:LeanRichTokens auto` | Back to detecting from the legend (the default) |

Changing the **mode** restarts the language server. Changing the
**toolchain** is a different thing — `elan override set <toolchain>`, or
`ELAN_TOOLCHAIN=…` in the environment nvim was launched from — and no editor
command does it.

Graphics widgets need `resvg` for SVG (installed) and a Kitty-protocol
terminal — Ghostty qualifies. *Unverified*: headless testing cannot render
images.
