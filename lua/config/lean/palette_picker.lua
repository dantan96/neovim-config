-- lua/config/lean/palette_picker.lua — `:LeanPalette`, an interactive
-- chooser for the Lean semantic highlighting.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHAT IT EDITS, AND WHY THERE ARE TWO MODES
-- ─────────────────────────────────────────────────────────────────────────
-- lua/config/lean/highlights.lua does not store forty colours; it ASSEMBLES
-- them from a smaller set of inputs — one hand-picked hue per world × level
-- × locality cell, three attribute colours, and a switch per channel.
-- (It used to compute the sort and former shades by blending toward a
-- recede target. That is deleted: Dan, "FUCK any blending. It's HORSESHIT.")
--
--   GENERATOR mode edits those inputs and regenerates. It is the default
--   because it is the mode in which one keystroke reaches every variant of
--   a colour at once — the plain group, its `.local`, and every lazily
--   built flag-suffixed group — instead of only the one on screen.
--
--   GROUPS mode sets any single group to any colour and any attributes,
--   directly, over the top of whatever the generator produced — including
--   groups the generator never touches (the `@lsp.type.*` pins, the
--   `@lsp.typemod.*` crossings, `leanSorryLike`, `LspInlayHint`,
--   `LeanDocumentHighlight`). It will happily break the hue/brightness
--   scheme. That is a legitimate thing to want and the tool does not argue.
--
-- The two layers are stored separately (see highlights.lua), so a hand-set
-- colour survives a later slider nudge, and either can be undone alone.
--
-- ─────────────────────────────────────────────────────────────────────────
-- THE PREVIEW IS A STATIC SPECIMEN, AND SAYS SO
-- ─────────────────────────────────────────────────────────────────────────
-- It is NOT a live Lean buffer. It cannot be: semantic tokens need an
-- attached server on a real project with the patched toolchain, and the
-- picker has to work anywhere.
--
-- What it is instead is honest in a more useful way. Every token in the
-- specimen carries the (token type, modifier set) that the PATCHED SERVER
-- ACTUALLY EMITTED for it — recorded with
-- docs/lean-highlighting/tools/lsp_probe.py against
-- ~/LeanCourse/MathematicsInLean/PaletteSpecimen.lean, whose elan directory
-- override selects the `lean4-rich` toolchain. Those recorded pairs are
-- then run through `highlights.M.group()` — the REAL generator, the same
-- call the `LspTokenUpdate` handler makes — to pick the group each token is
-- painted with. So the preview exercises the actual code path and the
-- actual classification; only the *arrival* of the tokens is canned.
--
-- Tokens the grid deliberately skips (`keyword`, `tactic`, `leanSorryLike`)
-- fall back to `@lsp.type.<type>.lean`, which is exactly what happens live:
-- the grid declines them and themes.lua's pin decides.
--
-- Recorded classifications worth knowing, because they are counter-intuitive
-- and guessing would have got them wrong:
--   * `s t : Set α` are propWorld + FORMER, not data elements — `Set α`
--     unfolds to `α → Prop`, so a set IS a predicate (C1).
--   * `Evens : Set ℕ` is propWorld + former for the same reason, while
--     `Set` itself is dataWorld + former.
--   * `ℕ` and `Type*` are KEYWORD tokens, not constants (B7).
--   * an `axiom`'s own declaration name gets no token at all; only a
--     REFERENCE to one does, which is why the specimen cites `propext`.
--
-- ─────────────────────────────────────────────────────────────────────────
-- KEYS — `?` inside the picker is the authoritative list (see `KEYS`)
-- ─────────────────────────────────────────────────────────────────────────
--   j / k      move                     /   filter the list
--   h / l      LIGHTNESS ∓ 4%           H / L   walk catppuccin's ladder
--   <Space>    toggle                   <CR>    swatch grid (or edit a group)
--   u          undo                     <C-r>   redo
--   g          generator mode           G   groups mode
--   x          clear this override      X   clear every override (twice)
--   s          save (persists to stdpath("data")/lean-palette.json)
--   y          the source edit for this row, in a scratch buffer
--   p          fold the preview away and watch the real buffer repaint
--   r          restore defaults (twice) q / <Esc>  close      ?  every key
--
-- Saving writes both layers; lua/plugins/themes.lua reads them back on the
-- next start via `highlights.setup({ load_saved = true })`.

local HL = require("config.lean.highlights")

local M = {}

-- ── the specimen ───────────────────────────────────────────────────────
-- Each row is { source line, { text, token type, modifiers }, ... } with the
-- tokens IN SOURCE ORDER. Positions are resolved by scanning for each
-- token's text forward from the end of the previous one, rather than being
-- stored as columns: the server reports UTF-16 offsets and this buffer is
-- UTF-8, and `α`, `ℕ`, `⊆`, `⁻¹` and `↔` all make those disagree. Scanning
-- is exact because the token list is ordered and non-overlapping — the same
-- reason docs/lean-highlighting/tools/hl_cells.lua locates cells by needle.
--
-- GENERATED, not hand-written: see the module header for the probe command.

-- stylua: ignore start
local SPECIMEN = {
  { "variable {α : Type u} {s t : Set α}", { "variable", "keyword", "" }, { "α", "variable", "declaration implicit dataWorld sort local" }, { "s", "variable", "declaration implicit propWorld former local" }, { "t", "variable", "declaration implicit propWorld former local" }, { "Set", "function", "defaultLibrary dataWorld former" }, { "α", "variable", "implicit dataWorld sort local" } },
  { "" },
  { "/-- A `Set`-valued definition: `Set ℕ` unfolds to `ℕ → Prop`. -/" },
  { "def Evens : Set ℕ := {n | n % 2 = 0}", { "def", "keyword", "" }, { "Evens", "function", "declaration propWorld former" }, { "Set", "function", "defaultLibrary dataWorld former" }, { "ℕ", "keyword", "" }, { "n", "variable", "declaration dataWorld element local" }, { "n", "variable", "dataWorld element local" } },
  { "" },
  { "@[simp] theorem evens_zero : 0 ∈ Evens := by", { "simp", "keyword", "" }, { "theorem", "keyword", "" }, { "evens_zero", "theorem", "declaration propWorld element" }, { "Evens", "function", "propWorld former" }, { "by", "keyword", "" } },
  { "  simp [Evens]", { "simp", "tactic", "" }, { "Evens", "function", "propWorld former" } },
  { "" },
  { "theorem subset_antisymm (h1 : s ⊆ t) (h2 : t ⊆ s) : s = t :=", { "theorem", "keyword", "" }, { "subset_antisymm", "theorem", "declaration propWorld element" }, { "h1", "variable", "declaration propWorld element local" }, { "s", "variable", "implicit propWorld former local" }, { "t", "variable", "implicit propWorld former local" }, { "h2", "variable", "declaration propWorld element local" }, { "t", "variable", "implicit propWorld former local" }, { "s", "variable", "implicit propWorld former local" }, { "s", "variable", "implicit propWorld former local" }, { "t", "variable", "implicit propWorld former local" } },
  { "  Set.Subset.antisymm h1 h2", { "Set.Subset", "function", "defaultLibrary propWorld former protected" } },
  { "" },
  { "theorem inv_eq_of_mul (G : Type*) [Group G] (a b : G) (h : a * b = 1) :", { "theorem", "keyword", "" }, { "inv_eq_of_mul", "theorem", "declaration propWorld element" }, { "G", "variable", "declaration dataWorld sort local" }, { "Type*", "keyword", "" }, { "Group", "class", "defaultLibrary dataWorld former" }, { "G", "variable", "dataWorld sort local" }, { "a", "variable", "declaration dataWorld element local" }, { "b", "variable", "declaration dataWorld element local" }, { "G", "variable", "dataWorld sort local" }, { "h", "variable", "declaration propWorld element local" }, { "a", "variable", "dataWorld element local" }, { "b", "variable", "dataWorld element local" } },
  { "    a⁻¹ = b := by", { "a", "variable", "dataWorld element local" }, { "b", "variable", "dataWorld element local" }, { "by", "keyword", "" } },
  { "  rw [← mul_one a⁻¹, ← h, ← mul_assoc, inv_mul_cancel, one_mul]", { "rw", "tactic", "" }, { "mul_one", "theorem", "defaultLibrary simp propWorld element" }, { "a", "variable", "dataWorld element local" }, { "h", "variable", "propWorld element local" }, { "mul_assoc", "theorem", "defaultLibrary propWorld element" }, { "inv_mul_cancel", "theorem", "defaultLibrary simp propWorld element" }, { "one_mul", "theorem", "defaultLibrary simp propWorld element" } },
  { "" },
  { "/-- Sort-polymorphic: `Sort u` is genuinely undetermined. -/" },
  { "def idPoly {β : Sort u} (x : β) : β := x", { "def", "keyword", "" }, { "idPoly", "function", "declaration polyWorld element" }, { "β", "variable", "declaration implicit polyWorld sort local" }, { "Sort", "keyword", "" }, { "x", "variable", "declaration polyWorld element local" }, { "β", "variable", "implicit polyWorld sort local" }, { "β", "variable", "implicit polyWorld sort local" }, { "x", "variable", "polyWorld element local" } },
  { "" },
  { "theorem eq_of_iff (p q : Prop) (h : p ↔ q) : p = q := propext h", { "theorem", "keyword", "" }, { "eq_of_iff", "theorem", "declaration propWorld element" }, { "p", "variable", "declaration propWorld sort local" }, { "q", "variable", "declaration propWorld sort local" }, { "h", "variable", "declaration propWorld element local" }, { "p", "variable", "propWorld sort local" }, { "q", "variable", "propWorld sort local" }, { "p", "variable", "propWorld sort local" }, { "q", "variable", "propWorld sort local" }, { "propext", "axiom", "defaultLibrary propWorld element" }, { "h", "variable", "propWorld element local" } },
  { "" },
  { "theorem evens_two_mul (n : ℕ) : 2 * n ∈ Evens := by", { "theorem", "keyword", "" }, { "evens_two_mul", "theorem", "declaration propWorld element" }, { "n", "variable", "declaration dataWorld element local" }, { "ℕ", "keyword", "" }, { "n", "variable", "dataWorld element local" }, { "Evens", "function", "propWorld former" }, { "by", "keyword", "" } },
  { "  sorry", { "sorry", "leanSorryLike", "" } },
}
-- stylua: ignore end

--- What each specimen line is there to show. Keyed by a substring so an
--- edit to the specimen cannot silently misalign the annotations.
local WHY = {
  ["{s t : Set α}"] = "α is a data sort; s and t are Prop formers — `Set α` IS `α → Prop`",
  ["def Evens"] = "a Set-valued definition: a former in the Prop world",
  ["@[simp] theorem"] = "@[simp] is deliberately UNMARKED — the tint was deleted",
  ["subset_antisymm"] = "h1 and h2 are proofs; s and t beside them are not",
  ["inv_eq_of_mul"] = "the binder list the palette exists for: G, a, b, h — three worlds",
  ["mul_one"] = "cited lemmas — the underline says Mathlib's, not yours",
  ["idPoly"] = "Sort u — genuinely undetermined, the third world",
  ["propext"] = "an axiom reference: it rests on nothing",
  ["sorry"] = "the one thing that must be impossible to miss",
}

