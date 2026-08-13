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
-- KEYS
-- ─────────────────────────────────────────────────────────────────────────
--   j / k      move          h / l      adjust value under cursor
--   <Space>    toggle        <CR>       type an exact value (hex, etc.)
--   g          generator mode           G   groups mode
--   x          clear this override      X   clear every override
--   s          save (persists to stdpath("data")/lean-palette.json)
--   r          restore defaults         q / <Esc>  close
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

local function ladder_step(hex, delta)
  local idx
  for i, e in ipairs(LADDER) do
    if e[2]:lower() == tostring(hex):lower() then
      idx = i
      break
    end
  end
  if not idx then
    return LADDER[delta > 0 and 1 or #LADDER][2]
  end
  return LADDER[(idx - 1 + delta) % #LADDER + 1][2]
end

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

local function set_path(p, v)
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

local function colour_row(label, path, gloss)
  return {
    kind = "colour",
    label = label,
    gloss = gloss,
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

local function generator_rows()
  local rows = { head("HUES · which question does colour answer?") }
  -- Sorted, so the list does not reshuffle between renders when a hue is
  -- added: Lua's pairs() order is not stable across tables.
  local names = vim.tbl_keys(o().hues)
  table.sort(names)
  for _, n in ipairs(names) do
    rows[#rows + 1] = colour_row(n, { "hues", n }, HUE_GLOSS[n] or "")
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
    rows[#rows + 1] = { kind = "group", entry = e }
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

local function build_rows()
  if S.mode == "generator" then
    S.rows = generator_rows()
  elseif S.mode == "groups" then
    S.rows = groups_rows()
  else
    S.rows = group_rows()
  end
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

local BAR = "███"

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
  local function row_line(prefix, gloss, spans)
    local text = prefix
    if gloss and gloss ~= "" then
      local room = W - vim.fn.strdisplaywidth(prefix) - 1
      local cut = fit(gloss, room)
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

  for i, row in ipairs(S.rows) do
    local sel = (i == S.cursor[S.mode])
    local cur = sel and "▸ " or "  "
    local selhl = sel and "Special" or nil
    if row.kind == "head" then
      put(fit("  " .. row.text, W), { { 2, 2 + #row.text, "Title" } })
    elseif row.kind == "colour" then
      local hex = row.get()
      local prefix = ("%s%-10s %s %s %-9s"):format(cur, row.label, BAR, hex, ladder_name(hex))
      row_line(prefix, row.gloss, {
        { 0, 2, selhl },
        { 2, 12, sel and "Title" or nil },
        { 13, 13 + #BAR, swatch(hex) },
      })
    elseif row.kind == "number" then
      local v = row.get()
      local filled = math.floor(v * 16 + 0.5)
      local bar = ("▓"):rep(filled) .. ("░"):rep(16 - filled)
      local prefix = ("%s%-10s %s %.2f"):format(cur, row.label, bar, v)
      row_line(prefix, row.gloss, { { 0, 2, selhl }, { 2, 12, sel and "Title" or nil } })
    elseif row.kind == "bool" then
      local v = row.get()
      local prefix = ("%s%-18s %s"):format(cur, row.label, v and "[on] " or "[off]")
      local at = #cur + 18 + 1
      row_line(prefix, row.gloss, {
        { 0, 2, selhl },
        { 2, 20, sel and "Title" or nil },
        { at, at + 5, v and "DiagnosticOk" or "Comment" },
      })
    elseif row.kind == "enum" then
      local v = row.get()
      local prefix = ("%s%-18s %-13s"):format(cur, row.label, "[" .. v .. "]")
      local at = #cur + 18 + 1
      row_line(prefix, row.gloss, {
        { 0, 2, selhl },
        { 2, 20, sel and "Title" or nil },
        { at, at + 13, v == "none" and "Comment" or "DiagnosticOk" },
      })
    elseif row.kind == "group" then
      local e = row.entry
      local eff = eff_of(e.name)
      local hex = hexof(eff.fg)
      local mark = e.overridden and "●" or "·"
      local prefix = ("%s%s %s %s"):format(cur, mark, hex and BAR or "   ", e.name)
      put(fit(prefix, W), {
        { 0, 2, selhl },
        { 2, 2 + #mark, e.overridden and "DiagnosticWarn" or "Comment" },
        { 3 + #mark, 3 + #mark + #BAR, hex and swatch(hex) or nil },
        { 4 + #mark + #BAR, 400, sel and "Title" or nil },
      })
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
      local prefix = ("%s%-16s %s %-12s"):format(cur, row.attr, sw and BAR or "   ", val)
      row_line(prefix, ovset and "set here" or "", {
        { 0, 2, selhl },
        { 2, 18, sel and "Title" or nil },
        { 19, 19 + #BAR, sw and swatch(sw) or nil },
      })
      if ovset then
        marks[#marks + 1] = { #lines - 1, #prefix + 1, 400, "DiagnosticWarn" }
      end
    end
  end

  put("")
  if S.status ~= "" then
    put("  " .. fit(S.status, W - 2), { { 2, 400, "DiagnosticInfo" } })
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
    local target = S.cursor[S.mode] + 3
    local n = vim.api.nvim_buf_line_count(S.buf.controls)
    pcall(vim.api.nvim_win_set_cursor, win, { math.min(target, n), 0 })
  end
end

-- ── actions ────────────────────────────────────────────────────────────

local function selectable(i)
  local r = S.rows[i]
  return r and r.kind ~= "head"
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
  S.status = ""
  render()
end

--- Write one attribute of an override, preserving the rest of it.
local function patch_override(name, key, value)
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

local function adjust(delta, big)
  local row = S.rows[S.cursor[S.mode]]
  if not row then
    return
  end
  if row.kind == "colour" then
    row.set(ladder_step(row.get(), delta))
  elseif row.kind == "number" then
    local step = big and row.big or row.step
    row.set(math.max(0, math.min(1, row.get() + delta * step)))
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
    patch_override(row.entry.name, "fg", ladder_step(hexof(eff.fg) or "#cdd6f4", delta))
  elseif row.kind == "attr" then
    local name = S.group_name
    local eff = row.eff or {}
    if row.atype == "colour" then
      patch_override(name, row.attr, ladder_step(hexof(eff[row.attr]) or "#cdd6f4", delta))
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
  S.status = ""
  render()
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
    vim.ui.input({ prompt = row.label .. " hex: ", default = row.get() }, function(v)
      if v and v:match("^#%x%x%x%x%x%x$") then
        row.set(v)
      elseif v then
        S.status = "not a hex colour: " .. v
      end
      render()
    end)
    return
  end
  if row.kind == "number" then
    vim.ui.input({ prompt = row.label .. ": ", default = tostring(row.get()) }, function(v)
      local n = tonumber(v)
      if n then
        row.set(math.max(0, math.min(1, n)))
      end
      render()
    end)
    return
  end
  if row.kind == "attr" and row.atype == "colour" then
    local eff = row.eff or {}
    vim.ui.input({
      prompt = S.group_name .. " " .. row.attr .. " hex: ",
      default = hexof(eff[row.attr]) or "#",
    }, function(v)
      if v and v:match("^#%x%x%x%x%x%x$") then
        patch_override(S.group_name, row.attr, v)
      elseif v and v ~= "" then
        S.status = "not a hex colour: " .. v
      end
      render()
    end)
    return
  end
  adjust(1)
end

local function clear_one()
  local row = S.rows[S.cursor[S.mode]]
  local name = (row and row.kind == "group" and row.entry.name) or S.group_name
  if name and HL.clear_override(name) then
    S.status = "cleared override on " .. name
  else
    S.status = "no override there"
  end
  render()
end

local function close()
  S.open = false
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

local function open_windows()
  local ui_w = vim.o.columns
  local ui_h = vim.o.lines
  local total = math.min(146, ui_w - 6)
  -- The preview gets first claim on the width: it is the thing being judged,
  -- and the longest specimen line is 73 columns. The control pane shrinks to
  -- 38 before the preview gives anything up, and its descriptions are
  -- truncated to fit rather than clipped mid-word by the window edge.
  local left = math.max(38, math.min(66, total - 76))
  local right = total - left - 2
  local height = math.min(34, ui_h - 8)
  local row = math.max(1, math.floor((ui_h - height) / 2) - 1)
  local col = math.max(1, math.floor((ui_w - total) / 2))

  S.buf.controls = scratch()
  S.buf.preview = scratch()

  S.win.controls = vim.api.nvim_open_win(S.buf.controls, true, {
    relative = "editor",
    width = left,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Lean palette ",
    title_pos = "center",
    footer = " j/k move · h/l adjust · <CR> exact ",
    footer_pos = "center",
  })
  S.win.preview = vim.api.nvim_open_win(S.buf.preview, false, {
    relative = "editor",
    width = right,
    height = height,
    row = row,
    col = col + left + 2,
    style = "minimal",
    border = "rounded",
    title = " preview ",
    title_pos = "center",
    -- Split across the two footers: one help string long enough to hold
    -- every key overflows the pane and gets centre-clipped at BOTH ends,
    -- which loses keys rather than merely crowding them.
    footer = " g/G mode · x/X clear · s save · r reset · q quit ",
    footer_pos = "center",
  })

  for _, w in pairs(S.win) do
    vim.wo[w].wrap = false
    vim.wo[w].cursorline = false
  end
  -- Wrap in the preview so a narrow terminal FOLDS a long specimen line
  -- rather than hiding its tail. Extmarks travel with the text when it
  -- wraps, so a token keeps its colour either way; a clipped line would
  -- silently drop tokens from view and make the preview a partial answer.
  vim.wo[S.win.preview].wrap = true
  vim.wo[S.win.preview].linebreak = true
  -- The control list is longer than the window once the palette widens past
  -- a handful of hues. Nothing else is needed to scroll it: `render()` puts
  -- the real cursor on the selected row, so Neovim keeps it in view — and
  -- 'scrolloff' means the selection is never pinned to the last visible line.
  vim.wo[S.win.controls].scrolloff = 3
end

local function keymaps()
  local buf = S.buf.controls
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
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
    S.mode = S.mode == "group" and "groups" or S.mode
    render()
  end)
  map("x", clear_one)
  map("X", function()
    local n = HL.clear_all_overrides()
    S.status = ("cleared %d override%s"):format(n, n == 1 and "" or "s")
    render()
  end)
  map("s", function()
    local ok, err = HL.save()
    S.status = ok and ("saved to " .. HL.state_path) or ("save failed: " .. tostring(err))
    render()
  end)
  map("r", function()
    HL.reset()
    S.status = "restored the shipped defaults (not yet saved — press s)"
    render()
  end)
  map("q", close)
  map("<Esc>", close)
end

--- Open the picker.
function M.open()
  if S.open then
    return
  end
  S.open = true
  S.status = ""
  S.mode = "generator"
  HL.warm() -- so GROUPS mode lists the flag variants without a Lean buffer
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
