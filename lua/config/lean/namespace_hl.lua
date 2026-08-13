-- lua/config/lean/namespace_hl.lua — the two things the semantic palette
-- cannot reach: namespace/module PATHS, and the keywords the server lumps
-- into one undifferentiated `keyword` token.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS IS A CAPTURE GAP AND NOT A PALETTE GAP — measured, not assumed
-- ─────────────────────────────────────────────────────────────────────────
-- `docs/lean-highlighting/tools/lsp_probe.py` against the patched server, on
-- MIL/C05.../S02_Induction_and_Recursion.lean (544 tokens) and on
-- HighlightGallery.lean:
--
--   import Mathlib.Data.Nat.GCD.Basic  ->  ONE token: keyword 'import'
--   namespace MyNat                    ->  ONE token: keyword 'namespace'
--   end MyNat                          ->  ONE token: keyword 'end'
--   open Function Set Order            ->  ONE token: keyword 'open'
--   universe u v                       ->  ONE token: keyword 'universe'
--
-- The path itself is not a token at ANY position, so no `@lsp.*` group — no
-- amount of palette work — can ever colour it. Nothing above priority 50
-- claims those columns either, which is why `after/syntax/lean.vim` is the
-- right layer for the path and this file only supplies the groups it links to.
--
-- The keywords are the opposite case: they DO carry a token, of type
-- `keyword`, so the syntax layer at 50 loses to it and only a token-level
-- handler can split them.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY SPLITTING A DOTTED IDENTIFIER IS SAFE — by construction, not by luck
-- ─────────────────────────────────────────────────────────────────────────
-- A resolved global reference arrives as ONE token spanning the whole dotted
-- name (`'Nat.succ_ne_zero'`, `'Nat.succ.inj'`, `'Finset.sum'`), so the
-- `Nat.` prefix is not separately addressable and has to be split here.
--
-- The obvious fear is that dot-notation on a LOCAL would be caught by the
-- same rule and painted as namespace scaffolding — `n.succ` is the commonest
-- idiom in Lean. It cannot happen, and the probe proves it rather than
-- suggesting it. In `example (n : Nat) : n.succ ≠ Nat.zero` the server emits
--
--   4:20  variable   +local  'n'          <- two tokens, the dot untokenized
--   4:22  enumMember         'succ'
--   4:29  enumMember         'Nat.zero'   <- one token, fully qualified
--
-- Dot-notation on a term is ALREADY split server-side. Therefore a token
-- whose text contains a `.` is always a fully-qualified constant, and every
-- component before the last `.` is genuinely a namespace. There is no
-- heuristic here.
--
-- ─────────────────────────────────────────────────────────────────────────
-- PRIORITY 129, AND THE CONTRACT WITH highlights.lua
-- ─────────────────────────────────────────────────────────────────────────
-- Neovim lays three marks per token at 125/126/127; `highlights.lua`
-- synthesises the `@lean.<world>.<level>` grid at 128. This file paints at
-- **129** and highlights.lua has agreed to stay at 128. That split is the
-- whole layering:
--
--   * a KEYWORD mark here replaces the whole token's colour, and is only ever
--     applied to a fixed, named list of keyword texts (below). Every other
--     keyword — `theorem`, `def`, `_`, and on the patched server every
--     tactic, which arrives as type `tactic` and not `keyword` at all — is
--     left entirely to highlights.lua and the theme. `Type*` and `ℕ` ARE in
--     the list as of the 2026-08-13 retune: they are notation atoms the
--     server calls `keyword` (GOTCHAS B7), so the grid cannot reach them and
--     the pink Dan asked for has to come from here.
--   * a PREFIX mark inside a dotted reference sets NO foreground. It carries
--     only `underdotted` + `sp`, so Neovim's per-attribute composition leaves
--     highlights.lua's foreground in place and the final component of the
--     name stays the dominant thing. Nothing this file does can change a
--     colour highlights.lua chose.
--
-- THE PRICE OF THAT CHOICE, and it is worth knowing before changing it: with
-- no foreground, the underline is the ENTIRE signal for a dotted reference,
-- and styled/coloured underlines are terminfo-gated (GOTCHAS D8). Measured
-- with `infocmp -x` on this machine:
--
--   xterm-ghostty      Smulx yes, Setulc yes   -> dotted, brass. Full signal.
--   tmux-256color-uc   Smulx yes, Setulc yes   -> full signal (this is the
--                                                 terminfo D8 added).
--   tmux-256color      Smulx yes, Setulc NO    -> dotted, in the text colour.
--                                                 Distinction survives.
--   xterm-256color     neither                 -> no styled underline.
--
-- The first three are the only TERMs in use here, so the split is visible
-- everywhere it needs to be, and degrades by losing the underline's COLOUR
-- rather than the underline. Note that `nvim__inspect_cell` reports
-- `underdotted` under all four — the grid attribute is set regardless and the
-- drop happens on the way out to the terminal, so a cell reading CANNOT
-- answer this question and `infocmp -x` is the check.
--
-- `@lsp.type.keyword.lean` is never touched. Dispatch is on the token's TEXT,
-- which is also why this file is correct against the stock toolchain, where
-- `rw`/`exact`/`apply` DO arrive as `keyword`: they are simply not in the
-- list.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THIS FILE AND NOT after/ftplugin/lean.lua
-- ─────────────────────────────────────────────────────────────────────────
-- Same reason as document_highlight.lua: the feature is autocmds, and
-- tests/test_invariants.lua asserts that re-sourcing an ftplugin leaves the
-- autocmd population unchanged. Required once from the lean.nvim spec's
-- `init`, it runs exactly once.
--
-- The ColorScheme autocmd is not optional either: `:colorscheme` clears every
-- group, and a `hi def link` in a syntax file does not reliably survive it.