--- Resolve the specimen's tokens to byte ranges on their line.
--- @return { line: integer, col: integer, len: integer, ty: string, mods: table }[]
local function specimen_tokens()
  local out = {}
  for lnum, row in ipairs(SPECIMEN) do
    local line = row[1]
    local from = 1
    for i = 2, #row do
      local text, ty, modstr = row[i][1], row[i][2], row[i][3]
      local at = line:find(text, from, true)
      if at then
        local mods = {}
        for m in modstr:gmatch("%S+") do
          mods[m] = true
        end
        out[#out + 1] = { line = lnum, col = at - 1, len = #text, ty = ty, mods = mods, text = text }
        from = at + #text
      end
    end
  end
  return out
end

local TOKENS = specimen_tokens()

-- ── the colour ladder ──────────────────────────────────────────────────
-- Colour choice is a walk along catppuccin mocha's own ramp rather than a
-- free wheel, because this palette is built on that ladder and an arbitrary
-- hex sits beside the rest of the buffer badly. `<CR>` still accepts any
-- hex at all — the ladder is the fast path, not the only one.

-- stylua: ignore start
local LADDER = {
  { "rosewater", "#f5e0dc" }, { "flamingo", "#f2cdcd" }, { "pink",     "#f5c2e7" },
  { "mauve",     "#cba6f7" }, { "red",      "#f38ba8" }, { "maroon",   "#eba0ac" },
  { "peach",     "#fab387" }, { "yellow",   "#f9e2af" }, { "green",    "#a6e3a1" },
  { "teal",      "#94e2d5" }, { "sky",      "#89dceb" }, { "sapphire", "#74c7ec" },
  { "blue",      "#89b4fa" }, { "lavender", "#b4befe" }, { "text",     "#cdd6f4" },
  { "subtext1",  "#bac2de" }, { "subtext0", "#a6adc8" }, { "overlay2", "#9399b2" },
  { "overlay1",  "#7f849c" }, { "overlay0", "#6c7086" }, { "surface2", "#585b70" },
  { "surface1",  "#45475a" }, { "surface0", "#313244" }, { "base",     "#1e1e2e" },
  { "mantle",    "#181825" }, { "crust",    "#11111b" },
}
-- stylua: ignore end

--- Name the ladder rung a hex sits on, when it sits on one.
local function ladder_name(hex)
  for _, e in ipairs(LADDER) do
    if e[2]:lower() == tostring(hex):lower() then
      return e[1]
    end
  end
  return "custom"
end

-- ── how far apart two colours are ──────────────────────────────────────
-- Sum of the three channel deltas, the same metric tests/helpers.lua
-- `H.hex_gap` uses, for the same reasons: no colour-space library, monotone
-- in the thing being asked about, and every number reproducible by hand.

--- @return integer 0 identical, 765 black-to-white
local function hex_gap(a, b)
  local function ch(s, i)
    return tonumber(tostring(s):sub(i, i + 1), 16) or 0
  end
  local d = 0
  for _, i in ipairs({ 2, 4, 6 }) do
    d = d + math.abs(ch(a, i) - ch(b, i))
  end
  return d
end

-- ── HSL, because `h`/`l` used to DESTROY an off-ladder colour ───────────
-- MEASURED, and this is the bug the whole key layout below exists to fix:
-- with the cursor on `data_element_local` (`#ffa8ff`), one `l` produced
-- `#f5e0dc` — rosewater, LADDER[1] — and one further `h` produced `#11111b`.
-- The old `ladder_step` had to FIND the current hex among the rungs to walk
-- from it, and half the palette is now off the ladder, so its `not idx`
-- fallback returned an end of the list. The loss was silent, instant, on the
-- primary adjust key, and unrecoverable.
--
-- So the two jobs are split and neither can lose a value:
--
--   h / l   lightness ∓/± 4% in HSL. Defined for ANY hex, on or off the
--           ladder, and reversible: it is "a bit lighter", which is the
--           commonest thing to want and was previously impossible.
--   H / L   the ladder walk, from the NEAREST rung. An off-ladder hex now
--           steps to the neighbour of the rung it most resembles rather
--           than to the top of the list. (Before this, `H`/`L` were silent
--           duplicates of `h`/`l` — `adjust`'s `big` argument was only ever
--           read by a `number` row kind that no longer exists.)

local function clamp01(x)
  return math.max(0, math.min(1, x))
end

--- @param hex string `#rrggbb`
--- @return number r 0..1
--- @return number g 0..1
--- @return number b 0..1
local function hex_rgb(hex)
  local s = tostring(hex):gsub("^#", "")
  if #s ~= 6 then
    return 0, 0, 0
  end
  return (tonumber(s:sub(1, 2), 16) or 0) / 255,
    (tonumber(s:sub(3, 4), 16) or 0) / 255,
    (tonumber(s:sub(5, 6), 16) or 0) / 255
end

local function rgb_hex(r, g, b)
  return ("#%02x%02x%02x"):format(
    math.floor(clamp01(r) * 255 + 0.5),
    math.floor(clamp01(g) * 255 + 0.5),
    math.floor(clamp01(b) * 255 + 0.5)
  )
end

--- One `@return` PER VALUE. A single line naming three types declares ONE
--- return, and every `return h, s, l` below is then a `redundant-return-value`
--- against an annotation that is simply wrong.
--- @return number h 0..1
--- @return number s 0..1
--- @return number l 0..1
local function rgb_hsl(r, g, b)
  local mx, mn = math.max(r, g, b), math.min(r, g, b)
  local l = (mx + mn) / 2
  if mx == mn then
    return 0, 0, l -- grey: hue is undefined, and 0 is as good as any
  end
  local d = mx - mn
  local s = l > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
  local h
  if mx == r then
    h = (g - b) / d + (g < b and 6 or 0)
  elseif mx == g then
    h = (b - r) / d + 2
  else
    h = (r - g) / d + 4
  end
  return h / 6, s, l
end

local function hsl_rgb(h, s, l)
  if s == 0 then
    return l, l, l
  end
  local function hue(p, q, t)
    t = t % 1
    if t < 1 / 6 then
      return p + (q - p) * 6 * t
    elseif t < 1 / 2 then
      return q
    elseif t < 2 / 3 then
      return p + (q - p) * (2 / 3 - t) * 6
    end
    return p
  end
  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3)
end

--- Lightness ± `delta` (a fraction of the full 0..1 range), preserving hue
--- and saturation. Exposed for the tests: this is the function that must
--- never turn a hand-picked colour into a different one.
--- @param hex string `#rrggbb`
--- @param delta number e.g. 0.04
--- @return string `#rrggbb`
function M.nudge(hex, delta)
  if type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then
    return hex
  end
  local h, s, l = rgb_hsl(hex_rgb(hex))
  return rgb_hex(hsl_rgb(h, s, clamp01(l + delta)))
end

--- The ladder rung a hex most resembles. Total: every hex has a nearest
--- rung, so the walk always has somewhere honest to start.
--- @return integer index into LADDER
function M.nearest_rung(hex)
  local best, bestd = 1, math.huge
  for i, e in ipairs(LADDER) do
    local d = hex_gap(hex, e[2])
    if d < bestd then
      best, bestd = i, d
    end
  end
  return best
end

--- Walk the ladder. An exact rung moves one place; anything else moves to
--- the neighbour of the rung it is CLOSEST to, so the first press of a walk
--- costs at most the distance to that rung and never the whole list.
--- @return string `#rrggbb`
function M.ladder_step(hex, delta)
  local idx
  for i, e in ipairs(LADDER) do
    if e[2]:lower() == tostring(hex):lower() then
      idx = i
      break
    end
  end
  if not idx then
    -- NOT `LADDER[1]`: that was the data loss. Land on the nearest rung
    -- first, then step, so `l` on `#ffa8ff` reaches pink's neighbour.
    idx = M.nearest_rung(hex)
    return LADDER[(idx - 1 + delta) % #LADDER + 1][2]
  end
  return LADDER[(idx - 1 + delta) % #LADDER + 1][2]
end

local ladder_step = M.ladder_step

--- The lightness step `h`/`l` takes. 4% of the full range: small enough that
--- a press is a nudge and not a decision, large enough to be visible.
local NUDGE = 0.04

-- ── swatch groups ──────────────────────────────────────────────────────

local swatch_cache = {}
local function swatch(hex)
  if not hex then
    return nil
  end
  local name = "LeanPalettePickerSw" .. hex:gsub("#", "")
  if not swatch_cache[name] then
    swatch_cache[name] = true
    vim.api.nvim_set_hl(0, name, { fg = hex })
  end
  return name
end

--- Cleared on every colorscheme change, since the swatches are plain
--- foreground definitions and `:colorscheme` wipes them.
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("LeanPalettePickerSwatches", { clear = true }),
  callback = function()
    swatch_cache = {}
  end,
})

-- ── UI state ───────────────────────────────────────────────────────────

local S = {
  open = false,
  mode = "generator", -- generator | groups | group
  cursor = { generator = 1, groups = 1, group = 1 },
  group_name = nil, -- which group `group` mode is editing
  rows = {}, -- current mode's selectable rows
  buf = {},
  win = {},
  ns = vim.api.nvim_create_namespace("LeanPalettePicker"),
  status = "",
  filter = "", -- item 4: `/` narrows the list
  compact = false, -- item 5: preview folded away, the real buffer visible
  pending = nil, -- item 12: which destructive key is armed
}

local function o()
  return HL.opts
end

--- Read/write a dotted path into the input table.
local function get_path(p)
  local cur = o()
  for _, k in ipairs(p) do
    cur = cur[k]
  end
  return cur
end

-- ── undo ───────────────────────────────────────────────────────────────
-- The other half of item 1's wound: before this, nothing in the picker could
-- take back the last thing you did, so a colour lost to a stray keypress was
-- lost. Both layers are snapshotted — the generator inputs and the override
-- table — because that is exactly the pair `save` writes, so the ring needs
-- no state model of its own.
--
-- THE RESTORE GOES THROUGH THE MODULE'S OWN MUTATORS, and that is not
-- ceremony. Assigning `HL.overrides = snap` and repainting would bypass
-- `restore_baseline`, so a group whose override the undo removes would keep
-- the hand-set colour instead of falling back to the theme's own — a wrong
-- undo, which is worse than no undo. Clear-then-set is the only shape that
-- gets the baseline machinery to run.

local RING = 40 -- entries; a snapshot is two small tables

local undo_ring, redo_ring = {}, {}

local function snapshot()
  return { inputs = vim.deepcopy(HL.opts), overrides = vim.deepcopy(HL.overrides) }
end

local function restore(snap)
  for _, name in ipairs(vim.tbl_keys(HL.overrides)) do
    if snap.overrides[name] == nil then
      HL.clear_override(name)
    end
  end
  for name, spec in pairs(snap.overrides) do
    HL.set_override(name, vim.deepcopy(spec))
  end
  HL.apply(vim.deepcopy(snap.inputs))
end

