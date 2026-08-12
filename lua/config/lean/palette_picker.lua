-- lua/config/lean/palette_picker.lua — `:LeanPalette`, an interactive
-- chooser for the Lean semantic highlighting.
--
-- ─────────────────────────────────────────────────────────────────────────
-- WHAT IT EDITS, AND WHY THERE ARE TWO MODES
-- ─────────────────────────────────────────────────────────────────────────
-- lua/config/lean/highlights.lua does not store forty colours; it GENERATES
-- them from eleven inputs. Hue comes from the world, brightness from the
-- level, and the sort/former shades are computed by blending toward a
-- recede target so that every hue steps back by exactly the same amount.
--
--   GENERATOR mode edits those eleven inputs and regenerates. It is the
--   default because it is the mode in which the palette stays coherent: one
--   keystroke moves all three dusty shades together, and a fourth world
--   would need no new colour at all.
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
  ["@[simp] theorem"] = "a simp lemma — the underline says simp already knows it",
  ["subset_antisymm"] = "h1 and h2 are proofs; s and t beside them are not",
  ["inv_eq_of_mul"] = "the binder list the palette exists for: G, a, b, h — three worlds",
  ["mul_one"] = "cited lemmas: some are @[simp], some are not",
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
  prop = "proofs, propositions, predicates",
  data = "values, types, constructors",
  poly = "sort-polymorphic: could be either",
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
    head("THE RECEDE STEP · sort and former step back by this much"),
    colour_row("recede", { "recede" }, "what the dusty shades blend toward"),
    {
      kind = "number",
      label = "blend",
      gloss = "0 = no step back, 1 = fully receded",
      step = 0.02,
      big = 0.1,
      get = function()
        return o().dust
      end,
      set = function(v)
        set_path({ "dust" }, v)
      end,
    },
    head("ATTRIBUTE COLOURS · the underline colours"),
    colour_row("simp", { "simp_sp" }, "'the automation knows about this'"),
    colour_row("alarm", { "alarm" }, "axioms and auto-bound implicits"),
    head("CHANNELS · one question each, so they decode independently"),
    bool_row("former → bold", { "channels", "former_bold" }, "the head of a type expression"),
    bool_row("local → italic", { "channels", "local_italic" }, "bound here, not imported"),
    enum_row("simp → ", { "channels", "simp_underline" }, HL.underline_styles, "carries @[simp]"),
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

local function current_underline(eff)
  for _, u in ipairs({ "underline", "undercurl", "underdouble", "underdotted", "underdashed" }) do
    if eff[u] then
      return u
    end
  end
  return "none"
end

-- ── rendering ──────────────────────────────────────────────────────────

local BAR = "███"

local function render_controls()
  local buf = S.buf.controls
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines, marks = {}, {}
  local function put(text, spans)
    lines[#lines + 1] = text
    for _, s in ipairs(spans or {}) do
      marks[#marks + 1] = { #lines - 1, s[1], s[2], s[3] }
    end
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
    if row.kind == "head" then
      put("  " .. row.text, { { 2, 2 + #row.text, "Title" } })
    elseif row.kind == "colour" then
      local hex = row.get()
      put(("%s%-14s %s %s  %-10s %s"):format(cur, row.label, BAR, hex, ladder_name(hex), row.gloss or ""), {
        { 0, 2, sel and "Special" or "Normal" },
        { 2, 16, sel and "Title" or "Normal" },
        { 17, 17 + #BAR, swatch(hex) },
        { #cur + 15 + #BAR + 1, 200, "Comment" },
      })
    elseif row.kind == "number" then
      local v = row.get()
      local filled = math.floor(v * 20 + 0.5)
      local bar = ("▓"):rep(filled) .. ("░"):rep(20 - filled)
      put(
        ("%s%-14s %s %.2f  %s"):format(cur, row.label, bar, v, row.gloss or ""),
        { { 0, 2, sel and "Special" or "Normal" }, { 2, 16, sel and "Title" or "Normal" } }
      )
    elseif row.kind == "bool" then
      local v = row.get()
      put(("%s%-20s %s  %s"):format(cur, row.label, v and "[on] " or "[off]", row.gloss or ""), {
        { 0, 2, sel and "Special" or "Normal" },
        { 2, 22, sel and "Title" or "Normal" },
        { 23, 28, v and "DiagnosticOk" or "Comment" },
      })
    elseif row.kind == "enum" then
      local v = row.get()
      put(("%s%-20s %-13s %s"):format(cur, row.label, "[" .. v .. "]", row.gloss or ""), {
        { 0, 2, sel and "Special" or "Normal" },
        { 2, 22, sel and "Title" or "Normal" },
        { 23, 36, v == "none" and "Comment" or "DiagnosticOk" },
      })
    elseif row.kind == "group" then
      local e = row.entry
      local eff = eff_of(e.name)
      local hex = hexof(eff.fg)
      local mark = e.overridden and "●" or "·"
      put(("%s%s %s %-44s"):format(cur, mark, hex and BAR or "   ", e.name), {
        { 0, 2, sel and "Special" or "Normal" },
        { 2, 3, e.overridden and "DiagnosticWarn" or "Comment" },
        { 4, 4 + #BAR, hex and swatch(hex) or "Comment" },
        { 4 + #BAR + 1, 200, sel and "Title" or "Normal" },
      })
    elseif row.kind == "attr" then
      local eff = row.eff or {}
      local ovset = row.ov
        and (
          row.attr == "underline style"
            and (function()
              for _, u in ipairs({ "underline", "undercurl", "underdouble", "underdotted", "underdashed" }) do
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
      put(("%s%-16s %s %-12s %s"):format(cur, row.attr, sw and BAR or "   ", val, ovset and "set here" or ""), {
        { 0, 2, sel and "Special" or "Normal" },
        { 2, 18, sel and "Title" or "Normal" },
        { 19, 19 + #BAR, sw and swatch(sw) or "Comment" },
        { 19 + #BAR + 14, 200, "DiagnosticWarn" },
      })
    end
  end

  put("")
  if S.status ~= "" then
    put("  " .. S.status, { { 2, 200, "DiagnosticInfo" } })
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
    for _, u in ipairs({ "underline", "undercurl", "underdouble", "underdotted", "underdashed" }) do
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
  local left = math.min(62, math.floor(total * 0.44))
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
    footer = " j/k move  h/l adjust  <CR> exact  g generator  G groups" .. "  x/X clear  s save  r reset  q quit ",
    footer_pos = "center",
  })

  for _, w in pairs(S.win) do
    vim.wo[w].wrap = false
    vim.wo[w].cursorline = false
  end
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

function M.setup()
  vim.api.nvim_create_user_command("LeanPalette", function()
    M.open()
  end, { desc = "Choose the Lean semantic highlight colours" })
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