local M = {}

-- ── the palette ────────────────────────────────────────────────────────
-- Hand-picked, every one of them. Nothing here is computed from anything
-- else, and nothing is blended toward a background to make it recede — a
-- namespace prefix is scaffolding, but scaffolding you can see.
--
-- RETUNED 2026-08-13. Brass, flamingo and olive are gone from the foregrounds
-- here; what replaced each one, and why:
--
--   brass    was the module keywords AND every namespace prefix. Dan:
--            "variable, section, import, namespace should be purple". They
--            are mauve now, the same purple every other keyword already is,
--            and separated from `theorem`/`def` by BOLD rather than by hue.
--            Brass is not orphaned — it keeps exactly one job, as the `sp` of
--            the underline on a namespace prefix inside a reference. It is
--            now the only place brass appears, and it is never a foreground.
--
--   flamingo was the final component of a module path. Superseded by the
--            rainbow below, and it could not have stayed anyway: measured on
--            rendered cells, `#f2cdcd` is ALSO catppuccin's `Identifier` and
--            therefore `@lsp.type.variable.lean` — 20 cells of it on the
--            Gallery screen with nobody having chosen them (GOTCHAS B10).
--
--   olive    was the binder keywords. Dan: "I think the 'fun' keyword doesn't
--            look great." `fun`, `have` and `with` measured 300/278/209
--            occurrences across MIL, which by the retune's rule is far too
--            frequent for a saturated off-theme hue. They take plain mauve —
--            i.e. they stop being special and rejoin the keywords. The group
--            is kept rather than deleted because `∀ ∃ λ` carry no token and
--            are reached only from here, and because it stays one editable
--            place if the distinction is ever wanted back.
--
-- ── THIRD RETUNE, 2026-08-13 (late) — TWO INSTRUCTIONS, BOTH LITERAL ────
--
--   BINDER KEYWORDS TAKE `#ff1493` DEEPPINK. Dan named the hex: it is what
--   `@lean.prop.former` had, and that cell moved into the magenta family, so
--   DeepPink was free. This is the SECOND time in two passes that a
--   saturated off-theme hue has been put on `fun` / `have` / `with`
--   (300/278/209 occurrences across MIL) after the previous pass took olive
--   OFF them for being too frequent for exactly that. The difference is that
--   this one was asked for by name; the olive was ours. Recorded rather than
--   argued: if it reads as too much, it is one hex.
--
--   MODULE KEYWORDS ARE NO LONGER BOLD. Dan asked why they ever were, and
--   there is no good answer — bold was invented in the last pass as the only
--   thing separating them from `theorem` / `def` once both went mauve, which
--   is a reason for the bold to exist and not a reason for anyone to want
--   it. They are now indistinguishable from a declaration keyword, which is
--   fine: `import` and `theorem` are never confused.
M.palette = {
  -- Every module and declaration keyword. No longer bold — see above.
  mauve = "#cba6f7",
  -- The binder keywords: `fun`, `have`, `show`, `match`, and (through
  -- after/syntax/lean.vim, because the server emits no token for them)
  -- `∀ ∃ λ ↦`. Not bold: the standing rule is no bold on a bright hue and
  -- this is the brightest hue in the file.
  deeppink = "#ff1493",
  -- Separators only. spthy-colorscheme.lua `slateGrayPlain`, which does this
  -- same job there for brackets, colons and commas.
  slate = "#708090",
  -- The ASCRIPTION COLON, fourth retune, instructed by hex. Only the bare
  -- `:` — `:=` and `::` are named in after/syntax/lean.vim's compound rule
  -- and keep catppuccin's sky. Deliberately the same `#f9e2af` as rainbow
  -- position 3 below: paths and proofs never share a line.
  yellow = "#f9e2af",
  -- The type-level furniture of a statement: `Type*`, `Sort`, and the
  -- blackboard-bold atoms `ℕ ℤ ℚ ℝ ℂ`. All arrive as `keyword` TOKENS
  -- (GOTCHAS B7), which is why they are here and not in the grid. Dan asked
  -- for `Type*` "hot pink" and then for "`\R`, `\N`, etc to also be pink".
  -- Chosen over `#ff1493`, which is the grid's predicate colour — see the
  -- note on the resolution in palette-widening-design.md.
  hotpink = "#ff69b4",
  -- Underline colour for a namespace prefix inside a dotted reference, and
  -- nothing else. Never a foreground here.
  brass = "#e5b567",
  -- ── the module path, coloured by POSITION ────────────────────────────
  -- Dan: "things like `Mathlib.Data.Real.Basic` should have been rainbow
  -- coloured, starting from red ('Mathlib'), orange ('data'), etc."
  --
  -- KEYED ON POSITION, NOT ON TEXT. `import Mathlib.Data` and
  -- `import Data.Mathlib` colour their components identically; there is no
  -- table of known namespace names anywhere and there is not going to be.
  -- Six entries, cycling — the deepest path in MIL is five.
  --
  -- Catppuccin's own red/peach/yellow/green/blue/mauve rather than six new
  -- hexes: a path sits alone at the top of a file, spatially separated from
  -- any proof, so reusing a hue that also means something in a proof body
  -- costs nothing (and `#f9e2af` yellow, which the grid vacated when cited
  -- lemmas moved to lavender, would otherwise have been orphaned).
  rainbow = { "#f38ba8", "#fab387", "#f9e2af", "#a6e3a1", "#89b4fa", "#cba6f7" },
}