--- Record the state a mutation is about to leave behind. Called from the
--- few choke points every mutation passes through, NOT from the key
--- handlers: `x`, `X`, `r` and `<CR>` do not go through `adjust`, and an
--- undo that covers only the arrow keys would leave exactly the destructive
--- ones unrecoverable.
local function checkpoint()
  undo_ring[#undo_ring + 1] = snapshot()
  if #undo_ring > RING then
    table.remove(undo_ring, 1)
  end
  redo_ring = {}
end

--- @return integer, integer how many steps back and forward are available
function M._rings()
  return #undo_ring, #redo_ring
end

local function set_path(p, v)
  checkpoint()
  local inputs = vim.deepcopy(o())
  local cur = inputs
  for i = 1, #p - 1 do
    cur = cur[p[i]]
  end
  cur[p[#p]] = v
  HL.apply(inputs)
end

-- ── row construction ───────────────────────────────────────────────────
-- A row is { kind, text, spans, ... }. `kind == "head"` is decoration and
-- is skipped by cursor movement; everything else is selectable and knows
-- how to adjust itself.

local function head(text)
  return { kind = "head", text = text }
end

--- `target` is the name `:LeanPalette set|source` knows this row by. It is
--- the last path component and not the label, because a channel's label is
--- prose (`local → italic`) and its target is an identifier
--- (`local_italic`) — `y` (item 13) has to hand the second one to
--- `M.source_for`, and guessing it back out of the label is not possible.
local function colour_row(label, path, gloss, indent)
  return {
    kind = "colour",
    label = label,
    gloss = gloss,
    indent = indent,
    target = path[#path],
    get = function()
      return get_path(path)
    end,
    set = function(v)
      set_path(path, v)
    end,
  }
end

local function bool_row(label, path, gloss)
  return {
    kind = "bool",
    label = label,
    gloss = gloss,
    target = path[#path],
    get = function()
      return get_path(path)
    end,
    set = function(v)
      set_path(path, v)
    end,
  }
end

local function enum_row(label, path, choices, gloss)
  return {
    kind = "enum",
    label = label,
    gloss = gloss,
    choices = choices,
    target = path[#path],
    get = function()
      return get_path(path)
    end,
    set = function(v)
      set_path(path, v)
    end,
  }
end

--- What each hue is for. A LOOKUP rather than a fixed row list, because
--- `hues` is arbitrary-keyed: the shipped set is the three worlds, but the
--- palette is meant to widen to a hand-picked colour per cell and a hue this
--- table has never heard of must still get a row. Unknown keys simply have
--- no description yet.
local HUE_GLOSS = {
  prop = "the Prop world — anchor for @lean.prop only",
  data = "the data world — anchor for @lean.data only",
  poly = "sort-polymorphic — anchor for @lean.poly only",

  prop_element_local = "A HYPOTHESIS — h0, h1",
  prop_element = "a cited lemma — mul_assoc",
  prop_sort_local = "a local p : Prop",
  prop_sort = "A PROPOSITION — 2 ≤ m, True",
  prop_former_local = "a local predicate p : α → Prop",
  prop_former = "A PREDICATE — Even, Prime, Set",

  data_element_local = "A DATUM YOU BOUND — m, n",
  data_element = "a global datum — Nat.factorial",
  data_sort_local = "A TYPE VARIABLE — α, G",
  data_sort = "a concrete type — ℕ, Filter α",
  data_former_local = "a local type family",
  data_former = "a type constructor — List, Prod",

  poly_element_local = "a local term in Sort u",
  poly_element = "a term in Sort u",
  poly_sort_local = "a local α : Sort u",
  poly_sort = "a sort-polymorphic type",
  poly_former_local = "a local sort-polymorphic former",
  poly_former = "a sort-polymorphic former — the rare cell",

  kind_constructor = "a constructor — how you BUILD data",
  kind_projection = "a structure projection",
  kind_class = "a class — Group, Monoid, Ring",
}

-- ── the order the hues are shown in ────────────────────────────────────
-- ALPHABETICAL DESTROYED THE GRID IT IS A VIEW OF (item 15). The palette is
-- organised as world × level × locality, and sorting by name put
-- `prop_element_local` (a hypothesis) sixteen rows away from
-- `data_element_local` (a datum) — the two cells the whole palette exists to
-- separate, and the pair you most need to see side by side.
--
-- FALLS BACK RATHER THAN DROPS. `hues` is arbitrary-keyed on purpose: a key
-- this version has never heard of must still get a row, so anything the
-- layout does not claim lands under OTHER, in sorted order.
local WORLD_ORDER = { "prop", "data", "poly" }
local LEVEL_ORDER = { "element", "sort", "former" }
local WORLD_HEAD = {
  prop = "PROP · proofs, statements and predicates",
  data = "DATA · values, types and type formers",
  poly = "POLY · sort-polymorphic — genuinely undetermined",
}

local function generator_rows()
  local rows = {}
  local hues = o().hues
  local left = {}
  for k in pairs(hues) do
    left[k] = true
  end
  local function take(k, indent)
    if left[k] then
      left[k] = nil
      rows[#rows + 1] = colour_row(k, { "hues", k }, HUE_GLOSS[k] or "", indent)
    end
  end
  for _, w in ipairs(WORLD_ORDER) do
    local before = #rows
    rows[#rows + 1] = head(WORLD_HEAD[w])
    for _, lv in ipairs(LEVEL_ORDER) do
      take(w .. "_" .. lv)
      -- The `_local` variant indented under its partner: "the imported one
      -- and the one you bound" is a pair, and reading it as a pair is the
      -- point of the indent.
      take(w .. "_" .. lv .. "_local", true)
    end
    if #rows == before + 1 then
      rows[before + 1] = nil -- a world with no cells gets no heading
    end
  end
  local kinds = {}
  for k in pairs(left) do
    if k:match("^kind_") then
      kinds[#kinds + 1] = k
    end
  end
  table.sort(kinds)
  if #kinds > 0 then
    rows[#rows + 1] = head("KINDS · what a declaration IS, across all worlds")
    for _, k in ipairs(kinds) do
      take(k)
    end
  end
  -- ANCHORS last and under their own heading (item 10). They are not
  -- parents of anything: `data` names `@lean.data` and feeds nothing else,
  -- and sitting at the top of a flat list directly above `data_element` it
  -- read as the parent of the twenty-one cells below it. They must stay
  -- DEFINED — `define_grid` paints them and a group with no `fg` renders
  -- colourless (B1) — so they are moved, not dropped.
  local anchors = {}
  for _, w in ipairs(WORLD_ORDER) do
    if left[w] then
      anchors[#anchors + 1] = w
    end
  end
  local other = {}
  for k in pairs(left) do
    if not vim.tbl_contains(anchors, k) then
      other[#other + 1] = k
    end
  end
  table.sort(other)
  if #other > 0 then
    rows[#rows + 1] = head("OTHER · hue keys this layout does not know")
    for _, k in ipairs(other) do
      take(k)
    end
  end
  if #anchors > 0 then
    rows[#rows + 1] = head("ANCHORS · name @lean.<world> and feed nothing else")
    for _, k in ipairs(anchors) do
      take(k)
    end
  end
  local rest = {
    head("ATTRIBUTE COLOURS · what the flags paint with"),
    colour_row("alarm", { "alarm" }, "axioms and auto-bound implicits"),
    head("CHANNELS · one question each, so they decode independently"),
    bool_row("former → bold", { "channels", "former_bold" }, "the head of a type expression"),
    bool_row("local → italic", { "channels", "local_italic" }, "bound here, not imported"),
    enum_row(
      "imported → ",
      { "channels", "imported_underline" },
      HL.underline_styles,
      "Mathlib's lemma, not yours — yields the slot to axiom and auto"
    ),
    enum_row("axiom → ", { "channels", "axiom_underline" }, HL.underline_styles, "rests on nothing"),
    enum_row("auto → ", { "channels", "auto_underline" }, HL.underline_styles, "the elaborator bound it"),
    bool_row("auto → alarm fg", { "channels", "auto_recolour" }, "loud on purpose"),
  }
  for _, r in ipairs(rest) do
    rows[#rows + 1] = r
  end
  return rows
end

local function groups_rows()
  local rows = { head("EVERY GROUP · ● overridden   · generated   <CR> to edit") }
  for _, e in ipairs(HL.catalogue()) do
    rows[#rows + 1] = { kind = "group", entry = e, target = e.name }
  end
  return rows
end

local ATTRS = {
  { "fg", "colour" },
  { "bg", "colour" },
  { "sp", "colour" },
  { "bold", "bool" },
  { "italic", "bool" },
  { "strikethrough", "bool" },
  { "reverse", "bool" },
  { "underline style", "enum" },
}

local function group_rows()
  local name = S.group_name
  local _, ov, eff = HL.inspect_group(name)
  local rows = {
    head(name),
    head(HL.gloss_for(name) or ""),
    head(ov and "OVERRIDDEN — x clears it, X clears every override" or "generated"),
  }
  for _, a in ipairs(ATTRS) do
    rows[#rows + 1] = { kind = "attr", attr = a[1], atype = a[2], eff = eff, ov = ov }
  end
  return rows
end

--- What a row can be matched against by `/` — item 4. Everything visible on
--- it, so "the pink one" is findable by its gloss and not only by its name.
--- Built by APPENDING, never as a table literal: `{ row.label, row.target,
--- … }` leaves a nil HOLE at index 1 for a row with no label, and
--- `table.concat` raises on it. That raise happens inside `render`, i.e.
--- inside a redraw, so the symptom is the picker going blank rather than any
--- message — found by driving the TUI, not by reading this back.
local function haystack(row)
  local bits = {}
  for _, k in ipairs({ "label", "target", "gloss", "attr" }) do
    if type(row[k]) == "string" then
      bits[#bits + 1] = row[k]
    end
  end
  if row.entry then
    bits[#bits + 1] = row.entry.name or ""
    bits[#bits + 1] = row.entry.gloss or ""
  end
  return table.concat(bits, " "):lower()
end

--- Keep only rows matching `S.filter`.
---
--- HEADINGS ARE DROPPED rather than kept-if-their-section-survives: a
--- filtered list is a flat answer to a question, and a heading above a
--- section whose other rows are hidden claims a structure that is not on
--- screen. The filter's own heading says how many matched.
local function apply_filter(rows)
  if S.filter == "" then
    return rows
  end
  local needle = S.filter:lower()
  local out = {}
  for _, r in ipairs(rows) do
    if r.kind ~= "head" and haystack(r):find(needle, 1, true) then
      out[#out + 1] = r
    end
  end
  table.insert(out, 1, head(("/%s · %d match%s · / again to change, <BS> to clear"):format(S.filter, #out, #out == 1 and "" or "es")))
  return out
end

local function build_rows()
  if S.mode == "generator" then
    S.rows = apply_filter(generator_rows())
  elseif S.mode == "groups" then
    S.rows = apply_filter(groups_rows())
  else
    S.rows = group_rows() -- eight attributes; nothing to search
  end
  -- The cursor can be left past the end by anything that shortens the list —
  -- `r` dropping a hue key, a filter, a mode with fewer rows. Clamped here
  -- rather than at each of those sites, because a stale index does not error:
  -- `S.rows[i]` is nil, `adjust` returns silently, and the picker reads as a
  -- widget whose keys have stopped working.
  local i = S.cursor[S.mode] or 1
  if i > #S.rows then
    i = #S.rows
  end
  while i >= 1 and S.rows[i] and S.rows[i].kind == "head" do
    i = i + 1
  end
  if i > #S.rows then
    i = #S.rows
  end
  S.cursor[S.mode] = math.max(1, i)
end

-- ── the effective spec for a group, as text ────────────────────────────

local function eff_of(name)
  local _, _, eff = HL.inspect_group(name)
  return eff or {}
end

local function hexof(v)
  if type(v) == "string" then
    return v
  end
  if type(v) == "number" then
    return string.format("#%06x", v)
  end
  return nil
end

--- The five styles as attribute keys — `M.underline_styles` without the
--- "none" entry. Only one can be on a cell at a time (B4).
local UNDERLINES = { "underline", "undercurl", "underdouble", "underdotted", "underdashed" }

local function current_underline(eff)
  for _, u in ipairs(UNDERLINES) do
    if eff[u] then
      return u
    end
  end
  return "none"
end

-- ── rendering ──────────────────────────────────────────────────────────

-- The footers are a HINT, not the legend — item 8. One string long enough to
-- hold every key overflows the pane and gets centre-clipped at both ends,
-- which loses keys; splitting it across two footers only made the clip
-- happen twice, and at 80×24 the second one lost `x/X c` from its middle.
-- `?` opens the full legend, which is also where every key added since can
-- be discovered.
local CONTROLS_FOOTER = " j/k · h/l · ? keys "
local PREVIEW_FOOTER = " ? for every key "


local BAR = "███"
--- Its DISPLAY width. `#BAR` is 9 — three characters of three bytes each —
--- and using it in a column budget silently overstated the prefix by six,
--- which at 80x24 dropped the hex column that would have fitted.
local BARW = 3

--- Cut `text` to at most `w` display columns, on a character boundary.
--- Descriptions are the first thing to go when the pane is narrow: a
--- half-word running into the window edge reads as a broken widget, whereas
--- a short description reads as a short description.
local function fit(text, w)
  if w <= 0 then
    return ""
  end
  if vim.fn.strdisplaywidth(text) <= w then
    return text
  end
  local out = vim.fn.strcharpart(text, 0, w)
  while vim.fn.strdisplaywidth(out) > w and #out > 0 do
    out = vim.fn.strcharpart(out, 0, vim.fn.strchars(out) - 1)
  end
  return out
end

--- Pad to a DISPLAY width, not a byte count.
---
--- `("%-18s"):format("local → italic")` pads to eighteen BYTES, and `→` is
--- three of them, so that row came out two columns short of every other one.
--- The same trap in reverse is item 7: `%-10s` against a nineteen-character
--- key does not truncate, it overflows, and every column after the label
--- shifts right by nine.
local function pad(s, w)
  local n = vim.fn.strdisplaywidth(s)
  return s .. string.rep(" ", math.max(0, w - n))
end

--- Assemble a row from `{ text, width, hl }` segments, returning the line
--- and the BYTE spans its extmarks need. Written as a builder because the
--- two indices genuinely differ — display columns decide the layout, byte
--- offsets decide the marks — and every hand-computed `#cur + 18 + 1` in the
--- old code was one multi-byte label away from painting the wrong span.
local function seg(parts)
  local text, spans = "", {}
  for _, p in ipairs(parts) do
    local s = p[2] and pad(p[1], p[2]) or p[1]
    local from = #text
    text = text .. s
    if p[3] then
      spans[#spans + 1] = { from, #text, p[3] }
    end
  end
  return text, spans
end

--- The width the label column needs, computed from the longest label
--- actually present rather than fixed at ten. `hues` is arbitrary-keyed, so
--- a hardcoded width is wrong the moment the palette widens — which is
--- exactly how it broke: the shipped keys are already nineteen characters.
local function label_width(rows)
  local w = 10
  for _, r in ipairs(rows) do
    if r.label then
      w = math.max(w, vim.fn.strdisplaywidth(r.label) + (r.indent and 2 or 0))
    end
  end
  return w
end

local function name_width(rows, cap)
  local w = 12
  for _, r in ipairs(rows) do
    if r.entry then
      w = math.max(w, vim.fn.strdisplaywidth(r.entry.name))
    end
  end
  return math.min(w, cap)
end

local function render_controls()
  local buf = S.buf.controls
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local W = (S.win.controls and vim.api.nvim_win_is_valid(S.win.controls))
      and vim.api.nvim_win_get_width(S.win.controls)
    or 60
  local lines, marks = {}, {}
  local function put(text, spans)
    lines[#lines + 1] = text
    for _, s in ipairs(spans or {}) do
      -- A nil group means "paint nothing". Painting "Normal" here was a real
      -- bug: inside a float with style="minimal" the background is
      -- NormalFloat, so an explicit Normal extmark stamped the GLOBAL
      -- background over it and left a visible dark rectangle behind every
      -- unselected row.
      if s[3] then
        marks[#marks + 1] = { #lines - 1, s[1], s[2], s[3] }
      end
    end
  end

  --- Emit one row: a fixed prefix, then as much description as still fits.
  --- A gloss needs ROOM TO BE A WORD. Measured at 80x24: two columns were
  --- left after the prefix, so every description rendered as a single letter
  --- (`a`, `A`) hanging off the end of the row — which is not a short
  --- description, it is a rendering artefact that looks like one.
  local GLOSS_MIN = 6
  local function row_line(prefix, gloss, spans)
    local text = prefix
    if gloss and gloss ~= "" then
      local room = W - vim.fn.strdisplaywidth(prefix) - 1
      local cut = room >= GLOSS_MIN and fit(gloss, room) or ""
      if cut ~= "" then
        spans[#spans + 1] = { #prefix + 1, #prefix + 1 + #cut, "Comment" }
        text = prefix .. " " .. cut
      end
    end
    put(fit(text, W), spans)
  end

  local tabs = S.mode == "groups" or S.mode == "group"
  put("")
  put(
    ("  %s   %s"):format(tabs and "  generator" or "▎ GENERATOR", tabs and "▎ GROUPS" or "  groups"),
    { { 2, 13, tabs and "Comment" or "Title" }, { 16, 26, tabs and "Title" or "Comment" } }
  )
  put("")

  local LW = label_width(S.rows)
  -- The name column is capped so that a long `@lsp.typemod.…` name cannot
  -- push the gloss (item 6) off the pane on its own; anything longer is cut
  -- by `fit`, which is the same treatment the gloss gets.
  local NW = name_width(S.rows, math.max(20, W - 34))
  -- WHICH COLUMNS FIT. At 80x24 the control pane is 38 and the prefix alone
  -- is 43, so the row used to be clipped by the window edge mid-word — which
  -- reads as a broken widget, and which is the narrow half of item 7. The
  -- optional columns are therefore DROPPED in increasing order of value: the
  -- ladder name first (it reads `custom` for half the palette now), then the
  -- hex. What is left always fits.
  local base = 2 + LW + 1 + BARW + 1
  local show_hex = W >= base + 8
  local show_rung = W >= base + 8 + 9

  -- Where each row actually landed. The real cursor is parked on the
  -- selected row so Neovim scrolls the list for us, and that used to be
  -- `S.cursor + 3` — a hardcoded count of the header lines above. Any row
  -- added above the list (the filter's heading, a section heading) desyncs
  -- it, and a desynced cursor does not error: the window scrolls to the
  -- wrong place and the selection appears stuck.
  S.rowline = {}

  for i, row in ipairs(S.rows) do
    local sel = (i == S.cursor[S.mode])
    local cur = sel and "▸ " or "  "
    local selhl = sel and "Special" or nil
    S.rowline[i] = #lines + 1
    if row.kind == "head" then
      put(fit("  " .. row.text, W), { { 2, 2 + #row.text, "Title" } })
    elseif row.kind == "colour" then
      local hex = row.get()
      local parts = {
        { cur, 2, selhl },
        { (row.indent and "  " or "") .. row.label, LW + 1, sel and "Title" or nil },
        { BAR .. " ", nil, swatch(hex) },
      }
      if show_hex then
        parts[#parts + 1] = { tostring(hex) .. " ", nil }
      end
      if show_rung then
        parts[#parts + 1] = { ladder_name(hex), 9 }
      end
      local prefix, spans = seg(parts)
      row_line(prefix, row.gloss, spans)
    elseif row.kind == "bool" then
      local v = row.get()
      local prefix, spans = seg({
        { cur, 2, selhl },
        { row.label, LW + 1, sel and "Title" or nil },
        { v and "[on] " or "[off]", nil, v and "DiagnosticOk" or "Comment" },
      })
      row_line(prefix, row.gloss, spans)
    elseif row.kind == "enum" then
      local v = row.get()
      local prefix, spans = seg({
        { cur, 2, selhl },
        { row.label, LW + 1, sel and "Title" or nil },
        { "[" .. v .. "]", 13, v == "none" and "Comment" or "DiagnosticOk" },
      })
      row_line(prefix, row.gloss, spans)
    elseif row.kind == "group" then
      -- ITEM 6: the hex and the gloss were COMPUTED AND DISCARDED. Every
      -- catalogue entry carries a gloss and `FOREIGN` carries hand-written
      -- English for all of its groups, and a group row showed neither — so
      -- the one mode that can reach every group was the one that told you
      -- least about them.
      local e = row.entry
      local eff = eff_of(e.name)
      local hex = hexof(eff.fg)
      local mark = e.overridden and "●" or "·"
      local gparts = {
        { cur, 2, selhl },
        { mark .. " ", nil, e.overridden and "DiagnosticWarn" or "Comment" },
        -- `@lean.ns.prefix` sets no `fg` ON PURPOSE, so its swatch is blank
        -- and its hex column reads `—`. That is the group being honest about
        -- painting an underline and nothing else, not a missing value.
        { hex and (BAR .. " ") or "    ", nil, hex and swatch(hex) or nil },
      }
      if W >= 6 + 8 + NW then
        gparts[#gparts + 1] = { hex or "—", 8 }
      end
      gparts[#gparts + 1] = { e.name, NW + 1, sel and "Title" or nil }
      local prefix, spans = seg(gparts)
      row_line(prefix, e.gloss, spans)
    elseif row.kind == "attr" then
      local eff = row.eff or {}
      local ovset = row.ov
        and (
          row.attr == "underline style"
            and (function()
              for _, u in ipairs(UNDERLINES) do
                if row.ov[u] ~= nil then
                  return true
                end
              end
              return false
            end)()
          or row.ov[row.attr] ~= nil
        )
      local val
      if row.atype == "colour" then
        val = hexof(eff[row.attr]) or "—"
      elseif row.atype == "enum" then
        val = current_underline(eff)
      else
        val = eff[row.attr] and "[on] " or "[off]"
      end
      local sw = row.atype == "colour" and hexof(eff[row.attr]) or nil
      local prefix, spans = seg({
        { cur, 2, selhl },
        { row.attr, 17, sel and "Title" or nil },
        { sw and (BAR .. " ") or "    ", nil, sw and swatch(sw) or nil },
        { val, 12 },
      })
      row_line(prefix, ovset and "set here" or "", spans)
      if ovset then
        marks[#marks + 1] = { #lines - 1, #prefix + 1, 400, "DiagnosticWarn" }
      end
    end
  end

  put("")

  -- THE STATUS GOES IN THE FOOTER, not at the bottom of the buffer. Measured
  -- at 200×50 with the widened palette: the list is 42 rows in a 42-row
  -- window, so a status line appended after it is BELOW THE FOLD and never
  -- seen — which would have made item 12's "r again to discard …" pre-flight
  -- and item 16's gap reading invisible exactly when they matter. The footer
  -- cannot scroll away. It is centre-clipped when too long (item 8), so it is
  -- cut to fit first.
  if S.win.controls and vim.api.nvim_win_is_valid(S.win.controls) then
    local text = S.status ~= "" and (" " .. fit(S.status, W - 4) .. " ") or CONTROLS_FOOTER
    pcall(vim.api.nvim_win_set_config, S.win.controls, { footer = text, footer_pos = "center" })
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)
  for _, m in ipairs(marks) do
    if m[4] then
      pcall(vim.api.nvim_buf_set_extmark, buf, S.ns, m[1], m[2], {
        end_col = math.min(m[3], #(lines[m[1] + 1] or "")),
        hl_group = m[4],
      })
    end
  end
end

local function render_preview()
  local buf = S.buf.preview
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines = {
    "",
    "  STATIC SPECIMEN — not a live buffer.",
    "  Classifications recorded from the patched server; the colours",
    "  come from the real generator.",
    "",
  }
  local offset = #lines
  for _, row in ipairs(SPECIMEN) do
    lines[#lines + 1] = "  " .. row[1]
  end
  lines[#lines + 1] = ""

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, S.ns, 0, -1)

  for i = 2, 4 do
    pcall(vim.api.nvim_buf_set_extmark, buf, S.ns, i - 1, 0, {
      end_col = #lines[i],
      hl_group = i == 2 and "DiagnosticWarn" or "Comment",
    })
  end

  -- The comment lines of the specimen itself.
  for lnum, row in ipairs(SPECIMEN) do
    if row[1]:match("^%s*/%-") then
      pcall(vim.api.nvim_buf_set_extmark, buf, S.ns, offset + lnum - 1, 0, {
        end_col = #lines[offset + lnum],
        hl_group = "Comment",
      })
    end
  end

  -- THE POINT: every token painted through the real generator.
  for _, t in ipairs(TOKENS) do
    local group = HL.group(t.ty, t.mods) or ("@lsp.type." .. t.ty .. ".lean")
    pcall(vim.api.nvim_buf_set_extmark, buf, S.ns, offset + t.line - 1, t.col + 2, {
      end_col = t.col + 2 + t.len,
      hl_group = group,
      priority = 200,
    })
  end

  -- Why each line is here, in the right margin where there is room.
  local width = S.win.preview and vim.api.nvim_win_get_width(S.win.preview) or 60
  for lnum, row in ipairs(SPECIMEN) do
    for needle, why in pairs(WHY) do
      if row[1]:find(needle, 1, true) then
        if width > 78 then
          pcall(vim.api.nvim_buf_set_extmark, buf, S.ns, offset + lnum - 1, 0, {
            virt_text = { { "  ← " .. why, "Comment" } },
            virt_text_pos = "eol",
          })
        end
        break
      end
    end
  end
end

local function render()
  build_rows()
  render_controls()
  render_preview()
  -- Keep the real cursor on the selected row so scrolling follows it.
  local win = S.win.controls
  if win and vim.api.nvim_win_is_valid(win) then
    local target = (S.rowline or {})[S.cursor[S.mode]] or 1
    local n = vim.api.nvim_buf_line_count(S.buf.controls)
    pcall(vim.api.nvim_win_set_cursor, win, { math.max(1, math.min(target, n)), 0 })
  end
end

-- ── actions ────────────────────────────────────────────────────────────

local function selectable(i)
  local r = S.rows[i]
  return r and r.kind ~= "head"
end

--- ITEM 16 — the one question a palette editor is FOR: *are these two things
--- far enough apart?* Answered for the row under the cursor, on the status
--- line, without asking: the collisions in the shipped palette are
--- deliberate and you should be able to see which ones you are standing on.
---
--- The gap is `tests/helpers.lua H.hex_gap`'s metric, deliberately, so the
--- number on screen is the number the `two_le` floor is written against.
--- Neighbours are the adjacent COLOUR rows, which after item 15 means the
--- cells the grouping puts beside each other rather than whatever sorted
--- next alphabetically.
--- @return string
local function colour_note(i)
  local row = S.rows[i]
  if not row or row.kind ~= "colour" then
    return ""
  end
  local hex = tostring(row.get())
  local same = {}
  for j, r in ipairs(S.rows) do
    if j ~= i and r.kind == "colour" and tostring(r.get()):lower() == hex:lower() then
      same[#same + 1] = r.label
    end
  end
  local function neighbour(dir)
    local j = i + dir
    while S.rows[j] do
      if S.rows[j].kind == "colour" then
        return hex_gap(hex, tostring(S.rows[j].get()))
      end
      j = j + dir
    end
    return nil
  end
  local up, down = neighbour(-1), neighbour(1)
  local parts = {}
  if up or down then
    parts[#parts + 1] = ("gap %s↑ %s↓"):format(up or "—", down or "—")
  end
  if #same > 0 then
    parts[#parts + 1] = "also " .. table.concat(same, ", ")
  end
  return table.concat(parts, " · ")
end

local function move(delta)
  local i = S.cursor[S.mode]
  local n = #S.rows
  for _ = 1, n do
    i = i + delta
    if i < 1 then
      i = n
    elseif i > n then
      i = 1
    end
    if selectable(i) then
      break
    end
  end
  S.cursor[S.mode] = i
  S.status = colour_note(i)
  render()
end

--- Write one attribute of an override, preserving the rest of it.
local function patch_override(name, key, value)
  checkpoint()
  local _, ov = HL.inspect_group(name)
  local spec = vim.deepcopy(ov or {})
  if key == "underline style" then
    for _, u in ipairs(UNDERLINES) do
      spec[u] = nil
    end
    if value ~= "none" then
      spec[value] = true
    end
    -- An override that now says nothing would linger as an empty entry.
    if next(spec) == nil then
      HL.clear_override(name)
      return
    end
  else
    spec[key] = value
  end
  local ok, bad = HL.set_override(name, spec)
  if not ok then
    S.status = "rejected: " .. table.concat(bad or {}, ", ")
  end
end

--- Move a colour by one press.
--- @param hex string|nil
--- @param delta integer -1 or 1
--- @param ladder boolean|nil walk the theme ramp instead of nudging lightness
local function step_colour(hex, delta, ladder)
  hex = hex or "#cdd6f4"
  if ladder then
    return ladder_step(hex, delta)
  end
  return M.nudge(hex, delta * NUDGE)
end

--- @param delta integer -1 or 1
--- @param ladder boolean|nil `H`/`L`: walk the ladder rather than nudge.
---   Named for what it does. Its predecessor was called `big` and was read
---   by exactly one row kind, `number`, which had already been deleted with
---   the blend — so `H`/`L` silently did what `h`/`l` did (item 14).
local function adjust(delta, ladder)
  local row = S.rows[S.cursor[S.mode]]
  if not row then
    return
  end
  S.status = ""
  if row.kind == "colour" then
    row.set(step_colour(row.get(), delta, ladder))
  elseif row.kind == "bool" then
    row.set(not row.get())
  elseif row.kind == "enum" then
    local cur, idx = row.get(), 1
    for i, c in ipairs(row.choices) do
      if c == cur then
        idx = i
      end
    end
    row.set(row.choices[(idx - 1 + delta) % #row.choices + 1])
  elseif row.kind == "group" then
    -- h/l on the list is a shortcut for nudging that group's fg.
    local eff = eff_of(row.entry.name)
    patch_override(row.entry.name, "fg", step_colour(hexof(eff.fg), delta, ladder))
  elseif row.kind == "attr" then
    local name = S.group_name
    local eff = row.eff or {}
    if row.atype == "colour" then
      patch_override(name, row.attr, step_colour(hexof(eff[row.attr]), delta, ladder))
    elseif row.atype == "bool" then
      patch_override(name, row.attr, not eff[row.attr])
    else
      local styles = HL.underline_styles
      local cur, idx = current_underline(eff), 1
      for i, c in ipairs(styles) do
        if c == cur then
          idx = i
        end
      end
      patch_override(name, "underline style", styles[(idx - 1 + delta) % #styles + 1])
    end
  end
  if S.status == "" then
    S.status = colour_note(S.cursor[S.mode])
  end
  render()
end

-- ── choosing a colour by looking at it ─────────────────────────────────
-- ITEM 9. `<CR>` used to open `vim.ui.input` expecting `#rrggbb`, which is
-- the worst possible input method for a visual decision. What replaces it is
-- a grid of swatches: the 26 rungs of the theme's own ramp, and — more
-- useful, and free — THE COLOURS ALREADY IN THIS PALETTE, which are the ones
-- a new choice actually has to sit beside. `i` still types a hex, because
-- that is literally how `#00bfff` was chosen and it must stay one key away.

local G = {
  open = false,
  buf = nil,
  win = nil,
  cells = {}, -- { hex, name }
  idx = 1,
  cols = 1,
  on_pick = nil,
  title = "",
  ns = vim.api.nvim_create_namespace("LeanPaletteSwatches"),
}

--- Every distinct colour currently in the palette, with what uses it. The
--- second half of the grid, and the half that answers "what have I already
--- got?" rather than "what does catppuccin have?".
local function palette_cells()
  local order, by_hex = {}, {}
  local function note(hex, label)
    if type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then
      return
    end
    hex = hex:lower()
    if not by_hex[hex] then
      by_hex[hex] = label
      order[#order + 1] = hex
    end
  end
  local names = vim.tbl_keys(HL.opts.hues)
  table.sort(names)
  for _, k in ipairs(names) do
    note(HL.opts.hues[k], k)
  end
  note(HL.opts.alarm, "alarm")
  local ok, ns = pcall(require, "config.lean.namespace_hl")
  if ok and type(ns) == "table" and type(ns.palette) == "table" then
    local pnames = vim.tbl_keys(ns.palette)
    table.sort(pnames)
    for _, k in ipairs(pnames) do
      note(ns.palette[k], "p." .. k)
    end
    for i, hex in ipairs(ns.palette.rainbow or {}) do
      note(hex, "rainbow" .. i)
    end
  end
  local out = {}
  for _, hex in ipairs(order) do
    out[#out + 1] = { hex, by_hex[hex] }
  end
  return out
end

local function close_grid()
  G.open = false
  if G.win and vim.api.nvim_win_is_valid(G.win) then
    pcall(vim.api.nvim_win_close, G.win, true)
  end
  if G.buf and vim.api.nvim_buf_is_valid(G.buf) then
    pcall(vim.api.nvim_buf_delete, G.buf, { force = true })
  end
  G.win, G.buf = nil, nil
end

local render_grid

--- @param title string
--- @param current string|nil the colour being replaced, so the grid opens on it
--- @param on_pick fun(hex: string)
local function open_grid(title, current, on_pick)
  G.cells = {}
  for _, e in ipairs(LADDER) do
    G.cells[#G.cells + 1] = { e[2], e[1] }
  end
  local seen = {}
  for _, c in ipairs(G.cells) do
    seen[c[1]:lower()] = true
  end
  local extra = {}
  for _, c in ipairs(palette_cells()) do
    if not seen[c[1]] then
      seen[c[1]] = true
      extra[#extra + 1] = c
    end
  end
  G.split = #G.cells -- where the ladder ends and the palette's own begins
  vim.list_extend(G.cells, extra)
  G.idx = 1
  for i, c in ipairs(G.cells) do
    if current and c[1]:lower() == tostring(current):lower() then
      G.idx = i
      break
    end
  end
  G.on_pick = on_pick
  G.title = title

  -- Sized from the longest name present rather than fixed: the ladder's
  -- rungs are short (`rosewater`) and the palette's own keys are not
  -- (`data_element_local`), and a fixed 12 ran the second section's columns
  -- into each other. Measured at 200x50 before the fix.
  G.namew = 10
  for _, c in ipairs(G.cells) do
    G.namew = math.max(G.namew, vim.fn.strdisplaywidth(c[2]))
  end
  G.cols = 4
  local cellw = G.namew + 7
  local width = G.cols * cellw
  while G.cols > 1 and width + 6 > vim.o.columns do
    G.cols = G.cols - 1
    width = G.cols * cellw
  end
  local rows = math.ceil(#G.cells / G.cols) + 4
  local height = math.min(rows, vim.o.lines - 6)
  G.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[G.buf].bufhidden = "wipe"
  G.win = vim.api.nvim_open_win(G.buf, true, {
    relative = "editor",
    width = math.min(width, vim.o.columns - 4),
    height = math.max(6, height),
    row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
    col = math.max(1, math.floor((vim.o.columns - width) / 2)),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = " hjkl move · <CR> pick · i type a hex · q cancel ",
    footer_pos = "center",
  })
  vim.wo[G.win].wrap = false
  G.open = true

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = G.buf, nowait = true, silent = true })
  end
  local function shift(d)
    G.idx = math.max(1, math.min(#G.cells, G.idx + d))
    render_grid()
  end
  map("h", function()
    shift(-1)
  end)
  map("l", function()
    shift(1)
  end)
  map("k", function()
    shift(-G.cols)
  end)
  map("j", function()
    shift(G.cols)
  end)
  map("<Left>", function()
    shift(-1)
  end)
  map("<Right>", function()
    shift(1)
  end)
  map("<Up>", function()
    shift(-G.cols)
  end)
  map("<Down>", function()
    shift(G.cols)
  end)
  map("<CR>", function()
    local hex = G.cells[G.idx] and G.cells[G.idx][1]
    close_grid()
    if hex then
      on_pick(hex)
    end
  end)
  -- `vim.fn.input`, not `vim.ui.input`. The rest of this config prefers the
  -- latter and it is the wrong tool twice here: it is ASYNCHRONOUS, so the
  -- answer arrives after the grid has gone and the picker has redrawn, and
  -- it routes through whichever provider is configured — which means this
  -- key cannot be driven from a script and therefore cannot be verified the
  -- way everything else here was. The native prompt is synchronous, needs no
  -- provider, and reads from the same typeahead `feedkeys` writes to.
  map("i", function()
    local start = G.cells[G.idx] and G.cells[G.idx][1] or "#"
    close_grid()
    local ok, v = pcall(vim.fn.input, { prompt = title .. " hex: ", default = start })
    if ok and type(v) == "string" and v:match("^#%x%x%x%x%x%x$") then
      on_pick(v:lower())
    elseif ok and type(v) == "string" and v ~= "" and v ~= start then
      S.status = "not a hex colour: " .. v
      render()
    else
      render()
    end
  end)
  map("q", function()
    close_grid()
    render()
  end)
  map("<Esc>", function()
    close_grid()
    render()
  end)
  render_grid()
end

render_grid = function()
  if not (G.buf and vim.api.nvim_buf_is_valid(G.buf)) then
    return
  end
  local lines, marks = {}, {}
  local function flush(from, to, heading)
    lines[#lines + 1] = "  " .. heading
    marks[#marks + 1] = { #lines - 1, 0, 400, "Title" }
    local text, spans = "", {}
    local n = 0
    for i = from, to do
      local hex, name = G.cells[i][1], G.cells[i][2]
      local sel = i == G.idx
      local piece = (sel and "▸" or " ") .. BAR .. " " .. pad(name, G.namew) .. "  "
      local at = #text
      text = text .. piece
      spans[#spans + 1] = { at + 1, at + 1 + #BAR, swatch(hex) }
      if sel then
        spans[#spans + 1] = { at, at + 1, "Special" }
        spans[#spans + 1] = { at + 1 + #BAR + 1, #text, "Title" }
      end
      n = n + 1
      if n % G.cols == 0 or i == to then
        lines[#lines + 1] = text
        for _, s in ipairs(spans) do
          marks[#marks + 1] = { #lines - 1, s[1], s[2], s[3] }
        end
        text, spans = "", {}
      end
    end
  end
  flush(1, G.split, "THE THEME'S LADDER")
  if #G.cells > G.split then
    lines[#lines + 1] = ""
    flush(G.split + 1, #G.cells, "ALREADY IN THIS PALETTE")
  end
  lines[#lines + 1] = ""
  local cur = G.cells[G.idx]
  lines[#lines + 1] = ("  %s  %s"):format(cur and cur[1] or "", cur and cur[2] or "")
  vim.bo[G.buf].modifiable = true
  vim.api.nvim_buf_set_lines(G.buf, 0, -1, false, lines)
  vim.bo[G.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(G.buf, G.ns, 0, -1)
  for _, m in ipairs(marks) do
    if m[4] then
      pcall(vim.api.nvim_buf_set_extmark, G.buf, G.ns, m[1], m[2], {
        end_col = math.min(m[3], #(lines[m[1] + 1] or "")),
        hl_group = m[4],
      })
    end
  end
  -- Keep the selected cell on screen.
  for i, l in ipairs(lines) do
    if l:find("▸", 1, true) then
      pcall(vim.api.nvim_win_set_cursor, G.win, { i, 0 })
      break
    end
  end
end

local function enter()
  local row = S.rows[S.cursor[S.mode]]
  if not row then
    return
  end
  if row.kind == "group" then
    S.group_name = row.entry.name
    S.mode = "group"
    S.cursor.group = 4
    render()
    return
  end
  if row.kind == "colour" then
    open_grid(row.label, row.get(), function(v)
      row.set(v)
      render()
    end)
    return
  end
  if row.kind == "attr" and row.atype == "colour" then
    local eff = row.eff or {}
    local name = S.group_name
    open_grid(name .. " " .. row.attr, hexof(eff[row.attr]), function(v)
      patch_override(name, row.attr, v)
      render()
    end)
    return
  end
  adjust(1)
end

local function clear_one()
  local row = S.rows[S.cursor[S.mode]]
  local name = (row and row.kind == "group" and row.entry.name) or S.group_name
  if name and HL.overrides[name] ~= nil then
    checkpoint()
  end
  if name and HL.clear_override(name) then
    S.status = "cleared override on " .. name .. " — u to undo"
  else
    S.status = "no override there"
  end
  render()
end

-- Defined further down, with the legend it closes; forward-declared because
-- `close` must be able to take the overlay down with the picker and a stray
-- float outliving its owner is how a "closed" picker keeps painting.
local close_help

local function close()
  S.open = false
  S.pending = nil
  close_grid()
  if close_help then
    close_help()
  end
  for _, w in pairs(S.win) do
    if w and vim.api.nvim_win_is_valid(w) then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  for _, b in pairs(S.buf) do
    if b and vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  S.win, S.buf = {}, {}
end

-- ── window construction ────────────────────────────────────────────────

local function scratch()
  local b = vim.api.nvim_create_buf(false, true)
  vim.bo[b].bufhidden = "wipe"
  vim.bo[b].modifiable = false
  return b
end

-- ── geometry ───────────────────────────────────────────────────────────
-- ITEM 17. The caps were `min(146, columns - 6)` and `min(34, lines - 8)`,
-- which on a 200×50 terminal drew a 146×34 dialog with a 49-row list
-- scrolling inside 34 rows of it and 55 rows of screen unused. The caps
-- existed because the preview's longest specimen line is 73 columns and more
-- width buys the PREVIEW nothing — true, and the wrong conclusion: the extra
-- width buys the CONTROL PANE the gloss back (items 6 and 7) and the extra
-- height buys the list its missing rows. So the preview keeps its 78 and the
-- control pane takes the rest, up to a width past which a line of prose
-- stops being comfortable to read.
--
-- ITEM 5, the compact layout: the two floats covered columns 27–145 of a
-- 200-column screen, i.e. the Mathlib buffer actually being judged was
-- underneath them. `p` folds the preview away and parks the control pane
-- against the right edge, so `h`/`l` repaints the real file in the open —
-- `HL.apply` already ends in `refresh_live_buffers()`, so that repaint is
-- free. The specimen is not thrown away: it is honest about being canned and
-- it exercises the real generator, which is worth keeping for the times the
-- picker is opened from a buffer that is not Lean at all.
local PREVIEW_W = 78
local CONTROLS_MAX = 110

--- @return table controls the control pane's window config
--- @return table|nil preview the preview's, or nil when folded away (item 5)
local function geometry()
  local ui_w, ui_h = vim.o.columns, vim.o.lines
  local avail = ui_w - 6
  local height = math.max(6, ui_h - 8)
  local row = math.max(0, math.floor((ui_h - height) / 2) - 1)
  if S.compact then
    local w = math.max(30, math.min(CONTROLS_MAX, math.floor(avail / 2)))
    return {
      relative = "editor",
      width = w,
      height = height,
      row = row,
      col = math.max(0, ui_w - w - 3),
    }, nil
  end
  local left = math.max(38, math.min(CONTROLS_MAX, avail - PREVIEW_W - 2))
  local right = math.max(20, math.min(PREVIEW_W, avail - left - 2))
  local total = left + right + 2
  local col = math.max(0, math.floor((ui_w - total) / 2))
  return {
    relative = "editor",
    width = left,
    height = height,
    row = row,
    col = col,
  }, {
    relative = "editor",
    width = right,
    height = height,
    row = row,
    col = col + left + 2,
  }
end

local function open_windows()
  local cfg, pcfg = geometry()

  S.buf.controls = scratch()
  S.buf.preview = scratch()

  S.win.controls = vim.api.nvim_open_win(
    S.buf.controls,
    true,
    vim.tbl_extend("force", cfg, {
      style = "minimal",
      border = "rounded",
      title = " Lean palette ",
      title_pos = "center",
      footer = CONTROLS_FOOTER,
      footer_pos = "center",
    })
  )
  if pcfg then
    S.win.preview = vim.api.nvim_open_win(
      S.buf.preview,
      false,
      vim.tbl_extend("force", pcfg, {
        style = "minimal",
        border = "rounded",
        title = " preview ",
        title_pos = "center",
        footer = PREVIEW_FOOTER,
        footer_pos = "center",
      })
    )
  end

  for _, w in pairs(S.win) do
    vim.wo[w].wrap = false
    vim.wo[w].cursorline = false
  end
  -- Wrap in the preview so a narrow terminal FOLDS a long specimen line
  -- rather than hiding its tail. Extmarks travel with the text when it
  -- wraps, so a token keeps its colour either way; a clipped line would
  -- silently drop tokens from view and make the preview a partial answer.
  if S.win.preview then
    vim.wo[S.win.preview].wrap = true
    vim.wo[S.win.preview].linebreak = true
  end
  -- The control list is longer than the window once the palette widens past
  -- a handful of hues. Nothing else is needed to scroll it: `render()` puts
  -- the real cursor on the selected row, so Neovim keeps it in view — and
  -- 'scrolloff' means the selection is never pinned to the last visible line.
  vim.wo[S.win.controls].scrolloff = 3
end

--- Move between the two layouts without tearing the picker down: the
--- control window keeps its buffer, its keymaps and its cursor, so `p` is a
--- view change and not a restart.
local function relayout()
  local cfg, pcfg = geometry()
  if S.win.controls and vim.api.nvim_win_is_valid(S.win.controls) then
    pcall(vim.api.nvim_win_set_config, S.win.controls, cfg)
  end
  if pcfg then
    if not (S.win.preview and vim.api.nvim_win_is_valid(S.win.preview)) then
      S.buf.preview = scratch()
      S.win.preview = vim.api.nvim_open_win(
        S.buf.preview,
        false,
        vim.tbl_extend("force", pcfg, {
          style = "minimal",
          border = "rounded",
          title = " preview ",
          title_pos = "center",
          footer = PREVIEW_FOOTER,
          footer_pos = "center",
        })
      )
      vim.wo[S.win.preview].wrap = true
      vim.wo[S.win.preview].linebreak = true
      vim.wo[S.win.preview].cursorline = false
    else
      pcall(vim.api.nvim_win_set_config, S.win.preview, pcfg)
    end
  elseif S.win.preview and vim.api.nvim_win_is_valid(S.win.preview) then
    pcall(vim.api.nvim_win_close, S.win.preview, true)
    S.win.preview = nil
    S.buf.preview = nil
  end
  render()
end

-- ── the legend ─────────────────────────────────────────────────────────
-- ITEM 8. Every key, in one place, reachable from either pane.

local KEYS = {
  { "MOVE" },
  { "j / k", "next / previous row" },
  { "/", "filter the list; `/` with an empty answer clears it" },
  { "<BS>", "clear the filter, or leave the attribute editor" },
  { "MODES" },
  { "g", "GENERATOR — the inputs the palette is assembled from" },
  { "G", "GROUPS — every highlight group, including the ones outside the grid" },
  { "<CR>", "on a group: edit its attributes.  on a colour: the swatch grid" },
  { "CHANGE A COLOUR" },
  { "h / l", "LIGHTNESS ∓ 4% — works on any colour, on the ladder or off it" },
  { "H / L", "walk catppuccin's ladder, starting from the nearest rung" },
  { "<CR>", "the swatch grid: the 26 rungs, then this palette's own colours" },
  { "<Space>", "toggle a boolean, cycle an underline style" },
  { "UNDO" },
  { "u", "step back — covers h/l, <CR>, x, X and r alike" },
  { "<C-r>", "step forward again" },
  { "CLEAR AND SAVE" },
  { "x", "clear the override on this group" },
  { "X", "clear EVERY override (press twice)" },
  { "r", "restore the shipped palette (press twice)" },
  { "s", "save both layers to the JSON (`y` prints the SOURCE edit instead)" },
  { "y", "the exact edit that would put this row in SOURCE, in a scratch buffer" },
  { "LAYOUT" },
  { "p", "fold the preview away and see the real buffer repaint" },
  { "?", "this" },
  { "q / <Esc>", "close" },
}

local Hlp = { win = nil, buf = nil }

-- Assignment, not `local function`: the name is declared up beside `close`,
-- and a second `local` here would shadow it and leave that one nil forever.
close_help = function()
  if Hlp.win and vim.api.nvim_win_is_valid(Hlp.win) then
    pcall(vim.api.nvim_win_close, Hlp.win, true)
  end
  Hlp.win, Hlp.buf = nil, nil
end

local function open_help()
  if Hlp.win and vim.api.nvim_win_is_valid(Hlp.win) then
    close_help()
    return
  end
  local lines, marks = {}, {}
  local width = 12
  for _, k in ipairs(KEYS) do
    width = math.max(width, vim.fn.strdisplaywidth(k[1]))
  end
  for _, k in ipairs(KEYS) do
    if not k[2] then
      if #lines > 0 then
        lines[#lines + 1] = ""
      end
      lines[#lines + 1] = "  " .. k[1]
      marks[#marks + 1] = { #lines - 1, 0, 400, "Title" }
    else
      local left = "  " .. pad(k[1], width + 2)
      lines[#lines + 1] = left .. k[2]
      marks[#marks + 1] = { #lines - 1, 2, #("  " .. k[1]), "Special" }
      marks[#marks + 1] = { #lines - 1, #left, 400, "Comment" }
    end
  end
  local w = 12
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l) + 2)
  end
  w = math.min(w, vim.o.columns - 4)
  local h = math.min(#lines, vim.o.lines - 4)
  Hlp.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(Hlp.buf, 0, -1, false, lines)
  vim.bo[Hlp.buf].modifiable = false
  vim.bo[Hlp.buf].bufhidden = "wipe"
  Hlp.win = vim.api.nvim_open_win(Hlp.buf, true, {
    relative = "editor",
    width = w,
    height = math.max(4, h),
    row = math.max(0, math.floor((vim.o.lines - h) / 2) - 1),
    col = math.max(0, math.floor((vim.o.columns - w) / 2)),
    style = "minimal",
    border = "rounded",
    title = " :LeanPalette keys ",
    title_pos = "center",
  })
  vim.wo[Hlp.win].wrap = false
  local ns = vim.api.nvim_create_namespace("LeanPaletteHelp")
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, Hlp.buf, ns, m[1], m[2], {
      end_col = math.min(m[3], #(lines[m[1] + 1] or "")),
      hl_group = m[4],
    })
  end
  for _, lhs in ipairs({ "q", "<Esc>", "?", "<CR>" }) do
    vim.keymap.set("n", lhs, close_help, { buffer = Hlp.buf, nowait = true, silent = true })
  end
end

--- @return string[] the legend, for a test that every mapped key is in it
function M._keys()
  return vim.tbl_map(function(k)
    return k[1]
  end, KEYS)
end

-- ── undo, redo, and the two-press guard ────────────────────────────────

local function undo()
  local snap = table.remove(undo_ring)
  if not snap then
    S.status = "nothing to undo"
    render()
    return
  end
  redo_ring[#redo_ring + 1] = snapshot()
  restore(snap)
  S.status = ("undone — %d step%s back, %d forward"):format(
    #undo_ring,
    #undo_ring == 1 and "" or "s",
    #redo_ring
  )
  render()
end

local function redo()
  local snap = table.remove(redo_ring)
  if not snap then
    S.status = "nothing to redo"
    render()
    return
  end
  undo_ring[#undo_ring + 1] = snapshot()
  restore(snap)
  S.status = ("redone — %d back, %d forward"):format(#undo_ring, #redo_ring)
  render()
end

--- What `r` and `X` are about to take, counted before they take it.
--- @return integer hues, integer channels, integer overrides
local function dirty()
  local d = HL.defaults()
  local hues, chans = 0, 0
  for k, v in pairs(HL.opts.hues) do
    if v ~= d.hues[k] then
      hues = hues + 1
    end
  end
  if HL.opts.alarm ~= d.alarm then
    hues = hues + 1
  end
  for k, v in pairs(HL.opts.channels) do
    if v ~= d.channels[k] then
      chans = chans + 1
    end
  end
  return hues, chans, vim.tbl_count(HL.overrides)
end

local function plural(n, word)
  return ("%d %s%s"):format(n, word, n == 1 and "" or "s")
end

local function keymaps()
  local buf = S.buf.controls
  --- Every key clears whatever the last one armed (item 12), so a `r` you
  --- thought better of is disarmed by the next thing you press rather than
  --- lying in wait. The handler receives what WAS armed, which is how the
  --- two-press keys recognise their own second press.
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, function()
      local armed = S.pending
      S.pending = nil
      fn(armed)
    end, { buffer = buf, nowait = true, silent = true })
  end
  map("u", undo)
  map("<C-r>", redo)
  map("?", open_help)
  map("p", function()
    S.compact = not S.compact
    S.status = S.compact and "preview folded — h/l repaints the real buffer; p to bring it back"
      or ""
    relayout()
  end)
  -- ITEM 4. A LIVE filter, not a prompt. `vim.ui.input` would have been two
  -- lines shorter and is what the rest of this config reaches for, but it is
  -- the wrong shape here twice over: it opens a float OVER the list you are
  -- narrowing, and it shows you nothing until the whole string is committed.
  -- `getcharstr` reads from the same typeahead that `feedkeys` writes to, so
  -- the list narrows as you type AND the key is drivable from a script —
  -- which is how it is verified.
  map("/", function()
    local before, q = S.filter, S.filter
    local function count()
      local n = 0
      for _, r in ipairs(S.rows) do
        if r.kind ~= "head" then
          n = n + 1
        end
      end
      return n
    end
    while true do
      S.filter = q
      S.cursor[S.mode] = 1
      render()
      S.status = ("/%s█   %d row%s · <CR> keep · <Esc> cancel"):format(
        q,
        count(),
        count() == 1 and "" or "s"
      )
      render()
      local ok, ch = pcall(vim.fn.getcharstr)
      if not ok or ch == "" or ch == "\r" or ch == "\n" then
        break
      elseif ch == "\27" then
        q = before
        break
      elseif ch == "\8" or ch == "\127" or ch == vim.keycode("<BS>") then
        -- One CHARACTER, not one byte. The names are ASCII but the glosses
        -- are not, and rubbing out a third of a `→` leaves an invalid string
        -- that matches nothing and reads as the filter having broken.
        q = vim.fn.strcharpart(q, 0, math.max(0, vim.fn.strchars(q) - 1))
      elseif #ch == 1 and ch:byte() < 32 then
        break -- any other control key ends the filter rather than entering it
      else
        q = q .. ch
      end
    end
    S.filter = q
    S.cursor[S.mode] = 1
    render()
    S.status = q == "" and ""
      or ("/%s — %d row%s · <BS> clears it"):format(q, count(), count() == 1 and "" or "s")
    render()
  end)
  map("y", function()
    local row = S.rows[S.cursor[S.mode]]
    local target = (row and row.target) or S.group_name
    if not target then
      S.status = "no source edit for this row"
      render()
      return
    end
    -- ITEM 13. `s` writes JSON, and an override that only lives in
    -- `lean-palette.json` is invisible from the config and how the palette
    -- drifts from its source. `:LeanPalette source` already computes the
    -- exact edit, routed by where the group is actually defined — this is
    -- purely the TUI knowing that exists.
    local lines = M.source_for(target)
    -- The picker STAYS OPEN behind this. Closing it first was the obvious
    -- thing and it is wrong twice: this handler is a mapping on the control
    -- buffer, so `close`'s `nvim_buf_delete(force)` deletes the buffer whose
    -- mapping is mid-execution; and the answer to "where does this go in
    -- source" is something you read and then carry on editing.
    local b = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
    vim.bo[b].filetype = "diff"
    vim.bo[b].bufhidden = "wipe"
    vim.api.nvim_open_win(b, true, {
      relative = "editor",
      width = math.min(100, vim.o.columns - 4),
      height = math.min(#lines + 1, vim.o.lines - 6),
      row = math.max(0, math.floor(vim.o.lines / 4)),
      col = math.max(0, math.floor((vim.o.columns - math.min(100, vim.o.columns - 4)) / 2)),
      style = "minimal",
      border = "rounded",
      title = " source edit for " .. target .. " — yank it ",
      title_pos = "center",
    })
    vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = b, nowait = true, silent = true })
  end)
  map("j", function()
    move(1)
  end)
  map("k", function()
    move(-1)
  end)
  map("<Down>", function()
    move(1)
  end)
  map("<Up>", function()
    move(-1)
  end)
  map("l", function()
    adjust(1)
  end)
  map("h", function()
    adjust(-1)
  end)
  map("L", function()
    adjust(1, true)
  end)
  map("H", function()
    adjust(-1, true)
  end)
  map("<Right>", function()
    adjust(1)
  end)
  map("<Left>", function()
    adjust(-1)
  end)
  map("<Space>", function()
    adjust(1)
  end)
  map("<CR>", enter)
  map("g", function()
    S.mode = "generator"
    S.status = ""
    render()
  end)
  map("G", function()
    S.mode = "groups"
    S.status = ""
    render()
  end)
  map("<BS>", function()
    -- The filter is the innermost thing `<BS>` can back out of, so it goes
    -- first: pressing it in a filtered attribute editor should not drop you
    -- into a list that is still narrowed to one row.
    if S.filter ~= "" then
      S.filter = ""
      S.status = "filter cleared"
    else
      S.mode = S.mode == "group" and "groups" or S.mode
    end
    render()
  end)
  map("x", clear_one)
  -- ITEM 12: `r` and `X` were unconfirmed, unrecoverable, and did not say
  -- what they would take. Measured: `r` from a state with one hue moved and
  -- one override set restored every hue and dropped the override, silently,
  -- and the status line said so afterwards — true, and too late. Undo (item
  -- 2) now covers both, so the pre-flight is the cheap half of a belt and
  -- braces rather than the only recourse.
  map("X", function(armed)
    local n = vim.tbl_count(HL.overrides)
    if n == 0 then
      S.status = "no overrides to clear"
      render()
      return
    end
    if armed ~= "X" then
      S.pending = "X"
      S.status = ("X again to clear %s"):format(plural(n, "override"))
      render()
      return
    end
    checkpoint()
    local cleared = HL.clear_all_overrides()
    S.status = ("cleared %s — u to undo"):format(plural(cleared, "override"))
    render()
  end)
  map("s", function()
    local ok, err = HL.save()
    S.status = ok and ("saved to " .. HL.state_path) or ("save failed: " .. tostring(err))
    render()
  end)
  map("r", function(armed)
    local hues, chans, ovs = dirty()
    if hues + chans + ovs == 0 then
      S.status = "already the shipped palette"
      render()
      return
    end
    if armed ~= "r" then
      S.pending = "r"
      S.status = ("r again to discard %s, %s and %s"):format(
        plural(hues, "hue change"),
        plural(chans, "channel change"),
        plural(ovs, "override")
      )
      render()
      return
    end
    checkpoint()
    HL.reset()
    S.status = "restored the shipped defaults — u to undo, s to save"
    render()
  end)
  map("q", close)
  map("<Esc>", close)
end

--- Open the picker.
---
--- ITEM 11 — the bridge from "what is this token?" to the row that controls
--- it. `inspect_token` already answers the hard half: it names the winning
--- group. Before `opts.group`, the workflow was to read that name, close the
--- report, open the picker, press `G` and hunt for the name by eye among
--- sixty-odd rows.
--- @param opts { group: string|nil }|nil
function M.open(opts)
  local group = opts and opts.group
  -- MUST WORK WHEN ALREADY OPEN. The early return on `S.open` would
  -- otherwise make the bridge a no-op precisely when the picker is up, which
  -- is the likeliest state for someone comparing two groups.
  if S.open then
    if group then
      S.mode = "group"
      S.group_name = group
      S.cursor.group = 4
      S.filter = ""
      render()
      vim.api.nvim_set_current_win(S.win.controls)
    end
    return
  end
  S.open = true
  S.status = ""
  S.filter = ""
  S.pending = nil
  -- `S.compact` is deliberately NOT reset. If you folded the preview away to
  -- watch the real buffer, you meant it, and having to press `p` again after
  -- every close would make the fold a per-session chore rather than a mode.
  HL.warm() -- so GROUPS mode lists the flag variants without a Lean buffer
  if group then
    S.mode = "group"
    S.group_name = group
    S.cursor.group = 4
  else
    S.mode = "generator"
  end
  open_windows()
  keymaps()
  render()

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(S.win.controls),
    once = true,
    callback = function()
      vim.schedule(close)
    end,
  })
end

-- ═══════════════════════════════════════════════════════════════════════
-- THE COMMAND LINE
-- ═══════════════════════════════════════════════════════════════════════
--
-- WHY A `:` COMMAND AND NOT A SHELL SCRIPT. The hard requirement is that a
-- colour change is live in the RUNNING editor with no restart, which makes
-- the editor the natural host: `HL.apply` and `HL.repaint` already end in
-- `refresh_live_buffers()`, so a command gets that for free, where a shell
-- script would have to find a running instance and RPC into it — a new
-- failure mode ("which nvim?") bought for nothing, since the thing being
-- judged is on screen in that instance already. And the actual determinant
-- of speed is not the syntax but COMPLETION: there are two dozen hue keys
-- and sixty-odd group names, nobody remembers `@lean.prop.former.imported`,
-- and only the command line can offer them by <Tab>. A shell wrapper can
-- still be had for free if it is ever wanted — `nvim --server $NVIM
-- --remote-send ':LeanPalette ...<CR>'` — but it would be a second door onto
-- this one.
--
-- NO THIRD STATE LAYER. Every subcommand writes the same two layers the
-- picker writes — `HL.opts` (the generator inputs) and `HL.overrides` — and
-- persists through the same `HL.save`. `:LeanPalette source` exists so that
-- "I like this" has an obvious path to `highlights.lua`, because an override
-- that only ever lives in `lean-palette.json` is how the palette drifts from
-- its source.

--- Ladder name -> hex, so `:LeanPalette set prop_element sky` works. The
--- ladder is catppuccin mocha's own ramp; an arbitrary hex is still accepted
--- and always will be, this is the fast path and not a restriction.
local LADDER_HEX = {}
for _, e in ipairs(LADDER) do
  LADDER_HEX[e[1]] = e[2]
end

--- Attribute words, as the spec delta each one means. `no<x>` writes
--- `false` rather than deleting the key: an override saying "explicitly not
--- bold" is a real thing to want over a generated `bold = true`, and
--- deleting is what `:LeanPalette reset` is for.
local ATTR_WORDS = {
  bold = { bold = true },
  nobold = { bold = false },
  italic = { italic = true },
  noitalic = { italic = false },
  strikethrough = { strikethrough = true },
  nostrikethrough = { strikethrough = false },
  reverse = { reverse = true },
  noreverse = { reverse = false },
}

--- Generator channels, split by the shape of their value. These are the
--- INPUTS the picker's generator mode edits, reachable here by name so that
--- one keystroke still moves every variant of a thing at once.
local BOOL_CHANNELS = { former_bold = true, local_italic = true, auto_recolour = true }
local ENUM_CHANNELS = { imported_underline = true, axiom_underline = true, auto_underline = true }

local SUBCOMMANDS = { "set", "list", "reset", "save", "forget", "source", "help" }

--- What kind of thing a target name is. Order matters: a hue key wins over
--- the group reading, because `data_element` is a hue and `@lean.data.element`
--- is the group it feeds, and confusing the two would silently write an
--- override where an input was meant.
local function target_kind(name)
  if HL.opts.hues[name] ~= nil then
    return "hue"
  elseif name == "alarm" then
    return "alarm"
  elseif BOOL_CHANNELS[name] then
    return "channel_bool"
  elseif ENUM_CHANNELS[name] then
    return "channel_enum"
  end
  return "group"
end

--- A colour word: a `#rrggbb` in either case, or a ladder rung by name.
--- @return string|nil hex
local function as_colour(word)
  if type(word) ~= "string" then
    return nil
  end
  if word:match("^#%x%x%x%x%x%x$") then
    return word:lower()
  end
  return LADDER_HEX[word]
end

local function is_style(word)
  for _, s in ipairs(HL.underline_styles) do
    if s == word then
      return true
    end
  end
  return false
end

--- Turn the value words of a `set` on a GROUP into one spec delta.
--- @return table|nil delta, string|nil error
local function parse_group_values(words)
  local delta = {}
  for _, w in ipairs(words) do
    local key, rest = w:match("^(%a+)=(.+)$")
    if key and (key == "fg" or key == "bg" or key == "sp") then
      local hex = as_colour(rest)
      if not hex then
        return nil, ("not a colour: %s (want #rrggbb or a ladder name)"):format(rest)
      end
      delta[key] = hex
    elseif ATTR_WORDS[w] then
      for k, v in pairs(ATTR_WORDS[w]) do
        delta[k] = v
      end
    elseif w == "nounderline" or (is_style(w) and w == "none") then
      -- One underline per cell (B4), so "off" is "clear all five".
      for _, u in ipairs(UNDERLINES) do
        delta[u] = false
      end
    elseif is_style(w) then
      for _, u in ipairs(UNDERLINES) do
        delta[u] = false
      end
      delta[w] = true
    elseif as_colour(w) then
      delta.fg = as_colour(w)
    else
      return nil, ("do not understand %q"):format(w)
    end
  end
  if next(delta) == nil then
    return nil, "nothing to set"
  end
  return delta, nil
end

--- Merge a delta into the override for `name`, dropping the keys the delta
--- turned off, and clear the override outright if nothing is left. Keeping
--- an empty entry would make `list` claim a group is hand-set when it is not.
local function apply_group_delta(name, delta)
  local _, ov = HL.inspect_group(name)
  local spec = vim.deepcopy(ov or {})
  for k, v in pairs(delta) do
    -- An underline turned off is REMOVED rather than written as `false`:
    -- `nvim_set_hl` treats the five styles as an enum of one, so a stored
    -- `underline = false` is noise where an absent key is the answer.
    if v == false and k:match("^under") then
      spec[k] = nil
    else
      spec[k] = v
    end
  end
  if next(spec) == nil then
    HL.clear_override(name)
    return true, {}
  end
  return HL.set_override(name, spec)
end

-- ── reporting ──────────────────────────────────────────────────────────

--- Echo lines, each optionally with a swatch painted in its own colour, so
--- `list` answers "what did I set" visually and not only in hex.
--- @param rows { [1]: string, [2]: string|nil }[] text, swatch hex
local function echo(rows)
  local chunks = {}
  for _, r in ipairs(rows) do
    if r[2] then
      chunks[#chunks + 1] = { "  " .. BAR .. " ", swatch(r[2]) }
    else
      chunks[#chunks + 1] = { "      " }
    end
    chunks[#chunks + 1] = { r[1] .. "\n" }
  end
  vim.api.nvim_echo(chunks, true, {})
end

--- Everything that differs from the shipped palette, both layers. NOT every
--- hue: the question this answers is "what have I changed", and a list of
--- all twenty-four inputs buries the two that moved.
--- @param pattern string|nil a Lua pattern to filter names by
--- @return { [1]: string, [2]: string|nil }[]
function M.state_rows(pattern)
  -- `pcall`, because the filter is a Lua PATTERN and a user typing
  -- `@lean.prop.[` from the command line must get an empty list rather than
  -- an error out of `string.find`.
  local function want(name)
    if pattern == nil or pattern == "" then
      return true
    end
    local ok, at = pcall(string.find, name, pattern)
    return ok and at ~= nil
  end
  local d = HL.defaults()
  local rows, names = {}, {}
  for k in pairs(HL.opts.hues) do
    names[#names + 1] = k
  end
  table.sort(names)
  for _, k in ipairs(names) do
    if HL.opts.hues[k] ~= d.hues[k] and want(k) then
      rows[#rows + 1] = {
        ("hue     %-22s %s   was %s"):format(k, HL.opts.hues[k], d.hues[k] or "(new key)"),
        HL.opts.hues[k],
      }
    end
  end
  if HL.opts.alarm ~= d.alarm and want("alarm") then
    rows[#rows + 1] =
      { ("hue     %-22s %s   was %s"):format("alarm", HL.opts.alarm, d.alarm), HL.opts.alarm }
  end
  local chans = vim.tbl_keys(HL.opts.channels)
  table.sort(chans)
  for _, k in ipairs(chans) do
    if HL.opts.channels[k] ~= d.channels[k] and want(k) then
      rows[#rows + 1] = {
        ("channel %-22s %s   was %s"):format(k, tostring(HL.opts.channels[k]), tostring(d.channels[k])),
      }
    end
  end
  local groups = vim.tbl_keys(HL.overrides)
  table.sort(groups)
  for _, g in ipairs(groups) do
    if want(g) then
      local spec = HL.overrides[g]
      local parts = {}
      for _, k in ipairs({ "fg", "bg", "sp" }) do
        if spec[k] then
          parts[#parts + 1] = k .. "=" .. spec[k]
        end
      end
      for k, v in pairs(spec) do
        if k ~= "fg" and k ~= "bg" and k ~= "sp" then
          parts[#parts + 1] = (v and "" or "no") .. k
        end
      end
      table.sort(parts)
      rows[#rows + 1] = { ("group   %-38s %s"):format(g, table.concat(parts, " ")), spec.fg }
    end
  end
  return rows
end

-- ── the source emitter ─────────────────────────────────────────────────
-- THE POINT OF THIS, and the reason it is not a nicety: an override that
-- lives only in `stdpath("data")/lean-palette.json` is invisible from the
-- config, survives no fresh checkout, and is how the palette drifts from its
-- source. This prints the exact edit — file, line number, and the line as it
-- would read — for anything currently set.
--
-- AND IT REFUSES TO GUESS. Not every group HAS a home in `highlights.lua`;
-- the `@lsp.type.*` pins live in themes.lua, the operator and path colours
-- live in namespace_hl.lua, and a group the user invented lives nowhere at
-- all. Printing a plausible-looking `highlights.lua` edit for one of those
-- would be worse than saying so, so the last case says so.

local SRC = {
  highlights = "lua/config/lean/highlights.lua",
  themes = "lua/plugins/themes.lua",
  namespace = "lua/config/lean/namespace_hl.lua",
}

--- First line of `relpath` matching `pat`, at or after the line `after` hits.
---
--- The text comes back as `""` and not `nil` when nothing matched. Every
--- caller guards on the LINE NUMBER, and a second nillable return would make
--- each `text:gsub` after that guard a `need-check-nil` that no runtime
--- check can discharge.
--- @param relpath string relative to `stdpath("config")`
--- @param pat string a Lua pattern
--- @param after string|nil a Lua pattern; start from the line it matches
--- @return integer|nil lnum
--- @return string text
local function find_line(relpath, pat, after)
  local path = vim.fn.stdpath("config") .. "/" .. relpath
  if vim.fn.filereadable(path) ~= 1 then
    return nil, ""
  end
  local lines = vim.fn.readfile(path)
  local from = 1
  if after then
    for i, l in ipairs(lines) do
      if l:find(after) then
        from = i
        break
      end
    end
  end
  for i = from, #lines do
    if lines[i]:find(pat) then
      return i, lines[i]
    end
  end
  return nil, ""
end

--- One `key = "#hex"` edit inside a named table in highlights.lua.
local function hue_edit(key, hex, after)
  local pat = "^%s*" .. vim.pesc(key) .. "%s*="
  local lnum, text = find_line(SRC.highlights, pat, after)
  if not lnum then
    return { ("  %s — no `%s =` line found; add one to %s"):format(SRC.highlights, key, after or "?") }
  end
  return {
    ("  %s:%d"):format(SRC.highlights, lnum),
    "  - " .. text,
    "  + " .. (text:gsub('"#%x%x%x%x%x%x"', '"' .. hex .. '"', 1)),
  }
end

--- Which grid cell, if any, a generated `@lean.*` group belongs to.
---
--- THE WORLD AND LEVEL ARE CHECKED AGAINST THE REAL AXES, not merely
--- pattern-matched. `@lean.op.prop` and `@lean.path.f4` are `@lean.<word>.<word>`
--- too, and reading them as a grid cell invented a hue key `op_prop` that
--- nothing has ever defined and sent the user to the wrong file.
--- @return string|nil cell `prop_element`, string|nil hue key, boolean is_local
local GRID_WORLDS = { prop = true, data = true, poly = true }
local GRID_LEVELS = { element = true, sort = true, former = true }
local function grid_cell(group)
  local world, level, rest = group:match("^@lean%.(%a+)%.(%a+)(.*)$")
  if not world or not level or not GRID_WORLDS[world] or not GRID_LEVELS[level] then
    return nil, nil, false
  end
  local is_local = rest:find("%.local") ~= nil
  local cell = world .. "_" .. level
  local key = cell .. (is_local and "_local" or "")
  if HL.opts.hues[key] == nil then
    key = cell
  end
  return cell, key, is_local
end

--- The exact source edit for one target, as lines. Never guesses a home.
--- @param name string a hue key, a channel, or a group
--- @return string[]
function M.source_for(name)
  local kind = target_kind(name)
  local out = { name }
  if kind == "hue" then
    vim.list_extend(out, hue_edit(name, HL.opts.hues[name], "DEFAULTS = {"))
    return out
  end
  if kind == "alarm" then
    vim.list_extend(out, hue_edit("alarm", HL.opts.alarm, "DEFAULTS = {"))
    return out
  end
  if kind == "channel_bool" or kind == "channel_enum" then
    local v = HL.opts.channels[name]
    local pat = "^%s*" .. vim.pesc(name) .. "%s*="
    local lnum, text = find_line(SRC.highlights, pat, "channels = {")
    if lnum then
      out[#out + 1] = ("  %s:%d"):format(SRC.highlights, lnum)
      out[#out + 1] = "  - " .. text
      out[#out + 1] = ("  + %s%s = %s,"):format(
        text:match("^(%s*)") or "    ",
        name,
        type(v) == "string" and ('"' .. v .. '"') or tostring(v)
      )
    else
      out[#out + 1] = ("  %s — no `%s =` line in `channels`"):format(SRC.highlights, name)
    end
    return out
  end

  -- A GROUP. Everything below routes by where the group is actually defined.
  local ov = HL.overrides[name]
  if not ov then
    out[#out + 1] = "  no override set — nothing to move into source"
    return out
  end

  local cell, hue_key = grid_cell(name)
  if cell and hue_key then
    -- A grid cell: the fg belongs in `DEFAULTS.hues`, the attributes in
    -- `CELL_STYLE`. Split rather than lumped, because they are two different
    -- tables and a hue reaches every variant while a cell style does not.
    if ov.fg then
      out[#out + 1] = ("  fg  ->  DEFAULTS.hues.%s  (reaches every variant of this cell)"):format(hue_key)
      vim.list_extend(out, hue_edit(hue_key, ov.fg, "DEFAULTS = {"))
    end
    local styles = {}
    for k, v in pairs(ov) do
      if k ~= "fg" and k ~= "bg" and k ~= "sp" then
        styles[#styles + 1] = ("%s = %s"):format(k, tostring(v))
      end
    end
    if #styles > 0 then
      table.sort(styles)
      local lnum = find_line(SRC.highlights, "^%s*" .. vim.pesc(cell) .. "%s*=", "local CELL_STYLE = {")
      out[#out + 1] = ("  style -> CELL_STYLE.%s in %s%s"):format(
        cell,
        SRC.highlights,
        lnum and (":" .. lnum) or " (no entry yet — add one)"
      )
      out[#out + 1] = ("  + %s = { %s },"):format(cell, table.concat(styles, ", "))
    end
    if ov.bg or ov.sp then
      out[#out + 1] = "  bg/sp have no generator input; they are override-only on a grid cell"
    end
    return out
  end

  local file = name:match("^@lsp%.") and SRC.themes
    or (name:match("^@lean%.") or name:match("^lean%a")) and SRC.namespace
    or nil
  if file then
    local lnum, text = find_line(file, vim.pesc('["' .. name .. '"]'))
    if lnum then
      out[#out + 1] = ("  %s:%d"):format(file, lnum)
      out[#out + 1] = "  - " .. text
      local parts = {}
      for _, k in ipairs({ "fg", "bg", "sp" }) do
        if ov[k] then
          parts[#parts + 1] = ('%s = "%s"'):format(k, ov[k])
        end
      end
      for k, v in pairs(ov) do
        if k ~= "fg" and k ~= "bg" and k ~= "sp" and v then
          parts[#parts + 1] = k .. " = true"
        end
      end
      table.sort(parts)
      out[#out + 1] = ('  + ["%s"] = { %s },'):format(name, table.concat(parts, ", "))
      -- ONLY IN namespace_hl. That module paints from named palette entries
      -- (`{ fg = p.deeppink }`), so the durable edit is usually to the hue
      -- and not to the group. themes.lua has no such table, and looking for
      -- one there matched the `type` out of `@lsp.type.keyword.lean` and
      -- offered a `p.type` that does not exist.
      local pkey = file == SRC.namespace and text:match("[^%w]p%.(%w+)") or nil
      if pkey then
        -- namespace_hl paints from a named palette entry, so the durable edit
        -- is usually to the PALETTE and not to the group — and that reaches
        -- every group sharing the hue, which is the point of having one.
        local plnum, ptext = find_line(file, "^%s*" .. pkey .. "%s*=", "M.palette = {")
        out[#out + 1] = ("  ...or move the hue itself: `p.%s`%s"):format(
          pkey,
          plnum and (" at " .. file .. ":" .. plnum) or ""
        )
        if ptext and ov.fg then
          out[#out + 1] = "  - " .. ptext
          out[#out + 1] = "  + " .. (ptext:gsub('"#%x%x%x%x%x%x"', '"' .. ov.fg .. '"', 1))
        end
      end
    else
      -- The one family namespace_hl BUILDS rather than lists: module-path
      -- components are `@lean.path.c<N>` / `.f<N>`, generated in a loop off
      -- `M.palette.rainbow`, so there is no `["@lean.path.c4"]` line to find
      -- and the honest answer is the rainbow slot.
      local slot = name:match("^@lean%.path%.[cf](%d+)$")
      if slot then
        local rlnum, rtext = find_line(file, "^%s*rainbow%s*=", "M.palette = {")
        out[#out + 1] = ("  path components are generated from `M.palette.rainbow`; this is position %s"):format(slot)
        if rlnum then
          out[#out + 1] = ("  %s:%d"):format(file, rlnum)
          out[#out + 1] = "  - " .. rtext
          if ov.fg then
            local n, i = tonumber(slot), 0
            out[#out + 1] = "  + "
              .. (rtext:gsub('"#%x%x%x%x%x%x"', function(lit)
                i = i + 1
                return i == n and ('"' .. ov.fg .. '"') or lit
              end))
          end
        end
      else
        out[#out + 1] = ("  %s defines no `[\"%s\"]` entry; add one"):format(file, name)
      end
    end
    return out
  end

  -- No home. SAY SO, and print what is actually stored, rather than
  -- inventing a plausible `highlights.lua` edit for a group that does not
  -- live there.
  out[#out + 1] = "  OVERRIDE-ONLY — no source home. It lives in " .. HL.state_path .. ":"
  out[#out + 1] = ('    "%s": %s'):format(name, vim.json.encode(ov))
  return out
end

--- The source edits for everything currently set.
function M.source_all()
  local out, targets = {}, {}
  local d = HL.defaults()
  for k, v in pairs(HL.opts.hues) do
    if v ~= d.hues[k] then
      targets[#targets + 1] = k
    end
  end
  if HL.opts.alarm ~= d.alarm then
    targets[#targets + 1] = "alarm"
  end
  for k, v in pairs(HL.opts.channels) do
    if v ~= d.channels[k] then
      targets[#targets + 1] = k
    end
  end
  for g in pairs(HL.overrides) do
    targets[#targets + 1] = g
  end
  table.sort(targets)
  for _, t in ipairs(targets) do
    vim.list_extend(out, M.source_for(t))
    out[#out + 1] = ""
  end
  if #out == 0 then
    out[1] = "nothing is set — the palette is exactly what highlights.lua ships"
  end
  return out
end

-- ── dispatch ───────────────────────────────────────────────────────────

local HELP = {
  ":LeanPalette                          the picker (j/k h/l, g/G modes)",
  ":LeanPalette set <target> <value>...  a hue key, a channel, or a group",
  ":LeanPalette list [pattern]           everything that differs from shipped",
  ":LeanPalette reset <target>|all       revert one, or the lot",
  ":LeanPalette source [target]          the exact edit to put it in source",
  ":LeanPalette save                     persist both layers",
  ":LeanPalette forget                   delete the saved file",
  "",
  "TARGETS   a hue key      prop_element_local, data_sort, alarm ...",
  "          a channel      former_bold, local_italic, axiom_underline ...",
  "          a group        @lean.prop.former, @lsp.type.keyword.lean ...",
  "          <Tab> completes all three.",
  "",
  "VALUES    #ff00ff        or a catppuccin ladder name: mauve, sky, peach",
  "          fg= bg= sp=    a specific channel, same colour syntax",
  "          bold italic strikethrough reverse, and no<x> for each",
  "          underline undercurl underdouble underdotted underdashed",
  "          nounderline    clears whichever one is set (only one fits)",
  "          on off toggle  for a boolean channel",
  "",
  "  :LeanPalette set prop_element_local #ff69b4",
  "  :LeanPalette set @lean.data.former sky nobold underdotted",
  "  :LeanPalette set former_bold off",
  "  :LeanPalette source @lean.data.former",
  "",
  "Every change is live at once — no restart, no :colorscheme. It is NOT",
  "saved until `save`, and `save` does not put it in source: `source` prints",
  "that edit, because an override that only lives in the JSON is how the",
  "palette drifts away from highlights.lua.",
}

--- @return string|nil error
local function do_set(args)
  local name = args[1]
  if not name then
    return "set what? " .. SUBCOMMANDS[1] .. " <target> <value>..."
  end
  local values = vim.list_slice(args, 2)
  local kind = target_kind(name)
  if kind == "hue" or kind == "alarm" then
    local hex = as_colour(values[1] or "")
    if not hex then
      return ("%s takes a colour, got %q"):format(name, values[1] or "")
    end
    local inputs = vim.deepcopy(HL.opts)
    if kind == "alarm" then
      inputs.alarm = hex
    else
      inputs.hues[name] = hex
    end
    HL.apply(inputs)
    echo({ { ("%s = %s"):format(name, hex), hex } })
    return nil
  end
  if kind == "channel_bool" then
    local w = values[1] or "toggle"
    local v
    if w == "on" or w == "true" then
      v = true
    elseif w == "off" or w == "false" then
      v = false
    elseif w == "toggle" then
      v = not HL.opts.channels[name]
    else
      return ("%s takes on|off|toggle, got %q"):format(name, w)
    end
    local inputs = vim.deepcopy(HL.opts)
    inputs.channels[name] = v
    HL.apply(inputs)
    echo({ { ("%s = %s"):format(name, tostring(v)) } })
    return nil
  end
  if kind == "channel_enum" then
    local w = values[1] or ""
    if not is_style(w) then
      return ("%s takes %s, got %q"):format(name, table.concat(HL.underline_styles, "|"), w)
    end
    local inputs = vim.deepcopy(HL.opts)
    inputs.channels[name] = w
    HL.apply(inputs)
    echo({ { ("%s = %s"):format(name, w) } })
    return nil
  end
  local delta, err = parse_group_values(values)
  if not delta then
    return err
  end
  local ok, bad = apply_group_delta(name, delta)
  if not ok then
    return "rejected: " .. table.concat(bad or {}, ", ")
  end
  local rows = M.state_rows("^" .. vim.pesc(name) .. "$")
  echo(#rows > 0 and rows or { { name .. " — override cleared" } })
  return nil
end

--- @return string|nil error
local function do_reset(args)
  local name = args[1]
  if not name then
    return "reset what? a target, or `all`"
  end
  if name == "all" then
    HL.reset()
    echo({ { "the shipped palette is back (in memory — `save` to keep it)" } })
    return nil
  end
  local kind = target_kind(name)
  local d = HL.defaults()
  if kind == "hue" or kind == "alarm" or kind == "channel_bool" or kind == "channel_enum" then
    local inputs = vim.deepcopy(HL.opts)
    if kind == "alarm" then
      inputs.alarm = d.alarm
    elseif kind == "hue" then
      -- A key the shipped defaults never had is DELETED rather than reset:
      -- there is no shipped value to go back to, and leaving it would make
      -- "reset" a lie.
      inputs.hues[name] = d.hues[name]
    else
      inputs.channels[name] = d.channels[name]
    end
    HL.apply(inputs)
    echo({ { ("%s back to shipped"):format(name) } })
    return nil
  end
  if HL.clear_override(name) then
    echo({ { "cleared the override on " .. name } })
  else
    echo({ { "no override on " .. name } })
  end
  return nil
end

--- Everything <Tab> can offer, by argument position.
--- @return string[]
function M.complete(arglead, cmdline)
  local words = vim.split(vim.trim(cmdline), "%s+")
  -- `words[1]` is the command itself. The argument being typed is the last
  -- word when `arglead` is non-empty, and a new one when it is not.
  local n = #words - 1 + (arglead == "" and 1 or 0)
  local pool = {}
  if n <= 1 then
    pool = vim.deepcopy(SUBCOMMANDS)
  elseif n == 2 then
    local sub = words[2]
    if sub == "set" or sub == "reset" or sub == "source" or sub == "list" then
      for k in pairs(HL.opts.hues) do
        pool[#pool + 1] = k
      end
      pool[#pool + 1] = "alarm"
      for k in pairs(BOOL_CHANNELS) do
        pool[#pool + 1] = k
      end
      for k in pairs(ENUM_CHANNELS) do
        pool[#pool + 1] = k
      end
      HL.warm()
      for _, e in ipairs(HL.catalogue()) do
        pool[#pool + 1] = e.name
      end
      if sub == "reset" then
        pool[#pool + 1] = "all"
      end
    end
  elseif words[2] == "set" then
    local kind = target_kind(words[3] or "")
    if kind == "channel_bool" then
      pool = { "on", "off", "toggle" }
    elseif kind == "channel_enum" then
      pool = vim.deepcopy(HL.underline_styles)
    else
      for name in pairs(LADDER_HEX) do
        pool[#pool + 1] = name
      end
      if kind == "group" then
        for w in pairs(ATTR_WORDS) do
          pool[#pool + 1] = w
        end
        vim.list_extend(pool, UNDERLINES)
        pool[#pool + 1] = "nounderline"
        for _, p in ipairs({ "fg=", "bg=", "sp=" }) do
          pool[#pool + 1] = p
        end
      end
    end
  end
  table.sort(pool)
  return vim.tbl_filter(function(c)
    return c:sub(1, #arglead) == arglead
  end, pool)
end

--- Run one command line. Split out from the command itself so tests can
--- drive it without going through `:` parsing.
--- @param argstr string everything after `:LeanPalette`
--- @return string|nil error
function M.run(argstr)
  local args = vim.split(vim.trim(argstr or ""), "%s+", { trimempty = true })
  local sub = table.remove(args, 1)
  if not sub then
    M.open()
    return nil
  elseif sub == "help" then
    echo(vim.tbl_map(function(l)
      return { l }
    end, HELP))
  elseif sub == "set" then
    return do_set(args)
  elseif sub == "reset" then
    return do_reset(args)
  elseif sub == "list" then
    local rows = M.state_rows(args[1])
    echo(#rows > 0 and rows or { { "nothing set — the shipped palette, unmodified" } })
  elseif sub == "source" then
    local lines = args[1] and M.source_for(args[1]) or M.source_all()
    echo(vim.tbl_map(function(l)
      return { l }
    end, lines))
  elseif sub == "save" then
    local ok, err = HL.save()
    echo({ { ok and ("saved to " .. HL.state_path) or ("save failed: " .. tostring(err)) } })
  elseif sub == "forget" then
    echo({ { HL.forget() and ("deleted " .. HL.state_path) or "could not delete the saved file" } })
  else
    return ("unknown subcommand %q — try `:LeanPalette help`"):format(sub)
  end
  return nil
end

function M.setup()
  vim.api.nvim_create_user_command("LeanPalette", function(cmd)
    local err = M.run(cmd.args)
    if err then
      vim.notify("LeanPalette: " .. err, vim.log.levels.ERROR)
    end
  end, {
    nargs = "*",
    complete = M.complete,
    desc = "Lean colours: bare = picker; " .. table.concat(SUBCOMMANDS, "|"),
  })
  return M
end

-- ── test surface ───────────────────────────────────────────────────────

--- @return { [1]: string, [2]: string }[] the ladder, name and hex
function M.ladder()
  return vim.deepcopy(LADDER)
end

--- @return string what the footer is currently saying
function M._status()
  return S.status
end

--- @return table[] the resolved specimen tokens
function M._tokens()
  return TOKENS
end

--- The group each specimen token would be painted with, right now.
--- @return table<string, string> "line:col" -> group name
function M._painting()
  local out = {}
  for _, t in ipairs(TOKENS) do
    out[t.line .. ":" .. t.col] = HL.group(t.ty, t.mods) or ("@lsp.type." .. t.ty .. ".lean")
  end
  return out
end

--- @return table the raw specimen, for a test that it stays well-formed
function M._specimen()
  return SPECIMEN
end

return M
