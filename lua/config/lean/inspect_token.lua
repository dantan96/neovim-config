-- lua/config/lean/inspect_token.lua — <leader>K: why is this token that colour?
--
-- ─────────────────────────────────────────────────────────────────────────
-- THE QUESTION THIS ANSWERS
-- ─────────────────────────────────────────────────────────────────────────
-- A Lean identifier on this machine is classified along five axes at once by
-- the patched server (see docs/lean-highlighting/NAMES.md in
-- ~/ClaudeProjects/leanSetup), turned into TEN highlight groups by Neovim and
-- one more by lua/config/lean/highlights.lua, and then rendered as a single
-- screen cell whose attributes are the COMPOSITION of all eleven. Every step
-- of that is invisible, and three of them are actively counter-intuitive:
--
--   * a group can exist, be listed by `:Inspect`, and contribute NOTHING,
--     because it is undefined — which lets a lower layer show through. That
--     is why `theorem` was accidentally blue for a while: nobody defined
--     `@lsp.type.theorem.lean`, so the syntax file's `leanConstant` won;
--   * priority is not the order the groups are listed in and not the order
--     they were created in. Neovim lays down its own three marks at 125 /
--     126 / 127 and highlights.lua synthesises one at 128, so the LAST thing
--     you would guess — a group nothing in the theme mentions — is the one
--     that decides the colour;
--   * the rendered cell is NOT the winning group's definition. Attributes
--     merge: a bold from priority 50 survives a foreground from priority 128
--     if 128 does not mention bold. `:Inspect` shows the stack, `nvim_get_hl`
--     shows a definition, and neither shows what was drawn.
--
-- So this module reports four things, in this order, and keeps them apart:
--   1. what the SERVER said, in its own vocabulary and in English;
--   2. every group that APPLIES here, in priority order, with the winner
--      marked and each group's resolved appearance beside it;
--   3. the cell that was actually DRAWN, read back off the screen grid;
--   4. an attribute-by-attribute attribution of that cell to the groups that
--      supplied each attribute, plus a diff against a simulation of the
--      merge, so a disagreement is visible rather than assumed away.
--
-- ─────────────────────────────────────────────────────────────────────────
-- ORDER OF OPERATIONS, WHICH IS LOAD-BEARING
-- ─────────────────────────────────────────────────────────────────────────
-- Everything that reads screen state must run BEFORE the float exists:
--   * the float is drawn over the token, so `nvim__inspect_cell` at the
--     token's screen position would read the FLOAT's cells;
--   * opening it moves the cursor out of the source window, which drops
--     'cursorline' and lets CursorMoved clear the document-highlight marks.
-- M.report() therefore samples everything and M.open() only formats. Nothing
-- below the `-- ── the float ──` divider touches the source window.
--
-- And, unlike docs/lean-highlighting/tools/hl_cells.lua, this does NOT run
-- `:only` to dodge GOTCHAS A8. A8 is about `screenpos()` being asked for a
-- position in the wrong grid; passing the window explicitly — the one the
-- keymap fired in — is the fix, and it does not destroy the user's layout.

local M = {}

-- ── vocabulary ─────────────────────────────────────────────────────────
-- One gloss per name in the server's legend, which is 29 token types and 31
-- modifiers (read off the wire, `:LeanRichTokens status`). Types and
-- modifiers are separate namespaces and one name — `local`, say — could
-- perfectly well appear in both, so they are separate tables rather than one.
--
-- The glosses for names NAMES.md maps no Lean thing onto say exactly that,
-- rather than being omitted: "no gloss" and "nothing maps to it" look
-- identical in the display otherwise, and only one of them is a gap in this
-- file. tests/test_lean.lua requires every legend name to be present here.

--- Standard LSP names that are in the legend for other clients' benefit and
--- that NAMES.md maps nothing onto. Kept as its own list so the test can tell
--- "deliberately unmapped" from "forgotten".
M.UNMAPPED_NOTE = "in the legend for compatibility; NAMES.md maps no Lean thing onto it"

M.TYPE_GLOSS = {
  -- emitted, and mapped in NAMES.md
  keyword = "Lean's own syntax — not a name you can look up",
  variable = "any local: a binder, a `let`, a tactic-introduced name",
  ["function"] = "a `def`",
  property = "a structure projection",
  struct = "a `structure`",
  class = "a `class`",
  enum = "an `inductive`",
  enumMember = "a constructor",
  typeParameter = "a locally bound type, as in `{α : Type*}`",
  type = "a type from the environment",
  namespace = "a namespace",
  theorem = "a `theorem` or `lemma` (custom name; not standard LSP)",
  axiom = "an `axiom` — asserted, never proved (custom name)",
  opaque = "an `opaque` — the body is deliberately unavailable (custom name)",
  recursor = "a recursor, `T.rec` (custom name)",
  tactic = "the head atom of a tactic step (custom name)",
  leanSorryLike = "`sorry` / `admit` / `stop` / `#exit` — a hole (upstream's name)",
  -- standard LSP names nothing here maps onto
  interface = M.UNMAPPED_NOTE,
  parameter = "standard LSP `parameter`; Lean sends every local as `variable`",
  event = M.UNMAPPED_NOTE,
  method = M.UNMAPPED_NOTE,
  macro = M.UNMAPPED_NOTE,
  modifier = M.UNMAPPED_NOTE,
  decorator = M.UNMAPPED_NOTE,
  comment = "standard LSP `comment`; here the syntax file colours comments",
  string = "standard LSP `string`; here the syntax file colours strings",
  number = "standard LSP `number`; here the syntax file colours numerals",
  regexp = M.UNMAPPED_NOTE,
  operator = M.UNMAPPED_NOTE,
}