-- ── keyword classification ─────────────────────────────────────────────
-- One table, editable in one place. The key is the token's exact text.
--
-- DELIBERATELY ABSENT, and each for a reason:
--   * `theorem def instance structure class inductive abbrev` — declaration
--     keywords keep plain mauve. They are the skeleton of the file and should
--     stay quiet; a `theorem` keyword and a lemma name are never confused.
--   * `by` — reads as the head of the tactic block, and tactics are blue on
--     `wt/palette`. Left alone rather than claimed from here.
--   * `simp` — arrives as `keyword` when it is the ATTRIBUTE in `@[simp]`.
--     Colouring it as a binder would be plainly wrong.
--   * `_` — a hole, not a keyword in any useful sense.
--
-- `∀ ∃ λ` are NOT here because the server emits no token for them at all
-- (verified: `∀ s, sᶜ ∈ f` in HighlightGallery.lean yields tokens for `s`
-- and `f` and nothing for `∀`). They are reached from after/syntax/lean.vim,
-- which is unopposed at those columns.
M.KEYWORDS = {
  -- module / file structure -> brass
  ["import"] = "@lean.path.keyword",
  ["open"] = "@lean.path.keyword",
  ["export"] = "@lean.path.keyword",
  ["namespace"] = "@lean.path.keyword",
  ["end"] = "@lean.path.keyword",
  ["section"] = "@lean.path.keyword",
  ["variable"] = "@lean.path.keyword",
  ["universe"] = "@lean.path.keyword",
  -- the type-level furniture of a statement -> hot pink.
  -- `Type u` yields NO token at all (measured: `variable {α : Type u}` on
  -- line 25 of HighlightGallery.lean produces tokens for `α`, `f`, `g` and
  -- nothing at the `Type` or the `u`), so `Type` here is inert cover for a
  -- form the server might tokenise later. `Type*` and `Sort` both do arrive,
  -- as one keyword token carrying the whole atom including the star.
  ["Type*"] = "@lean.sort.atom",
  ["Sort*"] = "@lean.sort.atom",
  ["Type"] = "@lean.sort.atom",
  ["Sort"] = "@lean.sort.atom",
  ["ℕ"] = "@lean.sort.atom",
  ["ℤ"] = "@lean.sort.atom",
  ["ℚ"] = "@lean.sort.atom",
  ["ℝ"] = "@lean.sort.atom",
  ["ℂ"] = "@lean.sort.atom",
  -- term / binder -> plain mauve
  ["fun"] = "@lean.binder.keyword",
  ["let"] = "@lean.binder.keyword",
  ["have"] = "@lean.binder.keyword",
  ["show"] = "@lean.binder.keyword",
  ["suffices"] = "@lean.binder.keyword",
  ["match"] = "@lean.binder.keyword",
  ["with"] = "@lean.binder.keyword",
  ["do"] = "@lean.binder.keyword",
  ["from"] = "@lean.binder.keyword",
}

