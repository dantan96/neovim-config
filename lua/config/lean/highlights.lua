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
-- Dan's rule, in his words:
--
--   "the most obviously different things are the ones that do not actually
--    need to have radically different hues; it is often those things that
--    are most similar, however, that do."
--
-- Operationalised: spend contrast where confusion is POSSIBLE, and nowhere
-- else. The measured worst case is the binder list. In
--
--     theorem two_le {m : ℕ} (h0 : m ≠ 0) (h1 : m ≠ 1) : 2 ≤ m
--
-- `m`, `h0` and `h1` are all `@lsp.type.variable.lean`, which links to
-- `Identifier`, which is `#f2cdcd`. Three characters apart, rendering
-- identically — and one of them is a PROOF while the others are DATA. That
-- is where the contrast goes.
--
-- Everything at the other end of the scale gets nothing:
--   * binder annotation — `{x}` / `⦃x⦄` / `[Inst α]` are already brackets;
--   * `declaration` — the binding occurrence is already after `theorem`;
--   * `private`, `protected`, `noncomputable`, `reducible`, `irreducible`,
--     `abbrev` — an adjacent keyword or attribute already says so;
--   * `matchPattern`, `elabWithoutExpectedType` — no reader question is
--     attached to either;
--   * `tactic` vs `keyword` — a tactic is always in tactic position, so `rw`
--     and `fun` are not confusable. Both stay mauve. (This was left open as
--     "worth a decision" in themes.lua; the decision is: not worth a hue.)
--
-- ONE DELIBERATE OMISSION worth naming, because the honest rationale is
-- weaker than it looks: `defaultLibrary` distinguishes a lemma imported from
-- Mathlib from one proved thirty lines up in this file, and NOTHING in the
-- source answers that. Italic below answers local-vs-global, which is a
-- different question. It is genuinely the highest-value remaining channel —
-- but every non-hue channel is already spoken for, and adding an eighth hue
-- breaks the ≤7-anchor budget. Left un-parked deliberately; see the note at
-- the bottom of this file for the one-line edit.
--
-- ─────────────────────────────────────────────────────────────────────────
-- CHANNELS — one question each, so they decode independently
-- ─────────────────────────────────────────────────────────────────────────
--   hue           which world?         prop = blue, data = flamingo,
--                                      poly = teal
--   brightness    a term, or type-level scaffolding?
--                                      element = anchor, sort/former = dusty
--   bold          within the scaffolding, is this the head?
--                                      former = bold
--   italic        bound here, or from the library?   local = italic
--   underline     which invisible attribute?  (ONE slot — the underline
--                 style is a 3-bit enum, so these can never co-occur)
--                                      simp   = dotted, yellow sp
--                                      axiom  = double, red sp
--                                      auto   = dashed, red sp
--   strikethrough deprecated  (set separately by @lsp.mod.deprecated.lean,
--                 and it stacks freely — M4)
--   background    NOT USED HERE, on purpose. It already means "this is not
--                 ordinary source text" twice over — the `sorry` chip and
--                 LspInlayHint — and a third meaning would dissolve the
--                 first two.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHY THESE THREE HUES, SPECIFICALLY
-- ─────────────────────────────────────────────────────────────────────────
-- The palette is chosen so that the two most common things on screen DO NOT
-- MOVE, and the change is paid for entirely by the thing that was wrong:
--
--   propWorld = blue #89b4fa    — catppuccin's `blue`, which is what
--     `Function`, and therefore after/syntax/lean.vim's `leanConstant`, and
--     therefore every cited lemma, already is. `rw [mul_assoc]` renders
--     exactly as it does today, because a cited lemma is prop + element.
--
--   dataWorld = flamingo #f2cdcd — catppuccin's `flamingo`, which is what
--     `Identifier`, and therefore `@lsp.type.variable.lean`, and therefore
--     every `a`, `b`, `m`, `n`, already is. Data locals do not move either.
--
--   polyWorld = teal #94e2d5     — the genuinely-undetermined world (`Sort u`
--     with `u` a parameter). No other hue on this screen is teal.
--
-- So exactly two things change colour, and they are the same statement read
-- in each direction:
--   * a hypothesis `h` moves flamingo → blue: it is a proof, not a datum;
--   * a global `def` such as `Nat.factorial` moves blue → flamingo: it is a
--     datum, not a proof.
-- That is the whole design. Everything else is one step of shade or one
-- attribute bit away from where it already was.
--
-- Hue budget (Healey, ≤ ~7 anchors) counting what is ALREADY on screen:
-- mauve keywords, green strings, peach numbers, grey comments, plus blue,
-- flamingo and teal here. Seven. Red appears only as an underline colour and
-- on auto-implicits, reusing the error association rather than adding an
-- eighth anchor.
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

-- ── colour arithmetic ──────────────────────────────────────────────────
-- The "dusty" step is GENERATED rather than hand-picked, so every hue
-- recedes by exactly the same amount and adding a fourth world later is one
-- line. Blending toward `overlay1` both desaturates and darkens, which is
-- what "this is ambient type context, not the term you are manipulating"
-- should look like.

