-- lua/config/lean/highlights.lua — the Lean semantic palette.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHAT THIS FILE IS FOR
-- ─────────────────────────────────────────────────────────────────────────
-- The patched Lean server (see docs/lean-highlighting/NAMES.md in
-- ~/ClaudeProjects/leanSetup) classifies every identifier along several
-- independent axes at once: a declaration KIND in the token type, and then
-- modifiers for WORLD (propWorld / dataWorld / polyWorld), LEVEL (element /
-- sort / former), binder annotation, locality, and a dozen attribute flags.
--
-- Neovim generates `@lsp.type.<t>`, `@lsp.mod.<m>` and
-- `@lsp.typemod.<t>.<m>` — never modifier × modifier. So the one distinction
-- that matters most, `propWorld` + `element` (a proof) against `dataWorld` +
-- `element` (a datum), is unreachable with stock groups. That is why four
-- groups (`leanProof`, `leanHypothesis`, `leanProp`, `leanInductive`) were
-- deleted with no drop-in: Prop-ness stopped being a token type and became a
-- modifier PAIR. This file restores the capability by synthesising a group
-- per (type, modifier-set) from an `LspTokenUpdate` callback.
--
-- ─────────────────────────────────────────────────────────────────────────
-- THE DESIGN PRINCIPLE, AND WHAT IT BUYS
-- ─────────────────────────────────────────────────────────────────────────
-- REWRITTEN 2026-08-13. The previous version of this header described a
-- deliberately conservative palette: three hues, two computed brightnesses,
-- and the two commonest things on screen pinned so they would NOT move. Dan
-- rejected it outright, and the rejection is the useful part:
--
--   "SO MUCH FUCKING PURPLE"  ·  "Too much blue"
--   "Where is the magenta, or the bright/hot pink ... from my proven spthy
--    syntax highlighting??"
--   "Where are the fucking underlines? And background colours?"
--   "FUCK any blending. It's HORSESHIT."
--
-- Two errors, named so they are not repeated:
--
-- 1. THE ANCHORS WERE WRONG TO KEEP. Blue for proofs and flamingo for data
--    were held fixed "so the commonest things do not move" — a continuity
--    rule (D6) from an earlier complaint about UNREQUESTED recolouring.
--    Applying it to a task whose whole purpose is to move colours is
--    backwards, and it is why the result read as the old palette with trim.
--
-- 2. THE VIVID COLOURS WENT TO THE RAREST CELLS. Magenta went to `class`,
--    pink to predicates — two of the least frequent things in a file — while
--    keywords, proofs and data locals kept the hues they already had. Spend
--    the gamut where the SCREEN is, not only where the ambiguity is.
--
-- What survives from the old principle is narrower than it looks. "Contrast
-- where confusion is possible" still decides which cells must be TOLD APART.
-- It does not get to decide how vivid the palette is; that is an aesthetic
-- goal Dan stated at the outset and it outranks the information argument.
--
-- ─────────────────────────────────────────────────────────────────────────
-- CHANNELS
-- ─────────────────────────────────────────────────────────────────────────
--   hue           world × level × local, ALL HAND-PICKED. No blending: every
--                 value in `DEFAULTS.hues` is a literal somebody chose.
--   `local`       picks a DIFFERENT HUE, not merely an italic. This is the
--                 change that halves the blue and the flamingo: a hypothesis
--                 and a cited lemma are both prop+element and together are
--                 most of what is on screen.
--   italic        still set for `local`, as a secondary cue on top of the
--                 hue split. Free, so it stays.
--   bold          former — the head of a type expression.
--   background    UNUSED AGAIN as of the third retune. It held the `@[simp]`
--                 tint; Dan deleted that outright ("It's gotta go") and
--                 `@[simp]` is now unmarked. The slot is free, but the
--                 underline slot is NOT where simp goes if it ever returns —
--                 see the note by `alarm` below.
--   underline     ONE slot (3-bit enum, B4): imported = straight, axiom =
--                 double, auto = dashed. `data.former` also carries a
--                 straight underline as a per-CELL style (CELL_STYLE), which
--                 any of the three flags overwrites.
--   strikethrough deprecated, set separately, stacks freely (M4).
--
-- STILL OUT OF REACH FROM THIS FILE, and being handled elsewhere: namespace
-- components (`Nat.` in `Nat.Prime` is not a separate token) and import
-- paths (not semantic tokens at all). Neither is a palette problem.
--
-- ─────────────────────────────────────────────────────────────────────────
-- THE INPUT MODEL — what is chosen, and what is ASSEMBLED from it
-- ─────────────────────────────────────────────────────────────────────────
-- Everything above describes a palette of forty-odd groups. Nothing in it is
-- computed from anything else any more; what is left is a set of INPUTS and
-- a set of rules for combining them into complete specifications:
--
--   THE INPUTS                              WHAT THEY ASSEMBLE INTO
--   hues.<world>_<level>[_local]            every @lean.<world>.<level>
--   hues.kind_<constructor|projection|      ...and its `.local` variant
--     class>                                the three kind-override groups
--   hues.<world>                            @lean.prop / .data / .poly
--   alarm    (axiom + auto sp and fg)       every flag-suffixed variant
--   channels.former_bold                    ...forty-odd complete specs
--   channels.local_italic
--   channels.imported_underline
--   channels.axiom_underline
--   channels.auto_underline
--   channels.auto_recolour
--
-- The picker's DEFAULT mode edits `M.opts` and calls `M.apply()`, and this
-- file regenerates every group from it — so a hue reaches every variant of
-- itself, including the lazily-built flag-suffixed ones, in one keystroke.
-- Its GROUPS mode writes a literal spec per group over the top. See
-- `M.defaults()` below.
--
-- RETIRED, and listed here because a saved `lean-palette.json` still
-- carries them: `dust`, `recede` (the blend step), `simp_sp` (the simp
-- underline's colour) and `simp_bg` (the simp background that replaced it,
-- now deleted along with the whole marker). `M.validate` ignores all four
-- rather than complaining — see `RETIRED` below.
--
-- ─────────────────────────────────────────────────────────────────────────
-- TWO LAYERS — the generator, and the last word over it
-- ─────────────────────────────────────────────────────────────────────────
-- The structure above is a good default, not a cage. Anything it produces
-- can be overridden per group, and the override wins:
--
--   generated spec  ──►  M.overrides[group]  ──►  nvim_set_hl
--
-- `M.overrides` is a separate table with a separate lifetime, and that
-- separation is the whole point:
--
--   * changing a hue regenerates the grid WITHOUT touching an override, so
--     a deliberate hand-set colour is not silently wiped by a later slider
--     nudge;
--   * an override can be cleared one group at a time, or all at once, and
--     the generated value underneath is still there to fall back to;
--   * an override can name a group the generator never produces at all —
--     the `@lsp.type.*.lean` pins from themes.lua, the
--     `@lsp.typemod.*` crossings, `leanSorryLike`, `LspInlayHint`,
--     `LeanDocumentHighlight`, `leanConstant`. If a group changes how Lean
--     looks, it is reachable.
--
-- ONE RULE IS ENFORCED SILENTLY, because it is mechanics and not taste:
-- every group written out is a COMPLETE specification carrying its own
-- `fg` (B1 — a partial child kills inheritance and renders COLOURLESS).
-- An override that sets only `bold` therefore has the effective `fg`
-- resolved and restated for it in `resolve()` below. The user is never
-- asked to care, and the edit is never refused.
--
-- ─────────────────────────────────────────────────────────────────────────
-- TWO MECHANICS THAT DICTATE THE IMPLEMENTATION
-- ─────────────────────────────────────────────────────────────────────────
-- 1. A PARTIAL CHILD DEFINITION KILLS INHERITANCE. The fallback guard is
--    `sg_cleared`, so `@a.b = { bold = true }` under `@a = { fg = green }`
--    renders bold and COLOURLESS (measurement M3's caveat). Every group this
--    file defines is therefore a COMPLETE spec — fg is always restated,
--    never inherited. The dotted names are for legibility and for a user's
--    `:highlight` grep; nothing depends on the tree resolving.
--
-- 2. THE SYNTHESISED MARK MUST OUTRANK THE BUILT-IN ONES. Neovim sets three
--    extmarks per token at `vim.hl.priorities.semantic_tokens` + 0/1/2, i.e.
--    125/126/127 (runtime/lua/vim/lsp/semantic_tokens.lua, the `set_mark0`
--    calls). `highlight_token`'s default is + 3 = 128, which is above all
--    three — verified by reading the runtime source, and then verified again
--    by reading rendered cells with `nvim__inspect_cell`. If it were below,
--    `@lsp.type.variable.lean` would keep the foreground and this whole file
--    would read as perfectly correct while doing nothing.

local M = {}

-- ── NO COLOUR ARITHMETIC ───────────────────────────────────────────────
-- There was a `blend()` here, and a "dusty" step that computed the sort and
-- former shades by mixing each hue toward `overlay1` so that every world
-- receded by exactly the same amount. It is gone, and it is not coming
-- back. Dan: "FUCK any blending. It's HORSESHIT."
--
-- It was also, by the time it was deleted, UNREACHABLE. `M.validate`
-- refills any key missing from a loaded file out of `DEFAULTS`, so no cell
-- can actually be cleared through `apply` — the branch that used the blend
-- was dead code defending a position that had already been rejected. Both
-- facts are worth keeping: the taste ruling on its own would have left the
-- question of whether something real was lost.
--
-- Every colour in this file is now a literal that somebody chose.

-- ── the inputs ─────────────────────────────────────────────────────────
-- The complete set of things a human chooses. Everything else in this file
-- is a pure function of this table. Kept as a constructor rather than a
-- shared table so that a caller holding "the defaults" cannot mutate them
-- out from under `M.reset()`.

--- The five underline styles Neovim can render, plus the off switch.
--- HL_UNDERLINE_MASK is three bits, so a cell has exactly ONE of these (B4);
--- the FLAGS order below decides who wins when a token qualifies for two.
M.underline_styles = {
  "none",
  "underline",
  "undercurl",
  "underdouble",
  "underdotted",
  "underdashed",
}

--- The same list as attribute keys, i.e. without the off switch. Declared
--- here rather than beside the flag table because the override layer needs
--- it too, to clear a generated underline that a hand-set one replaces.
local UNDERLINE_KEYS = { "underline", "undercurl", "underdouble", "underdotted", "underdashed" }

-- ── the hand-picked colours ────────────────────────────────────────────
-- Design and reasoning: docs/lean-highlighting/palette-widening-design.md in
-- ~/ClaudeProjects/leanSetup. Three hues at two computed brightnesses became
-- a colour per cell, because "generated" was doing the work that choosing
-- should have done.
--
-- COUNT, because the whole complaint was that too few colours appear:
-- 24 keys holding 15 DISTINCT hexes. The collisions are deliberate — the
-- `_local` variants of `poly` and of `prop_sort` repeat their plain partner,
-- because locality is worth a hue split only where the two are confusable and
-- abundant, which is `prop.element`, `prop.former` and `data.element`.
--
-- ── RETUNE, 2026-08-13, AND THE RULE IT ESTABLISHES ────────────────────
-- The widened palette was shown to Dan and corrected again. The correction is
-- one rule, and it decides every allocation in the table below:
--
--     THE LOUDEST COLOURS GO TO THE LEAST FREQUENT CELLS, AND THE MOST
--     FREQUENT CELLS TAKE THEMATIC (catppuccin) COLOURS, CALM AND NOT BOLD.
--
-- Which is the SAME error as §0.2 of the design doc, arriving inverted: that
-- version put the vivid colours on the rarest cells and was told to spend the
-- gamut where the screen is; this one obeyed and put DeepPink on a hypothesis
-- and magenta on `{s t : Set α}` — the two commonest things in a proof.
-- "Spend the gamut where the screen is" was never "shout where the screen
-- is". Dan: *"making such a bright colour almost always bold as well was not
-- a good idea lmao"*, and *"making `@lean.data.element.local` olive — indeed,
-- making it off-thematic in general, for something so common — was clearly a
-- massive fuckup."*
--
-- The qualifier that keeps this from over-correcting, also his: *"I do love
-- magenta and pink — we're gonna try to make sure those aren't too rare!"*
-- Pink and magenta must be RELIABLY PRESENT on any screenful; what has to be
-- rare is the SHOUTING (bold, and a hue that fights its neighbours). So the
-- pinks stay abundant — hypotheses, type variables, `Type*`, `ℕ` — and every
-- one of them is non-bold.
--
-- FREQUENCIES ARE MEASURED, NOT GUESSED. Cells per file, counted off
-- `tools/lsp_probe.py` (MIL C09 S01 / C04 S01 / C05 S03 / HighlightGallery):
--
--   data.element.local  343 132 288  58   green      the commonest thing there is
--   data.sort.local     305   9   6  13   magenta    `Type*`-heavy chapters
--   prop.former.local     0 155   8  56   rosewater  `{s t : Set α}`
--   prop.element.local   24 125 137  49   pink       a hypothesis
--   prop.element         44  38  57  50   lavender   a cited lemma
--   data.former.glob    130  11  14  12   DarkOrange (55 after `class` takes 75)
--   prop.former.glob     21  43  17  16   DeepPink   `Even`, `Prime`, `Set α`
--
-- Off-theme hexes were confined to cells that measured RARE. THAT RULE IS
-- NOW PARTLY SUSPENDED BY INSTRUCTION — see the THIRD RETUNE below.
--
-- ── THIRD RETUNE, 2026-08-13 (late) — DIRECT INSTRUCTION ───────────────
-- Dan looked at the second retune and gave eight specific edits. Several of
-- them CONTRADICT the rule stated above, deliberately and by name, so the
-- rule is not deleted — it is overruled where he overruled it, and the
-- overrules are listed so nobody "fixes" them back:
--
--   prop_element  #b4befe lavender -> #00bfff DeepSkyBlue. His word was
--                 "eye-catching ELECTRIC BLUE, not bold", and his
--                 instruction was to pick it by looking at a Mathlib screen
--                 rather than off a hex table, because it lands on ~32% of a
--                 Filter screen. Four candidates were rendered in one window
--                 at font 13 and read off the glass: #1e90ff DodgerBlue sits
--                 in `#89b4fa`'s family (the tactic blue, one word away on
--                 every `rw [...]` line), #33ccff drifts toward `#89dceb`
--                 sky, which is catppuccin's Operator and 118 cells of the
--                 same screen. #00bfff is the one that separates from BOTH:
--                 its red channel is 0 against sky's 137, and it is fully
--                 saturated where the tactic blue is not. It is off-theme on
--                 a frequent cell, which the rule above forbids; he asked
--                 for it anyway ("gross" was his verdict on the lavender).
--                 NOT BOLD.
--   data_element_local  #a6e3a1 green -> #f2cdcd flamingo. Instructed. This
--                 is the single commonest cell in the language, and flamingo
--                 is catppuccin's own `Identifier`, i.e. the colour
--                 `@lsp.type.variable.lean` already falls through to — so
--                 the grid and the fall-through now AGREE and B10 is benign
--                 here instead of a trap. Keeps its italic.
--   data_former   #ff8c00 -> #ff5fff, BOLD and UNDERLINED, not italic.
--                 Instructed verbatim, and it is the one place the standing
--                 "no bold on a bright hue" rule is broken ON PURPOSE. The
--                 test that sweeps for it now carries a NAMED exception
--                 rather than a weakened predicate.
--   data_sort     #eba0ac maroon -> #cc44cc. Joins the magenta family.
--   prop_former   #ff1493 -> #ffa8ff, a LIGHTER shade of the same magenta.
--                 (He first said teal, then withdrew it in favour of his
--                 earlier instruction that prop.former be a lighter shade of
--                 the data.former / data.sort hue. The withdrawal is why the
--                 poly family did not have to move off #94e2d5 teal.)
--
-- SO THE TYPE LEVEL IS NOW ONE FAMILY IN FOUR SHADES OF MAGENTA:
--   #ffa8ff  prop.former       a predicate           lightest
--   #ff5fff  data.sort.local   a type variable       italic
--   #ff5fff  data.former       a type constructor    bold + underline
--   #cc44cc  data.sort         a concrete type       deepest
-- `data.former` and `data.sort.local` share a hex by instruction 5 and are
-- told apart by weight alone — `Set α` puts them adjacent, which is the pair
-- to judge it on.
--
-- ORPHANED BY THIS PASS, recorded because an unused hue is a loose end:
-- `#ff8c00` DarkOrange and `#b4befe` lavender leave the palette entirely;
-- `#a6e3a1` green survives only as rainbow position 4; `#eba0ac` maroon
-- survives only on `data_former_local`, which measured ZERO cells in all
-- four probe files. `#ff1493` DeepPink leaves the grid and moves to the
-- BINDER KEYWORDS in namespace_hl.lua, where it is on `fun` / `have` /
-- `∀` / `∃` / `↦` — i.e. it is more visible than it was, not less.
--
-- THE INVARIANT ABOUT `sp`, stated precisely, because the loose version was
-- costing colours it had no right to:
--
--     A GROUP'S `fg` MUST NEVER EQUAL ITS OWN `sp`.
--
-- A coloured underline whose colour is the foreground it sits under carries
-- no signal. The old rule was a blanket ban on yellow and red foregrounds —
-- a coarse proxy that removed two whole hues from a palette whose entire
-- complaint was that it had too few. `#f38ba8` is now BOTH the alarm `sp`
-- and `kind_class`, and that is fine: a class is `data.sort`/`data.former`
-- and the alarm belongs to token type `axiom` and to `autoImplicit`, so the
-- two cannot land on one token. `#f9e2af` yellow came back the same way when
-- `simp` vacated the underline; it is now rainbow position 3 in
-- namespace_hl.lua rather than a grid cell.
--
-- The precise rule is ENFORCED, not merely written down: tests/test_lean.lua
-- sweeps every generated group and fails on `spec.fg == spec.sp`. That is
-- what makes it safe to reuse an `sp` hex deliberately.
--
-- The `prop` / `data` / `poly` entries are the FAMILY ANCHORS. They name
-- `@lean.<world>`, which is a real group `:highlight @lean.` shows. They no
-- longer feed anything else: with the blend gone, a cell that lost its own
-- colour does not degrade to its anchor, it just cannot happen (validate
-- refills it). Keep them defined — `define_grid` paints them, and a group
-- with no `fg` renders colourless (B1).

local DEFAULTS = {
  hues = {
    -- Family anchors. `@lean.prop` / `.data` / `.poly`, so the worlds are
    -- nameable in `:highlight`; every cell below is hand-picked and none of
    -- them is derived from these.
    prop = "#ff1493",
    -- Follows `data_element_local` (third retune), so that no hue in this
    -- table is a value nothing on screen can be. `#a6e3a1` green would
    -- otherwise sit here with zero users.
    data = "#f2cdcd",
    poly = "#94e2d5",

    -- ── world × level × local, all hand-picked ────────────────────────
    -- `local` splits the hue, it does not merely add italic. That split is
    -- the point: a hypothesis and a cited lemma are both prop+element, and
    -- together they are most of what is on screen. One blue for both is
    -- what made the old palette read as monochrome.

    -- Prop world. A proof, a proposition, a predicate.
    prop_element_local = "#eba0ac", -- pink      — A HYPOTHESIS. `h0`, `h1`
    prop_element = "#00bfff", -- DeepSkyBlue — A CITED LEMMA. `mul_assoc`
    prop_sort_local = "#ffc0cb", -- pinkPlain — a local `p : Prop` (rare; see below)
    prop_sort = "#ffc0cb", -- pinkPlain — A PROPOSITION. `2 ≤ m`, `True`
    prop_former_local = "#f5e0dc", -- rosewater — a local predicate `{s t : Set α}`
    prop_former = "#ffa8ff", -- magenta·light — A PREDICATE. `Even`, `Antitone`

    -- Data world.
    data_element_local = "#f2cdcd", -- flamingo  — A DATUM YOU BOUND. `m`, `n`
    data_element = "#fab387", -- peach     — A GLOBAL DATUM. `Nat.factorial`
    data_sort_local = "#ff5fff", -- magenta   — A TYPE VARIABLE. `α`, `G`
    data_sort = "#cc44cc", -- magenta·deep  — A CONCRETE TYPE. `Interval`
    data_former_local = "#eba0ac", -- maroon    — a local type family (0 cells; see below)
    data_former = "#ff5fff", -- magenta   — A TYPE CONSTRUCTOR. `Set`, `List`

    -- Poly world — genuinely undetermined `Sort u`. A deliberately tight
    -- family, because these are rare and should read as one thing.
    poly_element_local = "#94e2d5", -- teal
    poly_element = "#94e2d5",
    poly_sort_local = "#74c7ec", -- sapphire
    poly_sort = "#74c7ec",
    poly_former_local = "#89dceb",
    poly_former = "#89dceb",

    -- Kind overrides, scoped in KIND_HUE below. NOT a general kind axis:
    -- keying hue on kind would collapse `m`/`h0`/`h1` in `two_le`, which
    -- are all `kind = variable` and differ only by world.
    kind_constructor = "#ffc0cb", -- pinkPlain   — `enumMember`: how you BUILD data
    kind_projection = "#908070", -- dark gold   — `property`: structural plumbing
    kind_class = "#f38ba8", -- red         — `class`: Mathlib's scaffolding
  },
  -- THE `@[simp]` MARKER IS GONE, 2026-08-13 (third retune). Dan: "It's
  -- gotta go." It was a warm background tint (`simp_bg = "#3a3a2a"`) and
  -- before that an underline. `@[simp]`-ness is now UNMARKED — there is no
  -- channel for it and no group suffix.
  --
  -- IT MUST NOT COME BACK ON THE UNDERLINE. That slot holds `imported` /
  -- `axiom` / `auto` (one style per cell, B4), and adding a fourth claimant
  -- is exactly what pushed simp onto a background in the first place. If the
  -- distinction is ever wanted again it needs a channel nothing else uses.
  --
  -- `simp_bg` is listed in `RETIRED` below, not merely deleted: Dan's saved
  -- `lean-palette.json` still contains it and a complaint at every start is
  -- how a warning becomes furniture.
  alarm = "#f38ba8", -- red      — axioms and auto-bound implicits
  channels = {
    former_bold = true, -- former = the head of a type expression
    local_italic = true, -- bound here, not imported
    -- NEW 2026-08-13. "Is this lemma mine, or Mathlib's?" — the highest-value
    -- distinction the server sends and the one this file has listed as
    -- unspent since it was written. Dan: "there should be a distinction
    -- between mathlib lemmas and our lemmas — perhaps mathlib lemmas should
    -- be underlined, or underdotted".
    --
    -- STRAIGHT underline, not dotted, and the choice is not cosmetic:
    -- `@lean.ns.prefix` in namespace_hl.lua is underdotted and is applied to
    -- the namespace prefix of a dotted reference — which is very nearly the
    -- same population. `Iff.mp`, `Filter.ext`, `Nat.succ_le_of_lt` would
    -- carry one mark meaning two things.
    --
    -- No `sp`: Neovim draws an `sp`-less underline in the foreground colour,
    -- which is the quietest form available, and it makes the `fg ~= sp`
    -- invariant unfalsifiable here rather than merely satisfied.
    imported_underline = "underline",
    axiom_underline = "underdouble",
    auto_underline = "underdashed",
    auto_recolour = true, -- auto-implicits also take the alarm fg
  },
}

--- @return table a fresh, independent copy of the shipped inputs
function M.defaults()
  return vim.deepcopy(DEFAULTS)
end

-- ── validation ─────────────────────────────────────────────────────────
-- This runs on anything loaded from disk, and the load happens inside
-- catppuccin's `config` function. An error there does not degrade to
-- "default colours" — it aborts the colorscheme and leaves the editor
-- unthemed. So every field is checked and anything unrecognised falls back
-- to the shipped value rather than propagating.

--- `#RRGGBB`, in EITHER case on the way in and always lowercase on the way
--- out. `%x` matches `A-F` as well as `a-f`, so a user who types `#FF00FF`
--- into `:LeanPalette` is accepted rather than told off — but the value is
--- lowercased before it is stored.
---
--- That lowercasing is not tidiness. `nvim_get_hl` round-trips a colour as
--- lowercase, so a palette string held as `#FF1493` compares UNEQUAL to the
--- `#ff1493` that comes back off the rendered group while looking identical
--- in every diff and every log line. Four uppercase literals in `DEFAULTS`
--- cost three test failures exactly this way.
--- @param s any
--- @return string|nil hex lowercased, or nil if it is not a colour at all
local function norm_hex(s)
  if type(s) ~= "string" then
    return nil
  end
  return s:match("^#%x%x%x%x%x%x$") and s:lower() or nil
end

local function is_hex(s)
  return norm_hex(s) ~= nil
end

--- Inputs earlier versions had and this one does not. `dust` and `recede`
--- drove the deleted blend step; `simp_sp` coloured the simp underline and
--- `simp_bg` the simp background that replaced it, and the whole `@[simp]`
--- marker is now deleted. Dan's saved `lean-palette.json` contains all four.
---
--- Retired keys are IGNORED, never complained about. `M.setup` notifies on
--- complaints now, and a key that is merely old would put a warning on the
--- screen at every start — which teaches the user that the warning means
--- nothing, and then the one that matters is invisible too.
---
--- `channels.simp_underline` and `channels.simp_marker` are retired too.
--- They need no entry here: `M.validate` only ever copies the channel keys
--- it names, so an unknown one is dropped in silence already. The
--- TOP-LEVEL keys are the ones that need listing, because that loop reads
--- `raw[k]` directly.
local RETIRED = { "dust", "recede", "simp_sp", "simp_bg" }

local function is_style(s)
  for _, v in ipairs(M.underline_styles) do
    if v == s then
      return true
    end
  end
  return false
end

--- Coerce an arbitrary table into a complete, well-formed input set.
--- Never throws, never returns a partial table.
--- @param raw any
--- @return table inputs, string[] complaints
function M.validate(raw)
  local out = M.defaults()
  local bad = {}
  if type(raw) ~= "table" then
    if raw ~= nil then
      bad[#bad + 1] = "not a table"
    end
    return out, bad
  end
  -- `hues` is ARBITRARY-KEYED, not a fixed triple. The shipped set is three
  -- worlds, but the palette is meant to widen to a hand-picked colour per
  -- cell, so a key this version has never heard of is KEPT rather than
  -- dropped — that is how a colour the generator does not ship gets added.
  -- Keys in the defaults but absent from the file keep the shipped value,
  -- because `out` starts life as a full copy of the defaults.
  if type(raw.hues) == "table" then
    for k, v in pairs(raw.hues) do
      if type(k) ~= "string" or not k:match("^[%a][%w_]*$") then
        bad[#bad + 1] = "hues key " .. vim.inspect(k)
      elseif is_hex(v) then
        out.hues[k] = norm_hex(v)
      else
        bad[#bad + 1] = "hues." .. tostring(k) .. " = " .. vim.inspect(v)
      end
    end
  end
  for _, k in ipairs({ "alarm" }) do
    local v = raw[k]
    if v ~= nil then
      if is_hex(v) then
        out[k] = norm_hex(v)
      else
        bad[#bad + 1] = k .. " = " .. vim.inspect(v)
      end
    end
  end
  -- RETIRED KEYS. `dust` and `recede` drove the deleted blend step;
  -- `simp_sp` and `simp_bg` coloured the deleted `@[simp]` marker. Dan
  -- already has a
  -- `lean-palette.json` containing all four, so they are IGNORED rather
  -- than complained about: a saved file that mentions a key this version no
  -- longer has is not a damaged file, and reporting it would train the user
  -- to ignore the complaint list. Anything else unrecognised is simply not
  -- read either — `out` only ever grows from the keys checked above.
  for _, k in ipairs(RETIRED) do
    if raw[k] ~= nil then
      out[k] = nil
    end
  end
  if type(raw.channels) == "table" then
    for _, k in ipairs({ "former_bold", "local_italic", "auto_recolour" }) do
      local v = raw.channels[k]
      if v ~= nil then
        if type(v) == "boolean" then
          out.channels[k] = v
        else
          bad[#bad + 1] = "channels." .. k .. " = " .. vim.inspect(v)
        end
      end
    end
    for _, k in ipairs({ "axiom_underline", "auto_underline", "imported_underline" }) do
      local v = raw.channels[k]
      if v ~= nil then
        if is_style(v) then
          out.channels[k] = v
        else
          bad[#bad + 1] = "channels." .. k .. " = " .. vim.inspect(v)
        end
      end
    end
    -- `simp_underline` and `simp_marker` used to be migrated one to the
    -- other here. The whole `@[simp]` marker is deleted, so both are simply
    -- not read: `out.channels` only ever grows from the two lists above, and
    -- a key nobody reads produces neither an effect nor a complaint.
    -- tests/test_lean_palette.lua asserts that, and asserts it non-vacuously
    -- by also feeding a key that DOES complain.
  end
  return out, bad
end

--- The inputs currently in force. Replaced wholesale by `M.apply`.
M.opts = M.defaults()

-- ── the override layer ─────────────────────────────────────────────────
-- Hand-set specs, layered over whatever the generator produced — or over
-- nothing at all, for groups it never produces. Kept in its own table with
-- its own lifetime so that regenerating cannot wipe a deliberate choice.

--- group name -> partial spec
M.overrides = {}

--- Attributes an override may carry. An allowlist rather than a passthrough
--- because these values reach `nvim_set_hl`, which throws on a bad key or a
--- bad type — and the load happens inside catppuccin's `config` function,
--- where throwing costs the whole colorscheme.
local COLOUR_KEYS = { fg = true, bg = true, sp = true }
local BOOL_KEYS = {
  bold = true,
  italic = true,
  strikethrough = true,
  reverse = true,
  nocombine = true,
  underline = true,
  undercurl = true,
  underdouble = true,
  underdotted = true,
  underdashed = true,
}

--- Coerce one hand-set spec into something `nvim_set_hl` will accept.
--- Unknown keys and ill-typed values are dropped, never propagated.
--- @return table|nil spec, string[] complaints
function M.validate_override(raw)
  if type(raw) ~= "table" then
    return nil, { "not a table" }
  end
  local out, bad = {}, {}
  for k, v in pairs(raw) do
    if COLOUR_KEYS[k] then
      if is_hex(v) then
        out[k] = norm_hex(v)
      elseif v ~= nil then
        bad[#bad + 1] = k .. " = " .. vim.inspect(v)
      end
    elseif BOOL_KEYS[k] then
      if type(v) == "boolean" then
        out[k] = v
      else
        bad[#bad + 1] = k .. " = " .. vim.inspect(v)
      end
    else
      bad[#bad + 1] = "unknown attribute " .. tostring(k)
    end
  end
  if next(out) == nil then
    return nil, bad
  end
  return out, bad
end

--- The colour a group would show if we wrote nothing — used to satisfy B1
--- when an override sets an attribute but no `fg`. Resolves through links,
--- so a group that merely links to `Function` still yields a real hex.
local function inherited_fg(name)
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if ok and type(h) == "table" and h.fg then
    return string.format("#%06x", h.fg)
  end
  return nil
end

--- Merge the override for `name` over the generated spec.
---
--- WHEN THERE IS AN OVERRIDE the result is always a COMPLETE specification:
--- if it would have no foreground, the inherited one is resolved and
--- restated, because a partial definition renders colourless rather than
--- inheriting (B1).
---
--- WHEN THERE IS NOT it is a pass-through, `generated` and all — including
--- `nil`. That path is reachable and deliberate: `apply_foreign_overrides`
--- calls `resolve(name, nil)` for a group the generator never produced and
--- guards on the result. Annotated `table|nil` for that reason; do not
--- "fix" it by making the function return `{}`, which would CLEAR the group.
--- @param name string
--- @param generated table|nil what the generator said, if anything
--- @return table|nil spec
local function resolve(name, generated)
  local ov = M.overrides[name]
  if not ov then
    return generated
  end
  local out = {}
  for k, v in pairs(generated or {}) do
    out[k] = v
  end
  -- An override naming ANY underline style replaces whichever one the
  -- generator chose: only one fits in the cell (B4), and a leftover would
  -- otherwise win or leave a stray `sp` behind.
  for k in pairs(ov) do
    if BOOL_KEYS[k] and k:match("^under") then
      for _, u in ipairs(UNDERLINE_KEYS) do
        out[u] = nil
      end
      break
    end
  end
  for k, v in pairs(ov) do
    out[k] = v
  end
  if not out.fg then
    out.fg = inherited_fg(name)
  end
  return out
end

--- `resolve` for a group the generator DID produce. Its `generated` argument
--- is non-nil, so its result is too — which is what `nvim_set_hl` needs, and
--- what `resolve` alone cannot promise.
---
--- A separate name rather than a looser annotation on `resolve`: that
--- function's nil path is real and deliberate (`apply_foreign_overrides`
--- passes nil for a group the generator never made), and declaring it away
--- would be a lie lua_ls then propagates into every caller as a fact.
--- @param name string
--- @param generated table
--- @return table spec
local function resolved(name, generated)
  return resolve(name, generated) or generated
end

-- ── the derived palette ────────────────────────────────────────────────
--- Every colour this file can produce, flat, so the whole palette is one
--- table to read. Derived entries are computed here rather than in the style
--- table so that nothing downstream has to know how a shade was arrived at.
--- Mutated IN PLACE by `rebuild_palette` so a held reference stays live.
M.palette = {}

local function rebuild_palette(o)
  local p = M.palette
  for k in pairs(p) do
    p[k] = nil
  end
  p.alarm = o.alarm
  -- A flat copy, and nothing else. There is no derived shade any more: what
  -- is in `hues` is what gets painted.
  for name, hex in pairs(o.hues) do
    p[name] = hex
  end
  return p
end

rebuild_palette(M.opts)

-- ── the grid ───────────────────────────────────────────────────────────
-- World × level, the two axes every classified token carries exactly one of
-- each of. All nine cells are populated: eight are observable in a single
-- 106-line probe file, and the Mathlib census (M12, 766,442 constants) has
-- all nine live. `poly` × `former` is the rare one.

local WORLDS = { propWorld = "prop", dataWorld = "data", polyWorld = "poly" }
local LEVELS = { element = true, sort = true, former = true }

-- Kind overrides. A token type listed here takes its own colour INSTEAD of
-- the cell colour, but only in the cells named — everywhere else the
-- world/level reading wins, because it is the more important fact.
--
-- The scope is not arbitrary. It is exactly the two places where the cell
-- colour leaves a real ambiguity that no other channel resolves:
--   * data.element — italic separates the local, so `m` is distinct; but a
--     def, a constructor and a projection are identical to each other.
--   * data.sort / data.former — class, struct and inductive are identical.
--     This is the acute one: all but six of Mathlib's classes ARE structures
--     (see lean-internals.md §3), so `isClass`-before-`isStructure` bought a
--     distinction that nothing has rendered until now.
-- `struct` and `enum` deliberately keep the plain cell colour: class-vs-not
-- carries information, struct-vs-inductive is much lower stakes.
local KIND_HUE = {
  enumMember = { hue = "kind_constructor", suffix = "constructor", cells = { data_element = true } },
  property = { hue = "kind_projection", suffix = "projection", cells = { data_element = true } },
  class = {
    hue = "kind_class",
    suffix = "class",
    -- Dan, on the retune: "`@lean.data.former.class` could also do without
    -- boldness, and could also be italicised". `class` measured 75 cells in
    -- one MIL chapter, so it is not a rare cell and red-bold on it is the
    -- shouting the retune is removing.
    style = { bold = false, italic = true },
    cells = { data_sort = true, data_former = true },
  },
}

-- Per-CELL style, where the channel default is wrong for one cell of the grid.
--
-- `former` is bold by default — the head of a type expression is prominent —
-- and that is right for `data.former` (`List`, `Prod`), which is rare. It is
-- wrong for the Prop-world formers: `prop.former` is DeepPink, and DeepPink
-- bold is exactly what Dan struck out ("get rid of the boldness of the
-- pink"); `prop.former.local` measured 155 cells in one MIL chapter, which is
-- far too many to shout. Both take italic instead — the same style he asked
-- for on `@lean.prop.former` when he moved the hypothesis look onto it.
--
-- Keyed WITHOUT the `_local` suffix, i.e. on the grid cell: the `_local`
-- variant additionally picks up italic from the `local` channel, which is
-- idempotent with this.
--
-- `data_former` gained an UNDERLINE here in the third retune, by direct
-- instruction: "`data_former` → the same colour as `data_sort_local`
-- (`#ff5fff`), bold, underlined, NOT italic." The underline is a per-cell
-- style and not a channel, so it does not compete for the FLAGS slot — but
-- the flags still clear it, because `set_underline` wipes every underline
-- bit before setting its own. That is the right precedence: an `auto`-bound
-- type constructor should read as auto-bound, not as a former.
--
-- KEYED WITHOUT `_local`, so `data_former_local` picks this up too and then
-- adds italic from the `local` channel, i.e. bold + underline + italic
-- maroon — which contradicts the "NOT italic" half of the instruction. It is
-- left that way deliberately: `data.former.local` measured ZERO cells in all
-- four probe files, and adding a per-locality style lookup to serve a cell
-- nothing renders is machinery bought with nothing.
local CELL_STYLE = {
  prop_former = { bold = false, italic = true },
  data_former = { underline = true },
}

--- Complete spec for one grid cell. Never a delta — see mechanic 1.
--- @param world string prop | data | poly
--- @param level string element | sort | former
--- @param ty string|nil the token type, for the KIND_HUE overrides
--- @return table spec, string|nil name_suffix
local function cell_spec(world, level, ty, is_local)
  -- `local` picks a DIFFERENT HUE, not merely italic. A hypothesis and a
  -- cited lemma are both prop+element and together are most of what is on
  -- screen; giving them one hue and an italic is what made the previous
  -- palette read as monochrome. Italic stays on top as a secondary cue.
  local key = world .. "_" .. level .. (is_local and "_local" or "")
  if not M.palette[key] then
    key = world .. "_" .. level -- a cleared local variant falls back to the cell
  end
  local former_bold = level == "former" and M.opts.channels.former_bold or nil

  -- 1 · a kind override, where one is in scope for this cell. Scoped on the
  -- cell WITHOUT the local variant: a constructor, a projection and a class
  -- are all globals, so `data_element_local` should never match one.
  -- A style delta is applied with `v and true or nil` rather than written
  -- straight through: `bold = false` would be a live attribute in the spec
  -- table that every test and the picker then have to reason about, where
  -- absent is what "not bold" actually means everywhere else in this file.
  local function styled(spec, delta)
    for k, v in pairs(delta or {}) do
      spec[k] = v and true or nil
    end
    return spec
  end

  local ov = ty and KIND_HUE[ty]
  if ov and ov.cells[world .. "_" .. level] and M.palette[ov.hue] then
    return styled({ fg = M.palette[ov.hue], bold = former_bold }, ov.style), ov.suffix
  end

  -- 2 · the hand-picked cell colour. In practice this is the ONLY path:
  -- `M.validate` refills every key missing from a loaded file out of
  -- `DEFAULTS`, so a cell cannot be cleared through `apply` at all.
  local picked = M.palette[key]
  if picked then
    return styled({ fg = picked, bold = former_bold }, CELL_STYLE[world .. "_" .. level]), nil
  end

  -- 3 · the family anchor, as a floor. Reachable only by mutating
  -- `M.palette` directly, and kept for one mechanical reason: this function
  -- must never return a spec without an `fg`. A partial definition renders
  -- COLOURLESS (B1), and a nil spec would throw inside catppuccin's
  -- `config` function and leave the editor with no colorscheme at all.
  --
  -- This is where the blend used to be. It is not a "degrade gracefully"
  -- path any more, because there is nothing to degrade to.
  return { fg = M.palette[world] or M.palette.prop, bold = former_bold }, nil
end

-- ── flags that change the spec ─────────────────────────────────────────
-- Order is FIXED so that the group name is a function of the set, not of
-- Lua's hash iteration order. It is also the underline PRECEDENCE order:
-- each entry clears every other underline bit before setting its own, so
-- the last matching flag owns the single available slot (B4). Everything
-- not listed here is deliberately unstyled; see the header.

--- Put ONE underline style on a spec, clearing any other. `sp` is cleared
--- along with the style: a stray `sp` survives an overridden style and
--- shows up as a coloured underline from a group that lost (B4).
---
--- AN `sp` EQUAL TO THE FOREGROUND IS NOT WRITTEN AT ALL. Neovim renders an
--- underline with no `sp` in the foreground colour, so the two are visually
--- identical — but a stored `sp` is a second, independent channel that
--- SURVIVES a later style change (B4 again), and one that silently says the
--- same thing as the foreground is a channel nobody can read. This is live:
--- `auto_recolour` sets the foreground to `alarm` and the auto underline is
--- also `alarm`, so every auto-implicit group used to carry `fg == sp`.
--- tests/test_lean.lua sweeps for exactly that.
local function set_underline(spec, style, sp)
  for _, k in ipairs(UNDERLINE_KEYS) do
    spec[k] = nil
  end
  spec.sp = nil
  if style and style ~= "none" then
    spec[style] = true
    spec.sp = (sp ~= spec.fg) and sp or nil
  end
end

--- Build the flag table for a given input set. Each entry is
--- { suffix, predicate(type, mods), mutate(spec) }. A channel switched off
--- contributes NO entry, so its suffix vanishes from the group name too —
--- the name stays a faithful description of what the group actually does.
local function build_flags(o)
  local c = o.channels
  local flags = {}
  if c.local_italic then
    flags[#flags + 1] = {
      "local",
      function(_, mods)
        return mods["local"]
      end,
      function(spec)
        -- Bound in this file's binder list or tactic block, as opposed to
        -- coming from the environment. Same convention as this machine's
        -- spthy scheme, where italic consistently means "variable".
        spec.italic = true
      end,
    }
  end
  -- THE UNDERLINE PRECEDENCE, and the reason `imported` is placed HERE.
  --
  -- One underline style per cell (B4), and three flags now want it. The last
  -- matching entry in this list owns the slot, so the order below reads
  -- imported < axiom < auto — i.e. `imported` YIELDS to both.
  --
  -- Rarity wins the slot. `imported` is on most of the cited lemmas in a
  -- Mathlib-importing file (36 of the 50 `theorem` tokens in
  -- HighlightGallery), while `axiom` and `auto` are rare AND urgent: "this rests on nothing" and "the
  -- elaborator bound this name, you did not" must not be silently overwritten
  -- by a mark meaning "imported". `Classical.choice` is exactly that
  -- collision and it is a real constant, not a constructed case.
  if c.imported_underline ~= "none" then
    flags[#flags + 1] = {
      "imported",
      -- SCOPED TO THE CITED-LEMMA CELL, not to `defaultLibrary` at large.
      -- Dan asked about *lemmas*; `defaultLibrary` is on every imported name
      -- there is, and measured on MIL C09 S01 that is 258 tokens of which
      -- only 38 are `prop.element` — the other 220 are `Set`, `Filter`,
      -- `Nat`, `Group` and global data, which nobody asked to mark and which
      -- already carry their own cell colour. Widening this to the whole grid
      -- is deleting two conjuncts; do it deliberately, not by accident.
      -- `Classical.choice` stays in scope: it is propWorld + element.
      function(_, mods)
        return mods.defaultLibrary and mods.propWorld and mods.element
      end,
      function(spec)
        set_underline(spec, c.imported_underline, nil)
      end,
    }
  end
  if c.axiom_underline ~= "none" then
    flags[#flags + 1] = {
      "axiom",
      function(ty, _)
        return ty == "axiom"
      end,
      function(spec)
        -- The one global whose authority differs from every other global, and
        -- nothing at the use site says so: `Classical.choice` looks like any
        -- other constant. Double underline = "rests on nothing".
        set_underline(spec, c.axiom_underline, M.palette.alarm)
      end,
    }
  end
  if c.auto_underline ~= "none" or c.auto_recolour then
    flags[#flags + 1] = {
      "auto",
      function(_, mods)
        return mods.autoImplicit
      end,
      function(spec)
        -- The elaborator bound this name; you did not. Upstream keeps globals
        -- grey precisely so an accidental `nat` stands out, and once globals
        -- are coloured that signal is gone — so it has to be said directly.
        -- Loud on purpose: this is the "you typed the wrong name" case, and
        -- the world classification is least trustworthy here anyway, since
        -- Lean guessed the type.
        if c.auto_recolour then
          spec.fg = M.palette.alarm
        end
        set_underline(spec, c.auto_underline, M.palette.alarm)
      end,
    }
  end
  return flags
end

local FLAGS = build_flags(M.opts)

-- Token types that are outside the grid entirely and must be left alone.
-- `leanSorryLike` matters: it carries a background chip defined in
-- themes.lua, and a priority-128 foreground on top of it would make the
-- chip unreadable. Verified against the live server that all three arrive
-- with an EMPTY modifier set, so they would fall through anyway — the
-- early return makes that independent of the server ever changing its mind.
local SKIP = { keyword = true, tactic = true, leanSorryLike = true }

-- ── the style table ────────────────────────────────────────────────────

local specs = {} -- group name -> complete spec
local memo = {} -- "type\0mod mod mod" -> group name (or false)
local stats = { hits = 0, misses = 0 }

--- Register the GENERATED spec for a group and paint the EFFECTIVE one.
--- `specs` deliberately keeps the generated value, not the resolved one, so
--- that clearing an override falls back to something real and so that the
--- picker can show "generated X, overridden to Y" for the same group.
local function define(name, spec)
  specs[name] = spec
  vim.api.nvim_set_hl(0, name, resolved(name, spec))
end

--- What a group the generator does NOT produce looked like before we first
--- overrode it.
---
--- FOUND BY READING RENDERED CELLS, and invisible from the config: clearing
--- an override on `@lsp.type.leanSorryLike.lean` used to leave the `sorry`
--- chip DESTROYED. Those groups are defined by catppuccin's
--- `highlight_overrides` at colorscheme time, so `nvim_set_hl(0, name, {})`
--- does not "restore" them — it clears them, and the chip that themes.lua
--- exists to protect renders as a bare foreground. Generated groups have
--- `specs[name]` to fall back to; these have nothing unless it is kept.
local baseline = {}

local function remember_baseline(name)
  if specs[name] ~= nil or baseline[name] ~= nil then
    return
  end
  -- No `link = false`: a linked group must come back as the LINK it was,
  -- not as a flattened copy that would stop tracking its target.
  local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name })
  baseline[name] = (ok and type(h) == "table") and vim.deepcopy(h) or {}
end

--- Put a group back the way it was before any override touched it.
local function restore_baseline(name)
  if specs[name] then
    vim.api.nvim_set_hl(0, name, specs[name])
  else
    pcall(vim.api.nvim_set_hl, 0, name, baseline[name] or {})
    baseline[name] = nil
  end
end

--- Paint the overrides that name a group the generator never produces —
--- the themes.lua pins, `leanSorryLike`, `LspInlayHint`, and anything else
--- the user reached for. Separate pass because `define` only walks the
--- generated set.
local function apply_foreign_overrides()
  for name in pairs(M.overrides) do
    if specs[name] == nil then
      remember_baseline(name)
      local spec = resolve(name, nil)
      if spec then
        pcall(vim.api.nvim_set_hl, 0, name, spec)
      end
    end
  end
end

--- Build (and register) the group for one (type, modifier-set) pair.
--- @return string|nil group name, or nil when the token is outside the grid
local function build(ty, mods)
  if SKIP[ty] then
    return nil
  end
  local world, level
  for m in pairs(mods) do
    if WORLDS[m] then
      world = WORLDS[m]
    elseif LEVELS[m] then
      level = m
    end
  end
  -- No world or no level: not a classified token. Fall through to whatever
  -- themes.lua says about `@lsp.type.<ty>.lean`, which is today's
  -- appearance. Silence is the conservative answer, not a default colour.
  if not world or not level then
    return nil
  end

  local spec, kind_suffix = cell_spec(world, level, ty, mods["local"] and true or false)
  -- The kind suffix sits directly after the level and BEFORE any flag, so
  -- the name stays a function of the (type, modifier-set) pair and not of
  -- table order. Without it two different colours would share a group name.
  local name = "@lean." .. world .. "." .. level .. (kind_suffix and ("." .. kind_suffix) or "")
  for _, f in ipairs(FLAGS) do
    local suffix, pred, mutate = f[1], f[2], f[3]
    if pred(ty, mods) then
      name = name .. "." .. suffix
      mutate(spec)
    end
  end
  if not specs[name] then
    define(name, spec)
  end
  return name
end

--- The public entry point for a token. Memoised on (type, modifier-set),
--- which is what makes this affordable: a 5,000-token file contains on the
--- order of thirty distinct pairs (D12), and a 106-line probe file measured
--- sixty-three. The key is built from a SORTED modifier list so it does not
--- depend on the order Lua happens to walk the set in — otherwise every
--- token is a cache miss while still producing the correct colour, which is
--- invisible until it is slow.
--- @param ty string token type
--- @param mods table<string, boolean> modifier set, as `ev.data.token.modifiers`
--- @return string|nil
function M.group(ty, mods)
  local keys = {}
  for m in pairs(mods) do
    keys[#keys + 1] = m
  end
  table.sort(keys)
  local key = ty .. "\0" .. table.concat(keys, " ")
  local hit = memo[key]
  if hit ~= nil then
    stats.hits = stats.hits + 1
    return hit or nil
  end
  stats.misses = stats.misses + 1
  local name = build(ty, mods) or false
  memo[key] = name
  return name or nil
end

--- Define the nine grid cells eagerly. Lazy-only definition would mean the
--- groups do not exist until a Lean buffer has been tokenised, which makes
--- `:highlight @lean.` useless as a way to see the palette and makes the
--- table untestable without a live server.
local function define_grid()
  for _, world in pairs(WORLDS) do
    -- The family anchor, so `@lean.prop` names something. It is a complete
    -- spec like every other group here; nothing inherits from it.
    define("@lean." .. world, { fg = M.palette[world] })
    for level in pairs(LEVELS) do
      -- Parenthesised: cell_spec returns (spec, suffix) and Lua would
      -- otherwise expand both into `define`'s argument list.
      define("@lean." .. world .. "." .. level, (cell_spec(world, level)))
    end
  end
  -- The kind-override groups, eagerly, for the same reason as the grid: so
  -- `:highlight @lean.` shows the whole palette without a live server, and
  -- so the picker's raw mode can reach them before a Lean buffer exists.
  for ty, ov in pairs(KIND_HUE) do
    for key in pairs(ov.cells) do
      local world, level = key:match("^(%a+)_(%a+)$")
      local spec, suffix = cell_spec(world, level, ty)
      define("@lean." .. world .. "." .. level .. "." .. suffix, spec)
    end
  end
end

-- ── re-applying a changed input set ────────────────────────────────────
-- The subtle one, and the reason the `ColorScheme` handler below CANNOT be
-- reused for this. That handler re-emits `specs` unchanged, which is right
-- when only the colorscheme was cleared — but after an input changes,
-- `specs` still holds specs computed from the OLD palette, so re-emitting
-- would faithfully repaint the previous colours.
--
-- Worse, the flag-suffixed groups (`@lean.prop.element.local`) are built
-- lazily in `build()`. Dropping `specs` leaves them undefined, and Neovim's
-- `@`-group fallback strips segments from the right (B1) — so an undefined
-- `@lean.prop.element.local` resolves to `@lean.prop.element`, a PLAUSIBLE
-- BUT WRONG colour on a live buffer rather than a blank one. Regenerating
-- from the memo's key set, and then forcing a semantic-token refresh, is
-- what closes that window.

--- Split a memo key back into the pair that produced it.
local function unkey(key)
  local nul = key:find("\0", 1, true)
  local ty = key:sub(1, nul - 1)
  local mods = {}
  for m in key:sub(nul + 1):gmatch("%S+") do
    mods[m] = true
  end
  return ty, mods
end

--- Ask every attached Lean client to resend its tokens, so live buffers
--- repaint through the regenerated groups instead of waiting for an edit.
local function refresh_live_buffers()
  local st = vim.lsp and vim.lsp.semantic_tokens
  if not (st and st.force_refresh) then
    return
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "lean" then
      pcall(st.force_refresh, buf)
    end
  end
end

--- Adopt a new input set and regenerate every group from it.
--- @param inputs table|nil partial or complete; validated, never trusted
--- @return table M, string[] complaints from validation
function M.apply(inputs)
  local o, bad = M.validate(inputs)
  M.opts = o
  rebuild_palette(o)
  FLAGS = build_flags(o)

  -- Remember what we are replacing, then rebuild from the pairs actually
  -- seen. `build` writes into the fresh `specs`, so anything still absent
  -- afterwards is a name this input set can no longer produce.
  local previous = {}
  for name in pairs(specs) do
    previous[name] = true
  end
  local keys = {}
  for key in pairs(memo) do
    keys[#keys + 1] = key
  end

  specs, memo = {}, {}
  define_grid()
  for _, key in ipairs(keys) do
    M.group(unkey(key))
  end
  -- Retire names this input set cannot produce (a channel was switched off,
  -- so its suffix is gone). Left defined they would be dead entries in
  -- `:highlight @lean.` showing colours nothing can reach.
  for name in pairs(previous) do
    if not specs[name] and not M.overrides[name] then
      vim.api.nvim_set_hl(0, name, {})
    end
  end
  apply_foreign_overrides()

  refresh_live_buffers()
  return M, bad
end

--- Repaint everything from the current inputs AND the current overrides,
--- without recomputing the generator. What every override mutation calls.
function M.repaint()
  for name, spec in pairs(specs) do
    vim.api.nvim_set_hl(0, name, resolved(name, spec))
  end
  apply_foreign_overrides()
  refresh_live_buffers()
  return M
end

-- ── override mutation ──────────────────────────────────────────────────

--- Set (or replace) the hand-set spec for one group and repaint.
--- @param name string any highlight group — generated or not
--- @param spec table partial spec; validated, never trusted
--- @return boolean ok, string[] complaints
function M.set_override(name, spec)
  local clean, bad = M.validate_override(spec)
  if not clean then
    return false, bad
  end
  remember_baseline(name)
  M.overrides[name] = clean
  M.repaint()
  return true, bad
end

--- Drop one override. The generated value underneath comes back; a group
--- with nothing underneath is cleared, which restores the theme's own
--- fallback rather than leaving a stale hand-set colour behind.
function M.clear_override(name)
  if M.overrides[name] == nil then
    return false
  end
  M.overrides[name] = nil
  restore_baseline(name)
  M.repaint()
  return true
end

--- Drop every override, keeping the generator inputs as they are.
function M.clear_all_overrides()
  local names = vim.tbl_keys(M.overrides)
  M.overrides = {}
  for _, name in ipairs(names) do
    restore_baseline(name)
  end
  M.repaint()
  return #names
end

--- Back to the shipped palette, in memory: inputs AND overrides. Does not
--- touch the saved file; `M.forget()` does that.
function M.reset()
  M.clear_all_overrides()
  return M.apply(M.defaults())
end

--- Reset the generator inputs only, deliberately KEEPING hand-set groups.
function M.reset_inputs()
  return M.apply(M.defaults())
end

-- ── persistence ────────────────────────────────────────────────────────
-- NOT under `stdpath("config")`: that directory is a git repo and a chezmoi
-- external, and a colour choice is machine state, not tracked config. A
-- field rather than a constant so tests can point it at a temp file — the
-- shared `stdpath("data")` would otherwise let a test write leak into the
-- user's live editor on next start.

M.state_path = vim.fn.stdpath("data") .. "/lean-palette.json"

--- Both layers, so a restart restores exactly what was on screen.
--- @param state table|nil { inputs, overrides }; defaults to what is in force
--- @return boolean ok, string|nil err
function M.save(state)
  state = state or { inputs = M.opts, overrides = M.overrides }
  local payload = { inputs = M.validate(state.inputs), overrides = {} }
  for name, spec in pairs(state.overrides or {}) do
    local clean = M.validate_override(spec)
    if clean then
      payload.overrides[name] = clean
    end
  end
  local ok, err = pcall(function()
    vim.fn.mkdir(vim.fs.dirname(M.state_path), "p")
    local fh = assert(io.open(M.state_path, "w"))
    -- `vim.empty_dict()` so an override-free state round-trips as `{}` and
    -- not as `[]`, which would decode back as a list and be discarded.
    if next(payload.overrides) == nil then
      payload.overrides = vim.empty_dict()
    end
    fh:write(vim.json.encode(payload))
    fh:close()
  end)
  return ok, ok and nil or tostring(err)
end

--- Read the saved state. Any failure at all — missing, unreadable,
--- truncated, hand-edited to nonsense — yields the shipped defaults, because
--- this is called from inside catppuccin's `config` function and an error
--- there leaves the editor with no colorscheme at all.
--- Split across two lines because LuaCATS reads everything after the type
--- and the name as free-text description: one `@return` line mentioning two
--- types declares ONE return, and every `return a, b` below is then a
--- `redundant-return-value` diagnostic against an annotation that is simply
--- wrong.
--- @return table state { inputs, overrides }
--- @return string[] complaints
function M.load()
  local function empty()
    return { inputs = M.defaults(), overrides = {} }
  end
  local fh = io.open(M.state_path, "r")
  if not fh then
    return empty(), {}
  end
  local body = fh:read("*a")
  fh:close()
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= "table" then
    return empty(), { "unparseable JSON at " .. M.state_path }
  end
  -- Files written before the override layer existed are a bare input table.
  local raw_inputs = decoded.inputs ~= nil and decoded.inputs or decoded
  local inputs, bad = M.validate(raw_inputs)
  local overrides = {}
  if type(decoded.overrides) == "table" then
    for name, spec in pairs(decoded.overrides) do
      if type(name) == "string" then
        local clean, cbad = M.validate_override(spec)
        if clean then
          overrides[name] = clean
        end
        for _, c in ipairs(cbad or {}) do
          bad[#bad + 1] = name .. ": " .. c
        end
      end
    end
  end
  return { inputs = inputs, overrides = overrides }, bad
end

--- Delete the saved choice, so the next start uses the shipped defaults.
--- @return boolean ok
function M.forget()
  if vim.fn.filereadable(M.state_path) == 1 then
    return vim.fn.delete(M.state_path) == 0
  end
  return true
end

-- ── wiring ─────────────────────────────────────────────────────────────

local armed = false

--- Idempotent. Called from lua/plugins/themes.lua after the colorscheme is
--- applied, which is also the reason the ColorScheme autocmd below exists:
--- `:colorscheme catppuccin` clears every group, and a module that caches
--- "already defined" would silently stop painting from then on. That is the
--- same failure LineNrWrap and `@lsp.type.variable.lean` avoid by living in
--- catppuccin's `highlight_overrides`.
---
--- NOTE ON SCOPE: themes.lua is `enabled = ghostty_profile.theme() == nil`,
--- so under a derived Ghostty bundle (GhosttyNu, GhosttyFish, ...) neither
--- catppuccin nor this file loads, and Lean renders in that profile's own
--- colours. Deliberate: this palette is built on catppuccin mocha's ladder
--- and would clash with anything else.
---
--- @param o table|nil { load_saved = boolean, inputs = table }
--- `load_saved` is opt-in rather than automatic so that a bare `M.setup()`
--- — which is what every test does — is deterministic and cannot be
--- influenced by whatever the user last picked.
function M.setup(o)
  o = o or {}
  if o.load_saved then
    local state, complaints = M.load()
    M.overrides = state.overrides
    M.apply(state.inputs)
    -- SAY SO WHEN PART OF THE FILE WAS DISCARDED. `M.load` is total by
    -- design — it must not throw inside catppuccin's `config` function — so
    -- a hand-edited or half-corrupt `lean-palette.json` used to be repaired
    -- in silence and the user simply got some of the colours he saved. That
    -- is the wrong trade for a file whose entire purpose is to hold
    -- deliberate choices. Scheduled, not immediate: this runs during
    -- colorscheme setup, before the UI can show a message.
    --
    -- Retired keys are NOT complaints (see `RETIRED`), so an old saved file
    -- stays quiet — otherwise this would fire at every start and teach the
    -- user that the warning means nothing.
    if #complaints > 0 then
      vim.schedule(function()
        vim.notify(
          ("lean palette: %d entr%s in %s could not be read and were left at the shipped value:\n  %s")
            :format(
              #complaints,
              #complaints == 1 and "y" or "ies",
              vim.fn.fnamemodify(M.state_path, ":~"),
              table.concat(complaints, "\n  ")
            ),
          vim.log.levels.WARN
        )
      end)
    end
  elseif o.inputs or o.overrides then
    M.overrides = o.overrides or M.overrides
    M.apply(o.inputs or M.opts)
  end
  define_grid()
  apply_foreign_overrides()
  if armed then
    return M
  end
  armed = true

  local aug = vim.api.nvim_create_augroup("LeanSemanticPalette", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    callback = function()
      -- Re-emit everything. The inputs have not changed here, so the names
      -- and the specs are both still correct; only the DEFINITIONS were
      -- cleared by `:colorscheme`. (An input change goes through `M.apply`,
      -- which cannot use this path — see the note above it.)
      --
      -- The overrides have to be re-emitted too, and AFTER the theme has
      -- rebuilt its own groups: catppuccin redefines every `@lsp.type.*`
      -- pin from `highlight_overrides` on each colorscheme load, so a hand-
      -- set colour on one of those would otherwise survive exactly until
      -- the next `:colorscheme` and then vanish.
      define_grid()
      for name, spec in pairs(specs) do
        vim.api.nvim_set_hl(0, name, resolved(name, spec))
      end
      -- The theme has just rebuilt its pins, so the remembered "before"
      -- values are stale. Re-capture them HERE — after catppuccin, before
      -- the overrides go back on top — or a later clear would restore a
      -- definition from the previous colorscheme.
      baseline = {}
      apply_foreign_overrides()
    end,
  })

  vim.api.nvim_create_autocmd("LspTokenUpdate", {
    group = aug,
    callback = function(ev)
      local token = ev.data.token
      local group = M.group(token.type, token.modifiers or {})
      if group then
        -- Default priority is semantic_tokens + 3 = 128, above the built-in
        -- type/mod/typemod marks at 125/126/127. Passed explicitly so that
        -- a future change to the default cannot silently sink this below
        -- them.
        vim.lsp.semantic_tokens.highlight_token(token, ev.buf, ev.data.client_id, group, {
          priority = vim.hl.priorities.semantic_tokens + 3,
        })
      end
    end,
  })

  return M
end

-- ── what each group MEANS ──────────────────────────────────────────────
-- The picker shows these instead of the bare name: `@lean.prop.element.local`
-- is not a thing anyone can hold in their head, and "a hypothesis" is.

local GRID_GLOSS = {
  ["prop.element"] = "a proof — a term whose type is a proposition",
  ["prop.sort"] = "a proposition — the statement itself, not a proof of it",
  ["prop.former"] = "a predicate — yields a proposition (Even, Set α, ⊆)",
  ["data.element"] = "a datum — a term of some Type (a number, a group element)",
  ["data.sort"] = "a type — ℕ, or a type variable such as {G : Type*}",
  ["data.former"] = "a type former — yields a type (List, Set, Prod)",
  ["poly.element"] = "a term in an undetermined sort (Sort u, u a parameter)",
  ["poly.sort"] = "a sort-polymorphic type",
  ["poly.former"] = "a sort-polymorphic type former — the rare cell",
}
local ANCHOR_GLOSS = {
  prop = "the Prop world — everything that is a proof or a statement",
  data = "the data world — everything that is a value or a type",
  poly = "the sort-polymorphic world — genuinely undetermined",
}
local SUFFIX_GLOSS = {
  ["local"] = "bound here (binder list or tactic block), not imported",
  imported = "from an import — Mathlib's, not one you proved in this file",
  axiom = "an axiom — it rests on nothing",
  auto = "auto-bound implicit — the elaborator bound it, you did not",
}

--- Groups the generator never produces but that still decide how Lean
--- looks. Raw mode reaches all of them; several are the themes.lua pins
--- that exist purely to stop catppuccin owning a standard token name (B2),
--- so overriding one is exactly how a user re-decides that.
local FOREIGN = {
  { "@lsp.type.leanSorryLike.lean", "sorry / admit — the incomplete-proof chip" },
  { "@lsp.type.keyword.lean", "keywords: theorem, fun, let, ℕ" },
  { "@lsp.type.tactic.lean", "tactic head atoms: rw, simp, exact" },
  { "@lsp.type.function.lean", "a global def" },
  { "@lsp.type.theorem.lean", "a cited theorem or lemma" },
  { "@lsp.type.axiom.lean", "a cited axiom" },
  { "@lsp.type.opaque.lean", "an opaque constant — body unavailable" },
  { "@lsp.type.enum.lean", "an inductive type: Nat, List, True" },
  { "@lsp.type.enumMember.lean", "a constructor" },
  { "@lsp.type.struct.lean", "a structure" },
  { "@lsp.type.class.lean", "a class" },
  { "@lsp.type.property.lean", "a structure projection" },
  { "@lsp.type.recursor.lean", "a recursor" },
  { "@lsp.type.type.lean", "a concrete global type" },
  { "@lsp.type.typeParameter.lean", "a local type variable" },
  { "@lsp.type.variable.lean", "any local, before the grid repaints it" },
  {
    "@lsp.typemod.function.defaultLibrary.lean",
    "an imported def — the typemod that outranks the type pin (B3)",
  },
  { "@lsp.mod.deprecated.lean", "deprecated — struck through" },
  { "leanConstant", "constant reference from after/syntax/lean.vim" },
  { "LspInlayHint", "inlay hints — the implicits you did not type" },
  { "LeanDocumentHighlight", "other occurrences of the identifier under the cursor" },
  { "LeanInfoviewNormal", "the infoview background" },
}

--- A gloss for any generated `@lean.*` name, assembled from its parts.
local function gloss_for(name)
  local rest = name:match("^@lean%.(.+)$")
  if not rest then
    return nil
  end
  if ANCHOR_GLOSS[rest] then
    return ANCHOR_GLOSS[rest]
  end
  local world, level, suffixes = rest:match("^(%a+)%.(%a+)(.*)$")
  if not world then
    return nil
  end
  local base = GRID_GLOSS[world .. "." .. level]
  if not base then
    return nil
  end
  local extra = {}
  for s in suffixes:gmatch("%.([%a]+)") do
    extra[#extra + 1] = SUFFIX_GLOSS[s] or s
  end
  if #extra == 0 then
    return base
  end
  return base .. "; " .. table.concat(extra, "; ")
end

M.gloss_for = gloss_for

--- Build the flag-suffixed variants eagerly, so the picker can list and
--- override them before any Lean buffer has ever been tokenised. Kept OUT
--- of `setup()` on purpose: it would otherwise inflate the spec table that
--- tests/test_lean.lua sweeps, for no runtime benefit.
function M.warm()
  local reps = {
    { "variable", { propWorld = true, element = true, ["local"] = true } },
    { "variable", { dataWorld = true, element = true, ["local"] = true } },
    { "variable", { dataWorld = true, sort = true, ["local"] = true } },
    { "variable", { propWorld = true, former = true, ["local"] = true } },
    { "variable", { polyWorld = true, element = true, ["local"] = true } },
    { "variable", { polyWorld = true, sort = true, ["local"] = true } },
    { "theorem", { propWorld = true, element = true } },
    { "theorem", { propWorld = true, element = true, defaultLibrary = true } },
    -- The collision that decides the underline precedence: `Classical.choice`
    -- is imported AND an axiom, and the axiom mark has to survive.
    { "axiom", { propWorld = true, element = true, defaultLibrary = true } },
    { "function", { propWorld = true, former = true } },
    { "function", { dataWorld = true, former = true } },
    { "function", { dataWorld = true, element = true } },
    { "axiom", { propWorld = true, element = true } },
    { "variable", { dataWorld = true, sort = true, autoImplicit = true } },
  }
  for _, r in ipairs(reps) do
    M.group(r[1], r[2])
  end
  return M
end

--- Every group the picker can edit, in a stable display order.
--- @return { name: string, gloss: string, generated: boolean, overridden: boolean }[]
function M.catalogue()
  local out, seen = {}, {}
  local function add(name, gloss)
    if seen[name] then
      return
    end
    seen[name] = true
    out[#out + 1] = {
      name = name,
      gloss = gloss or gloss_for(name) or "",
      generated = specs[name] ~= nil,
      overridden = M.overrides[name] ~= nil,
    }
  end
  local generated = {}
  for name in pairs(specs) do
    generated[#generated + 1] = name
  end
  table.sort(generated)
  for _, name in ipairs(generated) do
    add(name)
  end
  for _, f in ipairs(FOREIGN) do
    add(f[1], f[2])
  end
  local extra = {}
  for name in pairs(M.overrides) do
    if not seen[name] then
      extra[#extra + 1] = name
    end
  end
  table.sort(extra)
  for _, name in ipairs(extra) do
    add(name, "hand-set group")
  end
  return out
end

--- What a group is currently painted as, both layers separated.
--- @return table generated, table|nil override, table effective
function M.inspect_group(name)
  local gen = specs[name]
  local eff = resolve(name, gen)
  if not eff then
    local ok, h = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    eff = (ok and type(h) == "table") and h or {}
  end
  return gen, M.overrides[name], eff
end

-- ── test surface ───────────────────────────────────────────────────────
-- Used by tests/test_lean.lua and tests/test_lean_palette.lua. Not part of
-- the runtime path.

--- @return table<string, table> every group defined so far, name -> spec
function M._specs()
  return specs
end

--- @return { hits: integer, misses: integer }
function M._stats()
  return { hits = stats.hits, misses = stats.misses }
end

-- ── the one-line edits, kept honest ────────────────────────────────────
-- Each of these is a real distinction the server already sends. They are
-- off because of the budget, not because they are worthless. In rough order
-- of value:
--
--   defaultLibrary  SPENT, 2026-08-13. It is a straight underline; see
--                   `channels.imported_underline`. The old note here said
--                   every style channel was spent and the honest options
--                   were a hue pair per world or nothing — that was wrong by
--                   one, because moving `simp` off the underline had already
--                   freed the slot and only `axiom` and `auto` were
--                   competing for it. `simp` has since been deleted
--                   entirely; its background is free and its underline is
--                   not (three claimants already).
--   instance        a registered instance, as opposed to a plain def.
--   irreducible     `simp` and `rw` will not unfold it, which is exactly
--                   the surprise that costs a reader ten minutes.
--   opaque          same family as `axiom`: the body is unavailable. Would
--                   take the double underline if `axiom` did not have it.
--   noncomputable   no code generated; matters only when compiling.
--
-- Add one by appending to `build_flags`. Everything else — the group name,
-- the memo key, the ColorScheme re-arm, `M.apply`'s regeneration and the
-- tests — follows automatically.

return M