-- ── the groups ─────────────────────────────────────────────────────────
-- Every entry is a COMPLETE spec. GOTCHAS B1: a partial child definition
-- kills inheritance entirely, so nothing here relies on `@lean.path`
-- resolving to anything.
--
-- The one deliberate exception is `@lean.ns.prefix`, which sets no `fg` ON
-- PURPOSE — see the header. It is not a partial child of anything; `@lean.ns`
-- is never defined, so there is no inheritance to break.
--
-- Written as a function rather than a literal so lua_ls sees one table
-- constructor and reports `duplicate-index` if a name is ever repeated
-- (GOTCHAS B8: a duplicate key is silently last-wins and every test asserting
-- on the effective colour passes).
---@return table<string, vim.api.keyset.highlight>
function M.groups()
  local p = M.palette
  local out = {
    -- Applied by THIS module at 129, to a token whose text is in M.KEYWORDS.
    --
    -- NO LONGER BOLD, third retune. Dan asked why it ever was; the honest
    -- answer is that the previous pass invented the bold to keep `import`
    -- distinguishable from `theorem` after moving both to mauve, which is
    -- not a reason he ever asked for. `@lean.path.keyword` and
    -- `@lean.path.floor` are now the same spec; both are kept because the
    -- floor exists to carry NO attribute bits by contract (see below) and
    -- collapsing them would re-open that trap the next time one gains one.
    ["@lean.path.keyword"] = { fg = p.mauve },
    -- DEEPPINK, third retune, by instruction. Was plain mauve, i.e. a visual
    -- no-op; now it is the loudest thing on a proof line. Not bold.
    ["@lean.binder.keyword"] = { fg = p.deeppink },
    -- FOURTH RETUNE: the same DeepPink, on the operator symbols that bind a
    -- variable or build a proposition — `∈ ∉ ∧ ∨ ¬ ↔ → ⋂ ⋃ ⨆ ⨅ ∑ ∏ ≠ ≤ < ≥ >
    -- ∣`. See after/syntax/lean.vim for the membership list and for why the
    -- meaning is stated as a union of two clauses and not as one phrase.
    --
    -- ITS OWN GROUP, sharing `p.deeppink` rather than linking to
    -- `@lean.binder.keyword`, for two reasons. The name has to be able to say
    -- what it is — `∧` is not a binder keyword — and the two are reached by
    -- different layers (that one by the 129 token handler, this one by the
    -- syntax file at 50), so a future edit to one must not silently move the
    -- other. They share the hex through `p.deeppink`, so the picker moves both
    -- together, which is the part that should not drift.
    --
    -- `@lean.op.*` and NOT `@lean.prop.*`: highlights.lua generates the whole
    -- `@lean.<world>.<level>` tree, and a hand-written group inside it would
    -- collide with the generated names and with the picker's gloss.
    ["@lean.op.prop"] = { fg = p.deeppink },
    -- The ascription colon, and only the bare one — `:=` and `::` stay sky.
    -- Instructed by hex. `#f9e2af` is also rainbow position 3, which costs
    -- nothing: a module path sits alone at the top of a file and a colon
    -- never appears in one.
    ["@lean.op.colon"] = { fg = p.yellow },
    -- `Type*`, `Sort`, `ℕ`, `ℝ`. Not bold: hot pink bold is the shouting the
    -- retune removed, and `Type*` measured 362 occurrences across MIL —
    -- more than `fun`.
    ["@lean.sort.atom"] = { fg = p.hotpink },

    -- The COLD-START FLOOR, used by after/syntax/lean.vim for the same words.
    -- Identical but for carrying NO attribute bits, and that is the whole
    -- point. Neovim composes per attribute, so a syntax group at 50 that sets
    -- `bold` keeps its bold even when a semantic mark at 125 takes the
    -- foreground. Measured: `open scoped Classical` rendered `scoped` as
    -- mauve-BOLD — mauve from `@lsp.type.keyword.lean`, which correctly owns
    -- it, and bold leaking up from this layer. Same for `have` used as a
    -- TACTIC, which the server types `tactic` rather than `keyword` so this
    -- module deliberately leaves alone. Setting only `fg` means a token that
    -- outranks us takes the whole appearance and we contribute nothing.
    ["@lean.path.floor"] = { fg = p.mauve },
    -- The binder floor follows the 129 group's HUE, or `fun` renders mauve
    -- for the second or so before the server answers and then jumps to pink,
    -- and renders mauve forever in a .lean file outside a Lake project.
    ["@lean.binder.floor"] = { fg = p.deeppink },

    -- Token-free by measurement, so their attributes cannot leak: the server
    -- emits nothing at these columns at all.
    ["@lean.path.dot"] = { fg = p.slate },
    -- Inside a dotted reference, over highlights.lua's 128. No fg: the
    -- foreground underneath is the whole point of leaving it alone. This is
    -- deliberately NOT rainbowed — a reference already carries a semantic
    -- colour and repainting `Nat.` red would fight it.
    ["@lean.ns.prefix"] = { underdotted = true, sp = p.brass },
    ["@lean.ns.dot"] = { fg = p.slate },
  }
  -- The rainbow, two groups per position: `cN` for a component followed by a
  -- dot, `fN` for the last one. Same hue; the FINAL one is bold.
  --
  -- Bold rather than "wherever the cycle lands" because the cycle position of
  -- the last component is a function of how deep the path is: `namespace
  -- Filter` would land on red and `Mathlib.Data.Real.Basic` on green, so
  -- position cannot mark it. Bold marks it identically at any depth.
  for i, hex in ipairs(p.rainbow) do
    out["@lean.path.c" .. i] = { fg = hex }
    out["@lean.path.f" .. i] = { fg = hex, bold = true }
  end
  return out