local function blend(a, b, t)
  local function ch(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local out = "#"
  for _, i in ipairs({ 2, 4, 6 }) do
    local v = math.floor(ch(a, i) + (ch(b, i) - ch(a, i)) * t + 0.5)
    out = out .. string.format("%02x", math.max(0, math.min(255, v)))
  end
  return out
end

local OVERLAY1 = "#7f849c" -- catppuccin mocha overlay1: the "recede" target
local DUST = 0.42 -- one step back; measured by looking, not derived

--- Every colour this file can produce, flat, so the whole palette is one
--- table to read and one table to edit. Derived entries are computed here
--- rather than in the style table so that nothing downstream has to know
--- how a shade was arrived at.
M.palette = {
  -- world anchors (catppuccin mocha names in comments)
  prop = "#89b4fa", -- blue      — proofs, propositions, predicates
  data = "#f2cdcd", -- flamingo  — data, types, constructors
  poly = "#94e2d5", -- teal      — sort-polymorphic: could be either
  -- attribute colours
  simp_sp = "#f9e2af", -- yellow — "the automation knows about this"
  alarm = "#f38ba8", -- red      — axioms and auto-bound implicits
}
M.palette.prop_dust = blend(M.palette.prop, OVERLAY1, DUST)
M.palette.data_dust = blend(M.palette.data, OVERLAY1, DUST)
M.palette.poly_dust = blend(M.palette.poly, OVERLAY1, DUST)

-- ── the grid ───────────────────────────────────────────────────────────
-- World × level, the two axes every classified token carries exactly one of
-- each of. All nine cells are populated: eight are observable in a single
-- 106-line probe file, and the Mathlib census (M12, 766,442 constants) has
-- all nine live. `poly` × `former` is the rare one.

local WORLDS = { propWorld = "prop", dataWorld = "data", polyWorld = "poly" }
local LEVELS = { element = true, sort = true, former = true }

--- Complete spec for one grid cell. Never a delta — see mechanic 1.
local function cell_spec(world, level)
  local base = M.palette[world]
  local dust = M.palette[world .. "_dust"]
  if level == "element" then
    -- The term you manipulate: full strength.
    return { fg = base }
  elseif level == "sort" then
    -- A type or a proposition. Ambient context; step back.
    return { fg = dust }
  else -- former
    -- The head of a type expression — `Set`, `Eq`, `Even`. Same band as a
    -- sort, because it lives at the same place in the tower; bold because
    -- it is the thing doing the work.
    return { fg = dust, bold = true }
  end
end

-- ── flags that change the spec ─────────────────────────────────────────
-- Order is FIXED so that the group name is a function of the set, not of
-- Lua's hash iteration order. Everything not listed here is deliberately
-- unstyled; see the header.

local FLAGS = {
  -- suffix, predicate over (type, modifiers), mutation
  {
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
  },
  {
    "simp",
    function(_, mods)
      return mods.simp
    end,
    function(spec)
      -- `@[simp]`-ness is invisible at the use site and is exactly what a
      -- reader asks when deciding whether `simp` will close a goal.
      spec.underdotted = true
      spec.sp = M.palette.simp_sp
    end,
  },
  {
    "axiom",
    function(ty, _)
      return ty == "axiom"
    end,
    function(spec)
      -- The one global whose authority differs from every other global, and
      -- nothing at the use site says so: `Classical.choice` looks like any
      -- other constant. Double underline = "rests on nothing".
      spec.underdouble = true
      spec.underdotted = nil -- one underline slot; this one wins
      spec.sp = M.palette.alarm
    end,
  },
  {
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
      spec.fg = M.palette.alarm
      spec.underdashed = true
      spec.underdouble = nil
      spec.underdotted = nil
      spec.sp = M.palette.alarm
    end,
  },
}

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

local function define(name, spec)
  specs[name] = spec
  vim.api.nvim_set_hl(0, name, spec)
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

  local name = "@lean." .. world .. "." .. level
  local spec = cell_spec(world, level)
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
      define("@lean." .. world .. "." .. level, cell_spec(world, level))
    end
  end
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
function M.setup()
  define_grid()
  if armed then
    return M
  end
  armed = true

  local aug = vim.api.nvim_create_augroup("LeanSemanticPalette", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = aug,
    callback = function()
      -- Re-emit everything. The memo maps a token pair to a NAME, and the
      -- names do not change, so it stays valid; only the definitions were
      -- cleared.
      define_grid()
      for name, spec in pairs(specs) do
        vim.api.nvim_set_hl(0, name, spec)
      end
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

-- ── test surface ───────────────────────────────────────────────────────
-- Used by tests/test_lean.lua. Not part of the runtime path.

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
--   defaultLibrary  "is this lemma mine, or Mathlib's?" — see the header.
--                   Cheapest expression: a FLAG entry that sets
--                   `spec.fg = blend(spec.fg, OVERLAY1, 0.18)` for imported
--                   names, i.e. locally-proved lemmas sit one notch
--                   brighter than the library around them.
--   instance        a registered instance, as opposed to a plain def.
--   irreducible     `simp` and `rw` will not unfold it, which is exactly
--                   the surprise that costs a reader ten minutes.
--   opaque          same family as `axiom`: the body is unavailable. Would
--                   take the double underline if `axiom` did not have it.
--   noncomputable   no code generated; matters only when compiling.
--
-- Add one by appending to FLAGS. Everything else — the group name, the
-- memo key, the ColorScheme re-arm and the tests — follows automatically.

return M