--- The seven standard LSP modifiers NAMES.md says are kept for legend
--- compatibility and never set. Named individually rather than derived,
--- because the display uses this: a token that actually CARRIES one of these
--- is flagged loudly, since it means the server's vocabulary changed and
--- every gloss in this file was written against the old one. Pinned against
--- the legend and against the glosses in tests/test_lean.lua.
M.MOD_NEVER_SET = {
  definition = true,
  readonly = true,
  static = true,
  abstract = true,
  async = true,
  modification = true,
  documentation = true,
}

local NEVER = "standard LSP modifier, kept for legend compatibility; never set by this server"

M.MOD_GLOSS = {
  -- universe — mutually exclusive, one per classified token
  propWorld = "`Prop`, i.e. `Sort 0` — the world of proofs and propositions",
  dataWorld = "some `Type u`, i.e. `Sort (u+1)` — the world of data",
  polyWorld = "sort-polymorphic: `Sort u` with `u` a level parameter, so genuinely undetermined",
  -- level — mutually exclusive, one per classified token
  element = "a term OF a type — a proof, or a datum",
  sort = "a term that IS a type or a proposition (`Meta.isType`)",
  former = "a function producing types — `Eq`, `Set`, `List` (`isTypeFormerType`)",
  -- binder: explicit is the absence of all three
  implicit = "bound by `{x}` — Lean infers it",
  strictImplicit = "bound by `⦃x⦄` — inferred, but only once a later explicit argument appears",
  instBinder = "an instance binder, `[Inst α]` — found by instance search",
  -- flags
  ["local"] = "bound here — a binder, a `let`, a tactic name — not from the environment",
  autoImplicit = "the ELABORATOR bound this name; you did not write the binder",
  simp = "`@[simp]` — `simp` knows this one",
  instance = "registered as an instance",
  reducible = "`@[reducible]` — unfolds freely",
  irreducible = "`@[irreducible]` — `simp` and `rw` will NOT unfold it",
  private = "`private` — not visible outside this module",
  protected = "`protected` — needs its full name even when the namespace is open",
  noncomputable = "`noncomputable` — no code is generated for it",
  matchPattern = "occurring as a pattern in a `match`",
  elabWithoutExpectedType = "elaborated with no expected type propagated in",
  abbrev = "`abbrev` — a `@[reducible] def`",
  -- standard LSP modifiers this server does use
  declaration = "the binding occurrence — this is where the name is introduced",
  deprecated = "`@[deprecated]` — Mathlib has moved on from this name",
  defaultLibrary = "imported — it came from the library, not from this file",
  -- ...and the seven it never sets
  definition = NEVER,
  readonly = NEVER,
  static = NEVER,
  abstract = NEVER,
  async = NEVER,
  modification = NEVER,
  documentation = NEVER,
}

-- ── English ────────────────────────────────────────────────────────────
-- The point of the whole tool: `propWorld` + `element` + `local` must also
-- read as "a hypothesis". The grid below is NAMES.md's world × level table
-- turned into prose; the headline table above it names the handful of cells
-- that have an ordinary English name of their own.

M.WORLDS = { propWorld = true, dataWorld = true, polyWorld = true }
M.LEVELS = { element = true, sort = true, former = true }

--- The predicate half of the sentence only. The subject — "a local" or "a
--- term" — is supplied by M.sentence from the `local` flag, so that
--- propWorld + element + local reads as NAMES.md's own gloss, "a local whose
--- type is a proposition", rather than as a generic phrase with a locality
--- footnote after it.
M.GRID = {
  propWorld = {
    element = "whose type is a proposition — so it is a proof",
    sort = "that IS a proposition",
    former = "that is a predicate: a function producing propositions",
  },
  dataWorld = {
    element = "whose type is some `Type u` — so it is a datum",
    sort = "that IS a type",
    former = "that is a type family: a function producing types",
  },
  polyWorld = {
    element = "whose type is sort-polymorphic (`Sort u`, `u` a level parameter)",
    sort = "that IS a sort-polymorphic type — it could be a `Prop` or a `Type`",
    former = "that is a sort-polymorphic type former",
  },
}

--- Display order for modifiers: NAMES.md's own categories, not alphabetical.
--- The two axes every classified token carries exactly one of come first,
--- because they are the ones that decide the colour; the seven standard
--- modifiers this server never sets come last, if they ever appear at all.
M.MOD_ORDER = {}
for i, m in ipairs({
  -- universe
  "propWorld", "dataWorld", "polyWorld",
  -- level
  "element", "sort", "former",
  -- binder
  "implicit", "strictImplicit", "instBinder",
  -- flags
  "local", "autoImplicit", "simp", "instance", "reducible", "irreducible",
  "private", "protected", "noncomputable", "matchPattern",
  "elabWithoutExpectedType", "abbrev",
  -- standard LSP, used
  "declaration", "deprecated", "defaultLibrary",
  -- standard LSP, never set
  "definition", "readonly", "static", "abstract", "async", "modification",
  "documentation",
}) do
  M.MOD_ORDER[m] = i
end