end

--- Priority of every mark this module sets.
---
--- 129 = `vim.hl.priorities.semantic_tokens + 4`. Neovim's own three marks are
--- at +0/+1/+2 and highlights.lua synthesises at +3. Computed from the live
--- table rather than hardcoded so that a user lowering `semantic_tokens` (as
--- lua/config/fsharp/semantic_priority.lua does for F#) moves this with it
--- instead of stranding it above.
function M.priority()
  return vim.hl.priorities.semantic_tokens + 4
end

-- ── splitting a dotted name ────────────────────────────────────────────

--- Byte ranges of the namespace components and separators of a dotted name.
---
--- Returns ranges RELATIVE to the start of `text`, half-open, as
--- `{ from, to, kind }` with `kind` one of `"prefix"` / `"dot"`. The final
--- component is deliberately absent: it keeps whatever colour it already had.
---
--- Byte offsets are correct without any UTF-16 arithmetic. `.` is 0x2E and no
--- byte of a multi-byte UTF-8 sequence is ever below 0x80, so a plain byte
--- scan cannot land inside `α` or a subscript; and `token.start_col` is
--- already a byte index (semantic_tokens.lua converts with `str_byteindex`).
---
---@param text string the token's source text
---@return { [1]: integer, [2]: integer, [3]: string }[]
function M.split(text)
  local out = {}
  -- A guillemet-quoted identifier may contain a dot that is part of the NAME
  -- (`«foo.bar»`), so it is not a separator. Cheap and total: refuse to split
  -- anything containing a guillemet at all.
  if text:find("«", 1, true) then
    return out
  end
  local seg = 0 -- 0-based byte offset where the current component starts
  local i = 1
  while true do
    local d = text:find(".", i, true) -- 1-based index of the dot
    if not d then
      break
    end
    -- Skip a zero-length component (`Foo..Bar` is not real Lean, but a
    -- half-typed buffer is the server's normal state).
    if d - 1 > seg then
      out[#out + 1] = { seg, d - 1, "prefix" }
    end
    out[#out + 1] = { d - 1, d, "dot" }
    seg = d
    i = d + 1
  end
  return out
end

-- ── the token handler ──────────────────────────────────────────────────

--- What, if anything, this module wants to paint for one token.
---
--- Pure: takes the token and its source text and returns a list of
--- `{ start_col, end_col, group }` in BUFFER byte columns. Separated from the
--- autocmd so it can be tested without a language server — and so a test can
--- be made non-vacuous by feeding it a token it must refuse.
---
---@param token table `ev.data.token` from |LspTokenUpdate|
---@param text string the buffer text the token covers
---@return { [1]: integer, [2]: integer, [3]: string }[]
function M.marks(token, text)
  local out = {}
  local mods = token.modifiers or {}

  if token.type == "keyword" then
    local group = M.KEYWORDS[text]
    if group then
      out[#out + 1] = { token.start_col, token.end_col, group }
    end
    return out
  end

  -- A local binding is never dotted, and this prunes the largest single
  -- population of tokens (244 of 544 in the S02 probe) before touching text.
  if mods["local"] then
    return out
  end

  -- GOTCHAS B4: one underline style per cell. An `axiom` gets a double
  -- underline and an auto-bound implicit a dashed one from highlights.lua,
  -- both spanning the whole token. Splitting the underline mid-name would
  -- break the stronger signal — `Classical.choice` "rests on nothing" matters
  -- more than "`Classical` is a path segment" — so on those tokens we do not
  -- split at all.
  if mods.axiom or mods.autoImplicit then
    return out
  end

  for _, r in ipairs(M.split(text)) do
    out[#out + 1] = {
      token.start_col + r[1],
      token.start_col + r[2],
      r[3] == "dot" and "@lean.ns.dot" or "@lean.ns.prefix",
    }
  end
  return out
end

--- Syntax-group links that after/syntax/lean.vim also states as `hi def link`.
---
--- Restated here because `:colorscheme` runs `:hi clear`, which drops links as
--- well as definitions, and the syntax file is not re-sourced. Emitted with
--- `default = true`, i.e. exactly `hi def link`, so an explicit
--- `:hi link leanPathFinal Whatever` from the user still wins and survives.
M.LINKS = (function()
  local links = {
    -- The floor groups, NOT the 129 ones — see M.groups() for the measurement.
    leanModuleKeyword = "@lean.path.floor",
    leanBinderKeyword = "@lean.binder.floor",
    leanPathQual = "@lean.path.floor",
    -- ...but `∀ ∃ λ` carry no token ever, so nothing can outrank them and they
    -- get the full treatment.
    leanBinderSymbol = "@lean.binder.keyword",
    -- Fourth retune. Same case as `leanBinderSymbol`: no token ever reaches
    -- these columns (M21), so the syntax layer is unopposed and the full
    -- group is safe. `leanSetOp` goes to catppuccin's `Operator` — the group
    -- `leanOp` itself links to — so that "these are operators exactly like
    -- the other operators" is true by construction rather than by two copies
    -- of `#89dceb`.
    leanPropOp = "@lean.op.prop",
    leanTypeColon = "@lean.op.colon",
    leanSetOp = "Operator",
    -- lean.nvim's own `syn keyword leanSort Sort Prop Type`. Repointed here
    -- so that `Type u` and `Prop`, which carry NO token at all (measured: on
    -- line 25 of HighlightGallery.lean `variable {α : Type u}` produces
    -- tokens for `α` and nothing at the `Type` or the `u`), look the same as
    -- `Type*` and `ℕ`, which do. Without it the retune would put `Type*` in
    -- hot pink and leave `Type u` two words away in yellow.
    --
    -- HARD-LINKED, see `HARD` below: lean.nvim already says
    -- `hi def link leanSort Type` and a second `hi def link` to an
    -- already-linked group is a silent no-op.
    leanSort = "@lean.sort.atom",
  }
  -- The rainbow chain. Also token-free by measurement, so `f{i}`'s bold has
  -- nothing to leak under. Every separator shares one group; only the
  -- components cycle.
  for i = 1, #M.palette.rainbow do
    links["leanPathC" .. i] = "@lean.path.c" .. i
    links["leanPathF" .. i] = "@lean.path.f" .. i
    links["leanPathDot" .. i] = "@lean.path.dot"
  end
  return links
end)()

--- Links that must NOT be `default`, because the group already carries a
--- `hi def link` from lean.nvim's own syntax file and a second default link
--- is a silent no-op. Kept as a named set rather than a flag on the entry so
--- that "which of our links overrule the plugin" is one grep.
M.HARD = { leanSort = true }

--- Define every group. Idempotent; re-run from the ColorScheme autocmd.
function M.define()
  for name, spec in pairs(M.groups()) do
    vim.api.nvim_set_hl(0, name, spec)
  end
  for name, target in pairs(M.LINKS) do
    vim.api.nvim_set_hl(0, name, { link = target, default = not M.HARD[name] })
  end
end

--- Should this module run at all?
---
--- Same predicate and same reason as `lua/plugins/themes.lua`, which is
--- `enabled = ghostty_profile.theme() == nil` and is what loads
--- `lua/config/lean/highlights.lua` (see its NOTE ON SCOPE). Under a derived
--- Ghostty bundle — GhosttyNu, GhosttyFish, GhosttyElvish, GhosttyXonsh —
--- neither catppuccin nor the world x level grid loads, and Lean is meant to
--- render in that profile's own colours. Painting mauve, hot pink, slate and
--- a six-colour rainbow over a foreign scheme with no grid underneath them
--- would be half a design.
---
--- Gating this off is a strict non-regression: `after/syntax/lean.vim`'s
--- `hi def link` targets then resolve to nothing, and an unresolved link
--- renders as `Normal` — which is precisely what the rule this replaced did
--- on purpose, under every profile.
---@return boolean
function M.enabled()
  return require("config.ghostty_profile").theme() == nil
end

local armed = false

function M.setup()
  if not M.enabled() then
    return M
  end
  M.define()
  if armed then
    return M
  end
  armed = true

  local aug = vim.api.nvim_create_augroup("LeanNamespaceHighlight", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    desc = "Lean: re-emit the namespace/keyword groups a colorscheme cleared",
    callback = M.define,
  })

  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = aug,
    desc = "Lean: split dotted names and re-colour module/binder keywords",
    callback = function(ev)
      local token = ev.data.token
      -- Multi-line tokens exist (Neovim 0.12 supports them) but no identifier
      -- or keyword is one, and the arithmetic below assumes a single line.
      if token.line ~= token.end_line then
        return
      end
      local ok, lines =
        pcall(vim.api.nvim_buf_get_text, ev.buf, token.line, token.start_col, token.line, token.end_col, {})
      if not ok or not lines[1] then
        return
      end
      local priority = M.priority()
      for _, m in ipairs(M.marks(token, lines[1])) do
        -- A COPY of the token with the columns moved, so `set_mark` reads
        -- every other field exactly as it would have. `highlight_token` puts
        -- the mark in the semantic-token engine's own namespace, which means
        -- the engine deletes it on the next refresh — the reason not to
        -- manage a namespace here.
        local sub = vim.tbl_extend("force", token, { start_col = m[1], end_col = m[2] })
        vim.lsp.semantic_tokens.highlight_token(sub, ev.buf, ev.data.client_id, m[3], {
          priority = priority,
        })
      end
    end,
  })

  return M
end

return M