--- Sort a modifier set into M.MOD_ORDER, with anything unknown last and
--- alphabetical among itself — a new modifier must still appear, in a stable
--- place, rather than vanish or reorder the rest.
---@param mods table<string, boolean>|nil
---@return string[]
function M.sorted_mods(mods)
  local names = {}
  for m, on in pairs(mods or {}) do
    if on then
      names[#names + 1] = m
    end
  end
  table.sort(names, function(a, b)
    local oa, ob = M.MOD_ORDER[a] or math.huge, M.MOD_ORDER[b] or math.huge
    if oa ~= ob then
      return oa < ob
    end
    return a < b
  end)
  return names
end

--- Kind nouns, for the headline. Only where the token type has a shorter
--- English name than the type itself.
local KIND = {
  variable = "local",
  ["function"] = "definition",
  theorem = "theorem",
  axiom = "axiom",
  opaque = "opaque constant",
  recursor = "recursor",
  enum = "inductive type",
  struct = "structure",
  class = "class",
  enumMember = "constructor",
  property = "projection",
  typeParameter = "type variable",
  type = "type",
  namespace = "namespace",
  tactic = "tactic",
  keyword = "keyword",
  leanSorryLike = "hole (`sorry` and friends)",
}

--- Clauses added for flags that change what the name MEANS, as opposed to
--- flags that only change how it is drawn. Ordered, so the sentence is a
--- function of the modifier set and not of table iteration order.
local CLAUSES = {
  { "declaration", "this is its binding occurrence, not a use of it" },
  { "defaultLibrary", "imported from the library, not proved in this file" },
  { "simp", "`simp` knows it" },
  { "instance", "registered as an instance" },
  { "instBinder", "found by instance search, not passed by you" },
  { "implicit", "implicit: Lean infers it" },
  { "strictImplicit", "strict-implicit: inferred only once a later explicit argument appears" },
  { "autoImplicit", "and the ELABORATOR bound the name — you did not write the binder" },
  { "irreducible", "`simp` and `rw` will not unfold it" },
  { "reducible", "it unfolds freely" },
  { "abbrev", "an `abbrev`" },
  { "private", "private to this module" },
  { "protected", "protected" },
  { "noncomputable", "noncomputable" },
  { "deprecated", "DEPRECATED" },
  { "matchPattern", "here it is a match pattern" },
  { "elabWithoutExpectedType", "elaborated without an expected type" },
}

--- Turn one (token type, modifier set) into English.
---
--- Deliberately total: an unknown type or an empty modifier set produces a
--- sentence that says what is missing rather than nothing at all, because a
--- blank line here is indistinguishable from a bug.
---@param ty string|nil token type
---@param mods table<string, boolean>|nil modifier set
---@return { headline: string, detail: string|nil, clauses: string[] }
function M.sentence(ty, mods)
  mods = mods or {}
  local world, level
  for m in pairs(mods) do
    if M.WORLDS[m] then
      world = m
    elseif M.LEVELS[m] then
      level = m
    end
  end

  -- The named cells. NAMES.md's own examples: a hypothesis is
  -- `variable` + propWorld + element + local, a type variable is a local at
  -- the `sort` level whatever its world.
  local head
  if ty == "leanSorryLike" then
    head = "a hole"
  elseif ty == "tactic" then
    head = "a tactic"
  elseif ty == "keyword" then
    head = "a keyword"
  elseif mods["local"] and level == "element" and world == "propWorld" then
    head = "a hypothesis"
  elseif mods["local"] and level == "element" and world == "dataWorld" then
    head = "a data local"
  elseif mods["local"] and level == "sort" then
    head = "a type variable"
  elseif mods["local"] and level == "former" then
    head = "a locally bound type former"
  elseif mods["local"] then
    head = "a local"
  elseif KIND[ty] then
    head = (KIND[ty]:match("^[aeiou]") and "an " or "a ") .. KIND[ty]
  elseif ty then
    head = "a `" .. ty .. "` token"
  else
    head = "no semantic token here"
  end

  local detail
  if world and level then
    detail = (mods["local"] and "a local " or "a term ") .. M.GRID[world][level]
  elseif world then
    detail = "in the "
      .. world
      .. ", but the server sent no level (element / sort / former)"
  elseif level then
    detail = "at level `" .. level .. "`, but the server sent no world"
  elseif ty then
    detail = "the server sent no world/level classification for this token"
  end

  local clauses = {}
  for _, c in ipairs(CLAUSES) do
    if mods[c[1]] then
      clauses[#clauses + 1] = c[2]
    end
  end
  return { headline = head, detail = detail, clauses = clauses }
end

-- ── highlight-group resolution ─────────────────────────────────────────

--- Attribute bits that OR together across the stack (M4/B4: bold, italic and
--- strikethrough all stack freely). Underline styles do NOT — see below.
local BOOLS = {
  "bold",
  "italic",
  "strikethrough",
  "reverse",
  "standout",
  "nocombine",
  "altfont",
}

--- The 3-bit underline enum (GOTCHAS B4). Exactly one of these can be on in a
--- cell, so a higher-priority group setting any of them REPLACES whatever the
--- stack had, rather than adding to it. `sp` is a separate colour slot and
--- survives independently, which is how a stray coloured underline appears
--- from a group whose style lost.
local UNDERLINES = {
  "underline",
  "undercurl",
  "underdouble",
  "underdotted",
  "underdashed",
}
local function hex(n)
  return n and string.format("#%06x", n) or nil
end

--- What a group actually resolves to, following links to the end.
---
--- GOTCHAS A4: `nvim_get_hl` returns an empty table for an undefined group,
--- for a cleared group and for a misspelt one alike, so `defined` here means
--- "resolves to at least one attribute" and nothing stronger. That is the
--- property that matters for rendering — an empty group contributes nothing
--- whichever of the three it is — but it is not the same as "the name exists".
---@param name string
---@return { attrs: table, defined: boolean }
function M.resolve(name)
  local ok, attrs = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
  if not ok or type(attrs) ~= "table" then
    attrs = {}
  end
  -- `cterm` is a sub-table and is not an attribute of the rendered truecolour
  -- cell; counting it would make a cterm-only group look defined.
  local n = 0
  for k in pairs(attrs) do
    if k ~= "cterm" then
      n = n + 1
    end
  end
  return { attrs = attrs, defined = n > 0 }
end

--- A one-line description of a resolved group, for the table.
---@param layer table
---@return string
function M.describe(layer)
  if not layer.defined then
    return "(undefined — contributes nothing; lower layers show through)"
  end
  local a = layer.attrs
  local parts = {}
  if layer.link and layer.link ~= layer.group then
    parts[#parts + 1] = "→ " .. layer.link
  end
  if a.fg then
    parts[#parts + 1] = "fg " .. hex(a.fg)
  end
  if a.bg then
    parts[#parts + 1] = "bg " .. hex(a.bg)
  end
  if a.sp then
    parts[#parts + 1] = "sp " .. hex(a.sp)
  end
  for _, k in ipairs(BOOLS) do
    if a[k] then
      parts[#parts + 1] = k
    end
  end
  for _, k in ipairs(UNDERLINES) do
    if a[k] then
      parts[#parts + 1] = k
    end
  end
  return table.concat(parts, "  ")
end

-- ── the merge ──────────────────────────────────────────────────────────

--- Simulate Neovim's attribute composition over a priority-ascending stack.
---
--- The rules, which are the whole point of section 4 of the display:
---   * fg / bg / sp are REPLACED by any higher layer that sets them;
---   * bold / italic / strikethrough and friends are OR-ed, so a lower layer's
---     bold survives a higher layer that says nothing about bold;
---   * the underline STYLE is a single slot and is replaced, `sp` is not.
---
--- This is a simulation and is presented as one: M.report() reads the real
--- cell as well and the display diffs them, so a wrong rule here shows up as
--- a disagreement rather than as a confident wrong answer.
---@param layers table[] priority-ASCENDING
---@return table<string, { value: any, group: string, priority: integer, also: integer }>
function M.compose(layers)
  local acc = {}
  local function set(k, value, layer)
    acc[k] = { value = value, group = layer.group, priority = layer.priority, also = 0 }
  end
  for _, L in ipairs(layers) do
    if L.defined then
      local a = L.attrs
      for _, k in ipairs({ "fg", "bg", "sp" }) do
        if a[k] then
          set(k, hex(a[k]), L)
        end
      end
      for _, k in ipairs(BOOLS) do
        if a[k] then
          if acc[k] then
            -- OR semantics: it was already on. Record that this layer would
            -- also have set it, and credit the higher one, which is the
            -- answer a reader expects — but say how many agreed.
            local also = acc[k].also + 1
            set(k, true, L)
            acc[k].also = also
          else
            set(k, true, L)
          end
        end
      end
      for _, k in ipairs(UNDERLINES) do
        if a[k] then
          -- One slot: drop whatever style was there.
          for _, u in ipairs(UNDERLINES) do
            acc[u] = nil
          end
          set(k, true, L)
          break
        end
      end
    end
  end
  return acc
end

-- ── gathering ──────────────────────────────────────────────────────────

--- Read the composed attributes of the rendered screen cell at a buffer
--- position, or say why that could not be done.
---
--- Three honest failures, all of which would otherwise be a plausible-looking
--- wrong reading:
---   * the position is not on screen at all (scrolled away, or inside a
---     closed fold) — `screenpos()` returns row 0;
---   * the character at the screen cell is not the character in the buffer,
---     which means something inline shifted the column. Inlay hints are ON by
---     default in this config (after/ftplugin/lean.lua) and are inline
---     virtual text, so this is a live risk and not a theoretical one;
---   * `nvim__inspect_cell` is an internal API and may simply not be there.
---@param win integer window handle — NOT window 0. GOTCHAS A8: the infoview
---            is a window over a different grid and `screenpos` in it is
---            garbage that looks fine.
---@param row integer 0-based
---@param col integer 0-based byte column
---@param want string|nil the character the buffer has at (row, col)
---@return { char: string, attrs: table }|nil, string|nil reason
function M.cell(win, row, col, want)
  if not vim.api.nvim_win_is_valid(win) then
    return nil, "the window the cursor was in is gone"
  end
  local sp = vim.fn.screenpos(win, row + 1, col + 1)
  if not sp or sp.row == 0 then
    return nil,
      "not on screen — scrolled out of the drawn viewport, or inside a closed fold. "
        .. "The semantic-token highlighter only marks what is drawn (GOTCHAS A1)."
  end
  if not vim.api.nvim__inspect_cell then
    return nil, "this Neovim has no nvim__inspect_cell"
  end
  local ok, res = pcall(vim.api.nvim__inspect_cell, 1, sp.row - 1, sp.col - 1)
  if not ok or type(res) ~= "table" then
    return nil, "nvim__inspect_cell failed: " .. tostring(res)
  end
  local ch = res[1]
  if want and want ~= "" and ch ~= want then
    return nil,
      ("the screen cell at that column holds %q, but the buffer holds %q — inline "):format(
        tostring(ch),
        want
      )
        .. "virtual text (inlay hints are on by default here), a conceal or a tab "
        .. "shifted the column, so this reading would be of the wrong cell."
  end
  return { char = ch, attrs = res[2] or {} }, nil
end

--- Everything the display needs, sampled from the live screen.
---
--- MUST be called before any float is opened — see the header. Everything
--- here is a read; nothing in this function changes editor state.
---@param win integer|nil defaults to the current window
---@param bufnr integer|nil defaults to that window's buffer
---@param row integer|nil 0-based; defaults to the cursor
---@param col integer|nil 0-based byte column; defaults to the cursor
---@return table
function M.report(win, bufnr, row, col)
  win = win or vim.api.nvim_get_current_win()
  bufnr = bufnr or vim.api.nvim_win_get_buf(win)
  if row == nil or col == nil then
    local c = vim.api.nvim_win_get_cursor(win)
    row, col = c[1] - 1, c[2]
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local char = vim.fn.strcharpart(line:sub(col + 1), 0, 1)
  local R = {
    win = win,
    buf = bufnr,
    row = row,
    col = col,
    line = line,
    char = char,
    -- Whitespace and end-of-line are not errors; they are the commonest way
    -- to press this key by accident and must read as an answer.
    on_blank = char == "" or char:match("^%s$") ~= nil,
    filetype = vim.bo[bufnr].filetype,
  }

  -- ── the server ───────────────────────────────────────────────────────
  local rich = require("config.lean.rich_tokens")
  local clients = vim.lsp.get_clients({ bufnr = bufnr, name = rich.SERVER })
  R.clients = {}
  for _, c in ipairs(clients) do
    local legend = rich.legend(c)
    R.clients[#R.clients + 1] = {
      id = c.id,
      rich = rich.legend_is_rich(c),
      n_types = legend and legend.tokenTypes and #legend.tokenTypes or nil,
      n_mods = legend and legend.tokenModifiers and #legend.tokenModifiers or nil,
    }
  end
  R.attached = #clients > 0
  -- THREE DIFFERENT FACTS, and rich_tokens.lua's own status command exists
  -- because they disagree. Keeping them separate here is not pedantry: on the
  -- patched toolchain with `vim.g.lean_rich_tokens = false`, `enabled()` is
  -- false while the legend is still rich and the rich tokens still arrive
  -- (this server build does not gate its legend on the capability — measured,
  -- see that file). Reporting "this legend has no propWorld" there would be
  -- flatly untrue, and it is the one sentence in this display a user would
  -- take at face value.
  --
  --   legend_rich  what the SERVER sent. nil when no client answered.
  --   mode_rich    whether rich client behaviour RUNS, which a forced-off
  --                setting turns off regardless of the legend.
  R.legend_rich = nil
  for _, c in ipairs(R.clients) do
    if c.rich == true then
      R.legend_rich = true
    elseif c.rich == false and R.legend_rich == nil then
      R.legend_rich = false
    end
  end
  R.mode_rich = rich.enabled(bufnr)
  R.forced = rich.override()

  -- ── the token ────────────────────────────────────────────────────────
  -- nil and {} are DIFFERENT answers and the display keeps them apart: nil
  -- means the semantic-token highlighter is not running on this buffer at
  -- all, {} means it is and nothing covers this position.
  --
  -- The tokens `get_at_pos` hands back are LIVE REFERENCES into the
  -- highlighter's own `current_result.highlights` (it assigns `client_id`
  -- onto them in place). Copy before touching anything, or a sort here is a
  -- corrupted highlight cache somewhere else.
  local raw = vim.lsp.semantic_tokens.get_at_pos(bufnr, row, col)
  R.highlighter_running = raw ~= nil
  R.tokens = raw and vim.deepcopy(raw) or {}

  -- The token's own extent, so the header names `mul_one` rather than the
  -- single character `m` the cursor happens to be sitting on. The cell read
  -- further down is still of that one character — a cell is one character —
  -- and the header says both, because conflating them is how you end up
  -- reporting the colour of a token's first letter as the token's colour.
  local t = R.tokens[1]
  if t then
    local tl = vim.api.nvim_buf_get_lines(bufnr, t.line, t.line + 1, false)[1] or ""
    R.token_text = tl:sub(t.start_col + 1, t.end_col)
  end

  -- ── the stack ────────────────────────────────────────────────────────
  local info = vim.inspect_pos(bufnr, row, col)
  local layers = {}
  local function add(kind, group, link, priority, note)
    if not group then
      return
    end
    local r = M.resolve(group)
    layers[#layers + 1] = {
      kind = kind,
      group = group,
      link = link,
      priority = priority,
      note = note,
      attrs = r.attrs,
      defined = r.defined,
      seq = #layers, -- traversal order, for stable tie reporting
    }
  end

  -- 'cursorline' is not an extmark and `vim.inspect_pos` cannot see it, but
  -- <leader>K is pressed with the cursor ON the token by construction, so it
  -- is applied to the cell being read. It composes underneath everything, so
  -- it goes in at the bottom — otherwise the simulation predicts no
  -- background and the real cell has one, and the diff blames a mystery.
  --
  -- 'cursorlineopt' is a comma list whose DEFAULT is "both", so a `:find`
  -- for "line" misses the default outright — and the default is the only
  -- case this block exists for. Matched by element instead: "line",
  -- "screenline" and "both" all paint the line; a bare "number" paints only
  -- the number column and must not count.
  local function paints_line()
    for _, o in ipairs(vim.split(vim.wo[win].cursorlineopt, ",", { trimempty = true })) do
      if o == "line" or o == "screenline" or o == "both" then
        return true
      end
    end
    return false
  end
  if
    vim.wo[win].cursorline
    and vim.api.nvim_win_get_cursor(win)[1] - 1 == row
    and paints_line()
  then
    add("window", "CursorLine", nil, -1, "the cursor's line, drawn under everything")
  end

  -- The `:syntax` layer is not an extmark at all: it is the base the extmarks
  -- compose over. `vim.hl.priorities.syntax` (50) is the convention Neovim
  -- publishes for "about here", and is shown as such rather than as a fact
  -- about a mark that does not exist. synstack() is outermost-first.
  for _, s in ipairs(info.syntax or {}) do
    add("syntax", s.hl_group, s.hl_group_link, vim.hl.priorities.syntax)
  end
  -- `ts`, not `t`: `t` is already bound in this function to the token under
  -- the cursor, and shadowing it here would make the two impossible to tell
  -- apart at a glance in exactly the place they are both in scope.
  for _, ts in ipairs(info.treesitter or {}) do
    add(
      "treesitter",
      ts.hl_group,
      ts.hl_group_link,
      (ts.metadata and ts.metadata.priority) or vim.hl.priorities.treesitter
    )
  end
  for _, s in ipairs(info.semantic_tokens or {}) do
    add("semantic", s.opts.hl_group, s.opts.hl_group_link, s.opts.priority or 0)
  end
  -- Everything else with a highlight: lean.nvim's goal markers, document
  -- highlight's LspReferenceText (which sits under the cursor BY DESIGN — see
  -- lua/config/lean/document_highlight.lua — and is the single likeliest
  -- source of a background nothing in the theme explains), diagnostics.
  for _, e in ipairs(info.extmarks or {}) do
    if e.opts and e.opts.hl_group then
      add(
        "extmark",
        e.opts.hl_group,
        e.opts.hl_group_link,
        e.opts.priority or 4096,
        e.ns ~= "" and e.ns or nil
      )
    end
  end

  -- Priority-ascending for the merge; the display re-sorts descending.
  table.sort(layers, function(a, b)
    if a.priority ~= b.priority then
      return a.priority < b.priority
    end
    return a.seq < b.seq
  end)
  R.layers = layers
  R.composed = M.compose(layers)

  -- The winner: the highest-priority layer that resolves to anything. Ties
  -- are reported rather than resolved — `vim.inspect_pos` does not expose the
  -- order Neovim would break them in, and inventing one would be the exact
  -- kind of confident wrong answer this tool exists to prevent.
  local winner, ties = nil, 0
  for _, L in ipairs(layers) do
    if L.defined then
      if not winner or L.priority > winner.priority then
        winner, ties = L, 0
      elseif L.priority == winner.priority then
        ties = ties + 1
      end
    end
  end
  R.winner = winner
  R.winner_ties = ties

  -- ── what was drawn ───────────────────────────────────────────────────
  R.cell, R.cell_error = M.cell(win, row, col, R.on_blank and nil or char)

  return R
end

-- ── formatting ─────────────────────────────────────────────────────────

local WIDTH = 96

local function rule(title)
  local head = "── " .. title .. " "
  return head .. string.rep("─", math.max(0, WIDTH - vim.fn.strdisplaywidth(head)))
end

--- Build the float's contents.
---
--- Returns lines plus the extmarks needed to paint each group's NAME in that
--- group's own colours. That is not decoration: a group with no definition
--- then renders as plain text, which is precisely what it does to the buffer,
--- and the difference between "blue" and "the theme's idea of blue" stops
--- being a hex code you have to imagine.
---@param R table from M.report()
---@return string[] lines, table[] marks  { row (0-based), col, end_col, group }
function M.render(R)
  local lines, marks = {}, {}
  local function put(s)
    lines[#lines + 1] = s or ""
    return #lines - 1 -- 0-based row of what was just added
  end
  --- One blank line, never two. The number of paragraphs above any given
  --- point varies with how much the server had to say, so the separators
  --- cannot be placed statically without either doubling or vanishing.
  local function gap()
    if #lines > 0 and lines[#lines] ~= "" then
      put()
    end
  end
  --- Add a line and paint a substring of it in `group`.
  local function put_hl(s, group, from, to)
    local r = put(s)
    if group then
      marks[#marks + 1] = { row = r, col = from, end_col = to, group = group }
    end
    return r
  end

  -- ── header ───────────────────────────────────────────────────────────
  local where = ("line %d, col %d   (buffer %d, %s)"):format(
    R.row + 1,
    R.col + 1,
    R.buf,
    R.filetype ~= "" and R.filetype or "no filetype"
  )
  if R.on_blank then
    put(("whitespace or end of line — %s"):format(where))
  elseif R.token_text and R.token_text ~= R.char then
    put(("`%s`   (cursor on `%s`)   %s"):format(R.token_text, R.char, where))
  else
    put(("`%s`   %s"):format(R.char, where))
  end
  put(vim.trim(R.line):sub(1, WIDTH))
  put()

  -- ── 1 · the server ───────────────────────────────────────────────────
  put(rule("1 · WHAT THE SERVER SAID"))
  put()
  for _, c in ipairs(R.clients) do
    put(
      ("  client %d   legend: %s (%s types, %s modifiers)"):format(
        c.id,
        c.rich and "RICH — the patched toolchain" or "standard — a stock toolchain",
        tostring(c.n_types),
        tostring(c.n_mods)
      )
    )
  end
  if #R.clients > 0 then
    gap()
  end
  if not R.attached then
    put("  No `leanls` client is attached to this buffer.")
    put("  Nothing below section 2 comes from a language server: whatever colour")
    put("  this token has is the syntax file's, or the theme's.")
  elseif not R.highlighter_running then
    put("  A `leanls` client is attached, but Neovim's semantic-token highlighter")
    put("  is not running on this buffer, so there are no tokens to report.")
    put("  (`vim.lsp.semantic_tokens.get_at_pos` returned nil, not an empty list.)")
  elseif #R.tokens == 0 then
    put("  The highlighter is running and NO TOKEN covers this position.")
    put("  The server classifies identifiers; punctuation, whitespace and")
    put("  notation atoms it does not tokenise fall through to the syntax file.")
  end
  -- Gated on the LEGEND, not on the mode. See the note in M.report().
  if R.attached and R.legend_rich == false then
    gap()
    put("  This legend has no `propWorld`, so no world/level classification")
    put("  arrives and the `@lean.*` grid cannot apply. `:LeanRichTokens status`")
    put("  reports which toolchain elan resolved.")
  elseif R.attached and R.legend_rich and R.forced == false then
    gap()
    put("  NOTE `vim.g.lean_rich_tokens = false` — rich client behaviour is off,")
    put("  and the legend above is rich ANYWAY. This server build does not gate")
    put("  its legend on the capability, so the rich tokens keep arriving and")
    put("  everything in sections 1 to 3 is real. What the setting turned off is")
    put("  the capability on the wire, not the classification.")
  end

  for i, tok in ipairs(R.tokens) do
    gap()
    if #R.tokens > 1 then
      put(("  token %d of %d (client %s)"):format(i, #R.tokens, tostring(tok.client_id)))
    end
    put(
      ("  %-11s %-24s %s"):format(
        "type",
        tok.type,
        M.TYPE_GLOSS[tok.type] or "(no gloss for this name — please add one)"
      )
    )
    -- In NAMES.md's category order, so the two axes that decide the colour
    -- are read first and the same set always reads the same way.
    local names = M.sorted_mods(tok.modifiers)
    if #names == 0 then
      put(("  %-11s %s"):format("modifiers", "(none)"))
    end
    local surprises = {}
    for j, m in ipairs(names) do
      put(
        ("  %-11s %-24s %s"):format(
          j == 1 and "modifiers" or "",
          m,
          M.MOD_GLOSS[m] or "(no gloss for this name — please add one)"
        )
      )
      if M.MOD_NEVER_SET[m] then
        surprises[#surprises + 1] = m
      end
    end
    -- The seven standard LSP modifiers NAMES.md records as kept for legend
    -- compatibility and NEVER SET. Seeing one on a real token is not a
    -- cosmetic surprise: it means the server's vocabulary changed under this
    -- config, and every gloss and grouping here was written against the old
    -- meaning. Say so at the point of use rather than leaving the reader to
    -- notice that a modifier's gloss says it cannot happen.
    if #surprises > 0 then
      put()
      put(
        ("  !! %s: NAMES.md says this server never sets %s. It just did, so the"):format(
          table.concat(surprises, ", "),
          #surprises > 1 and "these" or "this"
        )
      )
      put("     legend's meaning has changed and the glosses above may be stale.")
    end
    local s = M.sentence(tok.type, tok.modifiers)
    put()
    local prefix = "  In English:  "
    put_hl(prefix .. s.headline, "Title", #prefix, #prefix + #s.headline)
    if s.detail then
      put("               " .. s.detail)
    end
    for _, c in ipairs(s.clauses) do
      put("               · " .. c)
    end

    -- Whether highlights.lua's world × level grid reached this token, and if
    -- not, which of the two reasons it was. Read off the OBSERVED stack
    -- rather than by re-deciding the rule here — a second copy of that
    -- decision would agree with itself forever while highlights.lua moved.
    if i == 1 then
      local synth
      for _, L in ipairs(R.layers) do
        if L.group:match("^@lean%.") then
          synth = L
        end
      end
      local world, level
      for m in pairs(tok.modifiers or {}) do
        if M.WORLDS[m] then
          world = m
        elseif M.LEVELS[m] then
          level = m
        end
      end
      put()
      if synth then
        put(
          ("  @lean.* grid:  %s, synthesised at priority %d"):format(
            synth.group,
            synth.priority
          )
        )
      elseif world and level then
        put("  @lean.* grid:  no group. The world × level pair IS present, so this")
        put("                 token TYPE is one lua/config/lean/highlights.lua skips")
        put("                 on purpose (`sorry` carries a background chip that a")
        put("                 priority-128 foreground would make unreadable).")
      else
        put("  @lean.* grid:  no group — without both a world and a level there is")
        put("                 no cell to place it in, so the token keeps whatever")
        put("                 lua/plugins/themes.lua says about its `@lsp.*` groups.")
      end
    end
  end
  put()

  -- ── 2 · the groups ───────────────────────────────────────────────────
  put(rule("2 · WHAT IT IS BEING CAPTURED AS — and at what priority"))
  put()
  put("  Every group that applies at this position, highest priority first.")
  put("  ★ marks the highest-priority group that resolves to ANYTHING; an")
  put("  undefined group is listed because it applies, and contributes nothing.")
  put()
  put(("   %-5s %-8s %s"):format("pri", "layer", "group / what it resolves to"))

  local desc = {}
  for i = #R.layers, 1, -1 do
    desc[#desc + 1] = R.layers[i]
  end
  -- The group name and its resolved appearance go on separate lines, because
  -- `@lsp.typemod.variable.strictImplicit.lean` is 44 columns on its own and
  -- a single-line table would either wrap or truncate the part that matters.
  local CONT = string.rep(" ", 2 + 1 + 5 + 1 + 8 + 1) -- matches `head` below
  for _, L in ipairs(desc) do
    local star = (L == R.winner) and "★" or " "
    local pri = tostring(L.priority)
    if L.kind == "syntax" then
      pri = "~50"
    elseif L.kind == "window" then
      pri = "base"
    end
    local head = ("  %s%-5s %-8s "):format(star, pri, L.kind)
    put_hl(head .. L.group, L.group, #head, #head + #L.group)
    put(CONT .. M.describe(L))
    if L.note then
      put(CONT .. "(" .. L.note .. ")")
    end
  end
  if #R.layers == 0 then
    put("  (nothing at all applies here)")
  end
  if #(R.layers) > 0 then
    local has_ts = false
    for _, L in ipairs(R.layers) do
      if L.kind == "treesitter" then
        has_ts = true
      end
    end
    if not has_ts then
      put()
      put("  treesitter: none — no parser is attached for this buffer.")
    end
  end
  put()
  put("  `syntax` is not an extmark: it is the base the extmarks compose over.")
  put("  ~50 is `vim.hl.priorities.syntax`, the value Neovim publishes for it.")
  put("  Neovim lays down its own three marks per token at 125 (type), 126")
  put("  (each modifier) and 127 (each type × modifier crossing);")
  put("  lua/config/lean/highlights.lua synthesises one at 128, above all of them.")
  if R.winner_ties > 0 then
    put()
    put(
      ("  NOTE %d other defined group(s) share priority %d with ★. Neovim breaks"):format(
        R.winner_ties,
        R.winner.priority
      )
    )
    put("       that tie by mark order, which `vim.inspect_pos` does not expose —")
    put("       so ★ is this tool's pick, not a derived fact. Section 3 is.")
  end
  put()

  -- ── 3 · the cell ─────────────────────────────────────────────────────
  put(rule("3 · WHAT WAS ACTUALLY DRAWN — a composition, not the winner"))
  put()
  put("  The cell is NOT ★'s definition. Each of fg / bg / sp is replaced by the")
  put("  highest-priority group that sets it; bold, italic and strikethrough OR")
  put("  together, so a lower layer's bold survives a higher layer that is silent")
  put("  about bold; and the underline STYLE is one 3-bit slot, so styles replace")
  put("  each other while `sp` survives separately (GOTCHAS B4).")
  put()

  local function attrline(label, value, src)
    if src then
      local head = ("  %-14s %-12s from "):format(label, value)
      local tail = src.group .. ("  (%s)"):format(src.priority)
      local r = put_hl(head .. tail, src.group, #head, #head + #src.group)
      if src.also and src.also > 0 then
        lines[r + 1] = lines[r + 1]
          .. ("  — and %d lower layer(s) set it too"):format(src.also)
      end
    else
      put(("  %-14s %s"):format(label, value))
    end
  end

  if R.cell then
    local a = R.cell.attrs
    local function show(k, label, v)
      attrline(label, v, R.composed[k])
    end
    put(("  rendered cell  %q"):format(R.cell.char))
    put()
    show("fg", "fg", hex(a.foreground) or "(none — the default foreground)")
    if a.background or R.composed.bg then
      show("bg", "bg", hex(a.background) or "(none)")
    end
    if a.special or R.composed.sp then
      show("sp", "sp", hex(a.special) or "(none)")
    end
    for _, k in ipairs(BOOLS) do
      if a[k] or R.composed[k] then
        show(k, k, a[k] and "on" or "OFF")
      end
    end
    for _, k in ipairs(UNDERLINES) do
      if a[k] or R.composed[k] then
        show(k, k, a[k] and "on" or "OFF")
      end
    end

    -- The diff. A simulation that always agrees with itself is worth nothing;
    -- this is the line that makes the section falsifiable.
    local diffs = {}
    local function cmp(k, actual)
      local pred = R.composed[k]
      local p = pred and pred.value or nil
      local want = (k == "fg" or k == "bg" or k == "sp") and (hex(actual) or nil)
        or (actual and true or nil)
      if p ~= want then
        diffs[#diffs + 1] = ("%s: predicted %s, drawn %s"):format(
          k,
          tostring(p),
          tostring(want)
        )
      end
    end
    cmp("fg", a.foreground)
    cmp("bg", a.background)
    cmp("sp", a.special)
    for _, k in ipairs(BOOLS) do
      cmp(k, a[k])
    end
    for _, k in ipairs(UNDERLINES) do
      cmp(k, a[k])
    end
    put()
    if #diffs == 0 then
      put("  ✓ the drawn cell is exactly what merging the stack above predicts.")
    else
      put("  ✗ the drawn cell and the merge above DISAGREE:")
      for _, d in ipairs(diffs) do
        put("      " .. d)
      end
      put("    Something outside the extmark stack contributed: 'cursorline',")
      put("    Visual, Search, a floating window's winhighlight, or a decoration")
      put("    provider that draws without leaving a mark. The drawn cell is the")
      put("    truth; the merge is this tool's model of it.")
    end
  else
    put("  Could not read the screen cell.")
    put("  " .. (R.cell_error or "unknown reason"))
    put()
    put("  Sections 1 and 2 are unaffected — they are read from the buffer, not")
    put("  from the screen.")
  end

  put()
  put(("  `q` closes.  NAMES.md is the full vocabulary: %s"):format(
    "~/ClaudeProjects/leanSetup/docs/lean-highlighting/NAMES.md"
  ))
  return lines, marks
end

-- ── the float ──────────────────────────────────────────────────────────
-- Nothing below here may read screen state; see the header.

local ns = vim.api.nvim_create_namespace("lean.inspect_token")

--- Sample the token under the cursor and show the report.
---
--- Sampling happens FIRST and completely, because opening the float covers
--- the token and moves the cursor out of the window.
function M.open()
  local win = vim.api.nvim_get_current_win()
  local ok, R = pcall(M.report, win)
  if not ok then
    vim.notify("Lean token inspector: " .. tostring(R), vim.log.levels.ERROR)
    return
  end
  local lines, marks = M.render(R)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  for _, m in ipairs(marks) do
    -- pcall: a group name is only a name, and painting must never be the
    -- reason the report fails to appear.
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, m.row, m.col, {
      end_col = m.end_col,
      hl_group = m.group,
      priority = 200,
    })
  end
  vim.bo[buf].modifiable = false

  -- Snacks.win is what \? and the rest of this config use for floats, and it
  -- already binds `q` to close.
  Snacks.win({
    buf = buf,
    width = 0.9,
    height = 0.9,
    border = "rounded",
    title = " Lean token inspector ",
    title_pos = "center",
    wo = { wrap = false, number = false, signcolumn = "no", cursorline = false },
    bo = { bufhidden = "wipe" },
  })
  return R
end

return M
