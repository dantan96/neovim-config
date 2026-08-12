-- tests/test_lean_palette.lua — the Lean palette's INPUT model, its override
-- layer, and the picker's specimen.
--
-- Separate from tests/test_lean.lua for the reason stated at the top of that
-- file: opening a Lean buffer loads lean.nvim, which writes the global
-- 'breakat' and leaves a 'winfixbuf' infoview around. Nothing here needs a
-- Lean buffer — every case is a pure function of the module — so this file
-- keeps its own child and never opens one.
--
-- WHAT CANNOT BE TESTED HERE, and is not pretended at: whether a colour
-- reaches a screen cell. Headless Neovim applies no semantic tokens at all
-- (GOTCHAS A1), so an assertion about rendering would be vacuous while
-- looking like end-to-end coverage. That half is verified by driving a real
-- TUI in a pty and reading `nvim__inspect_cell` — see
-- docs/lean-highlighting/tools/hl_cells.sh in the leanSetup repo. What IS
-- tested here is everything below the cell: which group a token resolves to,
-- and what that group's complete specification is.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["palette"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
    end,
    post_once = function()
      child.stop()
    end,
  },
})

--- Run `body` against a FRESH module pair, with persistence pointed at a
--- throwaway path. Freshness matters: the modules are stateful by design
--- (the memo, the spec table, the override table) and a case that inherited
--- another's overrides would pass or fail for the wrong reason.
---
--- The temp state_path is not a nicety. The real one is under
--- stdpath("data"), which is SHARED with the user's running editor — a test
--- that called M.save() with the default path would rewrite the palette Dan
--- sees on his next start.
local function pal(body)
  return child.lua_get(([==[(function()
    package.loaded["config.lean.highlights"] = nil
    package.loaded["config.lean.palette_picker"] = nil
    local HL = require("config.lean.highlights")
    HL.state_path = vim.fn.tempname() .. "/lean-palette.json"
    %s
  end)()]==]):format(body))
end

local function fg(name)
  return ([[(function()
    local h = vim.api.nvim_get_hl(0, { name = %q, link = false })
    return h.fg and string.format("#%%06x", h.fg) or "nil"
  end)()]]):format(name)
end

-- ── the input model ────────────────────────────────────────────────────

T["palette"]["defaults are complete and every colour is real"] = function()
  local got = pal([==[
    local d = HL.defaults()
    local bad = {}
    for _, k in ipairs({ "simp_sp", "alarm", "recede" }) do
      if not tostring(d[k]):match("^#%x%x%x%x%x%x$") then bad[#bad+1] = k end
    end
    -- The SHAPE, not a fixed triple: `hues` is arbitrary-keyed so the
    -- palette can widen to a hand-picked colour per cell without this case
    -- having to be rewritten each time one is added.
    local nhues = 0
    for k, v in pairs(d.hues) do
      nhues = nhues + 1
      if not tostring(v):match("^#%x%x%x%x%x%x$") then bad[#bad+1] = "hues."..tostring(k) end
    end
    return { bad = bad, nhues = nhues, dust = d.dust, channels = d.channels }
  ]==])
  expect.equality(got.bad, {})
  expect.equality(got.nhues > 0, true)
  expect.equality(type(got.dust), "number")
  expect.equality(got.channels.former_bold, true)
  expect.equality(got.channels.local_italic, true)
  expect.equality(got.channels.simp_underline, "underdotted")
end

-- THE WIDENING CONTRACT. `hues` is not a fixed triple: the palette is
-- headed for a hand-picked colour per cell, so a key this version has never
-- heard of must SURVIVE a validate round-trip rather than being dropped as
-- unrecognised. That is the only way a user adds a colour the generator does
-- not ship. Junk keys and junk values are still rejected.
T["palette"]["an unknown hue key survives, and junk still does not"] = function()
  local got = pal([==[
    local inputs, bad = HL.validate({
      hues = {
        prop = "#111111",       -- a shipped key, changed
        propFormer = "#222222", -- a key this version has never heard of
        ["not a key"] = "#333333",
        alsoBad = "chartreuse",
      },
    })
    HL.apply(inputs)
    return {
      prop = inputs.hues.prop,
      novel = inputs.hues.propFormer,
      -- presence as a boolean: a nil field would simply vanish from the
      -- table on its way back to the parent and assert nothing.
      spaced_present = inputs.hues["not a key"] ~= nil,
      junkval_present = inputs.hues.alsoBad ~= nil,
      -- a shipped key absent from the input keeps its default
      data_present = inputs.hues.data ~= nil,
      nbad = #bad,
      -- and the novel hue reaches the derived palette, dusty partner included
      pal = HL.palette.propFormer,
      pal_dust = HL.palette.propFormer_dust,
    }
  ]==])
  expect.equality(got.prop, "#111111")
  expect.equality(got.novel, "#222222") -- kept, not dropped
  expect.equality(got.spaced_present, false) -- rejected: not an identifier
  expect.equality(got.junkval_present, false) -- rejected: not a hex
  expect.equality(got.data_present, true) -- shipped default retained
  expect.equality(got.nbad, 2)
  -- The generator counts nothing: a novel hue gets its computed shade too.
  expect.equality(got.pal, "#222222")
  expect.equality(got.pal_dust ~= nil and got.pal_dust ~= "#222222", true)
end

-- The point of a generated palette: one input moves a whole column and
-- leaves the others exactly where they were.
T["palette"]["changing a world hue moves that world and no other"] = function()
  local got = pal([==[
    HL.setup()
    local before = {}
    for _, g in ipairs({ "@lean.prop.element", "@lean.prop.sort", "@lean.prop.former",
                         "@lean.data.element", "@lean.poly.element" }) do
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      before[g] = string.format("#%06x", h.fg)
    end
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.prop = "#00ff00"
    HL.apply(inputs)
    local after = {}
    for g in pairs(before) do
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      after[g] = string.format("#%06x", h.fg)
    end
    return { before = before, after = after }
  ]==])
  -- The whole prop column moved...
  expect.equality(got.after["@lean.prop.element"], "#00ff00")
  expect.no_equality(got.after["@lean.prop.sort"], got.before["@lean.prop.sort"])
  expect.no_equality(got.after["@lean.prop.former"], got.before["@lean.prop.former"])
  -- ...and nothing else did.
  expect.equality(got.after["@lean.data.element"], got.before["@lean.data.element"])
  expect.equality(got.after["@lean.poly.element"], got.before["@lean.poly.element"])
end

-- The blend factor is the whole reason the dusty shades are generated: at 0
-- they collapse onto their anchor, at 1 they land on the recede target, and
-- all three move together by construction.
T["palette"]["the blend factor drives every dusty shade identically"] = function()
  local got = pal([==[
    HL.setup()
    local function shades()
      return { HL.palette.prop_dust, HL.palette.data_dust, HL.palette.poly_dust }
    end
    local inputs = vim.deepcopy(HL.opts)
    inputs.dust = 0
    HL.apply(inputs)
    local at0 = shades()
    inputs = vim.deepcopy(HL.opts); inputs.dust = 1
    HL.apply(inputs)
    local at1 = shades()
    return { at0 = at0, at1 = at1, anchors = { HL.palette.prop, HL.palette.data, HL.palette.poly },
             recede = HL.palette.recede }
  ]==])
  expect.equality(got.at0, got.anchors)
  expect.equality(got.at1, { got.recede, got.recede, got.recede })
end

-- A channel switched off must vanish from the NAME too, not merely stop
-- painting: the name is the thing a user greps for in `:highlight @lean.`,
-- and a `.local` suffix on a group that is no longer italic is a lie.
T["palette"]["switching a channel off drops its suffix and its attribute"] = function()
  local got = pal([==[
    HL.setup()
    local on = HL.group("variable", { propWorld = true, element = true, ["local"] = true })
    local on_italic = HL._specs()[on].italic
    local inputs = vim.deepcopy(HL.opts)
    inputs.channels.local_italic = false
    HL.apply(inputs)
    local off = HL.group("variable", { propWorld = true, element = true, ["local"] = true })
    return { on = on, on_italic = on_italic, off = off,
             off_italic = HL._specs()[off].italic or false }
  ]==])
  expect.equality(got.on, "@lean.prop.element.local")
  expect.equality(got.on_italic, true)
  expect.equality(got.off, "@lean.prop.element")
  expect.equality(got.off_italic, false)
end

T["palette"]["the underline style for an attribute is an input"] = function()
  local got = pal([==[
    HL.setup()
    local inputs = vim.deepcopy(HL.opts)
    inputs.channels.simp_underline = "undercurl"
    HL.apply(inputs)
    local g = HL.group("theorem", { propWorld = true, element = true, simp = true })
    local s = HL._specs()[g]
    return { g = g, undercurl = s.undercurl or false, underdotted = s.underdotted or false,
             sp = s.sp }
  ]==])
  expect.equality(got.undercurl, true)
  expect.equality(got.underdotted, false)
  expect.no_equality(got.sp, vim.NIL)
end

-- THE RE-APPLY TRAP, stated as a test. Flag-suffixed groups are built
-- LAZILY, so an apply() that dropped the spec table without regenerating
-- would leave `@lean.prop.element.local` undefined — and Neovim's @-group
-- fallback strips segments from the right (B1), resolving it to
-- `@lean.prop.element`. That is a plausible but WRONG colour, not a blank
-- one, which is exactly the kind of failure that reads as correct.
T["palette"]["apply regenerates the lazily-built variants, not just the grid"] = function()
  local got = pal([==[
    HL.setup()
    local g = HL.group("variable", { propWorld = true, element = true, ["local"] = true })
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.prop = "#123456"
    HL.apply(inputs)
    local h = vim.api.nvim_get_hl(0, { name = g, link = false })
    return {
      g = g,
      in_specs = HL._specs()[g] ~= nil,
      fg = h.fg and string.format("#%06x", h.fg) or "nil",
      -- non-vacuity: the parent it would have fallen back to is a DIFFERENT
      -- colour only if the variant carries something the parent does not,
      -- so also assert the distinguishing attribute survived.
      italic = h.italic or false,
    }
  ]==])
  expect.equality(got.g, "@lean.prop.element.local")
  expect.equality(got.in_specs, true)
  expect.equality(got.fg, "#123456")
  expect.equality(got.italic, true)
end

T["palette"]["every generated group carries its own fg after a re-apply"] = function()
  local bad = pal([==[
    HL.setup()
    HL.warm()
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.data = "#abcdef"
    inputs.channels.axiom_underline = "underline"
    HL.apply(inputs)
    local out = {}
    for name, spec in pairs(HL._specs()) do
      if not spec.fg then out[#out+1] = name end
    end
    table.sort(out)
    return out
  ]==])
  expect.equality(bad, {})
end

-- ── the override layer ─────────────────────────────────────────────────

T["palette"]["an override beats the generator"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lean.data.element"
    local gen = HL._specs()[g].fg
    HL.set_override(g, { fg = "#ff00ff", bold = true })
    local h = vim.api.nvim_get_hl(0, { name = g, link = false })
    return { gen = gen, fg = string.format("#%06x", h.fg), bold = h.bold or false }
  ]==])
  expect.no_equality(got.gen, "#ff00ff")
  expect.equality(got.fg, "#ff00ff")
  expect.equality(got.bold, true)
end

-- The separation of the two layers, which is the reason overrides live in
-- their own table: a slider nudge must not silently discard a deliberate
-- hand-set colour.
T["palette"]["an override survives a later generator change"] = function()
  local got = pal([==[
    HL.setup()
    local g, sib = "@lean.prop.element", "@lean.prop.sort"
    HL.set_override(g, { fg = "#ff00ff" })
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.prop = "#00ff00"
    HL.apply(inputs)
    local a = vim.api.nvim_get_hl(0, { name = g, link = false })
    local b = vim.api.nvim_get_hl(0, { name = sib, link = false })
    return {
      overridden = string.format("#%06x", a.fg),
      sibling = string.format("#%06x", b.fg),
      generated_underneath = HL._specs()[g].fg,
    }
  ]==])
  expect.equality(got.overridden, "#ff00ff") -- untouched by the hue change
  expect.no_equality(got.sibling, "#ff00ff") -- but the sibling regenerated
  expect.equality(got.generated_underneath, "#00ff00") -- and the layer beneath moved
end

T["palette"]["clearing one override falls back to the generated value"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lean.data.element"
    local gen = HL._specs()[g].fg
    HL.set_override(g, { fg = "#ff00ff" })
    local during = vim.api.nvim_get_hl(0, { name = g, link = false })
    HL.clear_override(g)
    local after = vim.api.nvim_get_hl(0, { name = g, link = false })
    return { gen = gen, during = string.format("#%06x", during.fg),
             after = string.format("#%06x", after.fg),
             still_overridden = HL.overrides[g] ~= nil }
  ]==])
  expect.equality(got.during, "#ff00ff")
  expect.equality(got.after, got.gen)
  expect.equality(got.still_overridden, false)
end

T["palette"]["clearing every override restores every generated value"] = function()
  local got = pal([==[
    HL.setup()
    local gens = {}
    for _, g in ipairs({ "@lean.prop.element", "@lean.data.element", "@lean.poly.element" }) do
      gens[g] = HL._specs()[g].fg
      HL.set_override(g, { fg = "#ff00ff" })
    end
    local n = HL.clear_all_overrides()
    local after = {}
    for g in pairs(gens) do
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      after[g] = string.format("#%06x", h.fg)
    end
    return { n = n, gens = gens, after = after }
  ]==])
  expect.equality(got.n, 3)
  expect.equality(got.after, got.gens)
end

-- B1 as a property of the override layer. An override that sets only an
-- attribute would otherwise render the group COLOURLESS, because a partial
-- child definition aborts inheritance entirely.
T["palette"]["an attribute-only override still writes a complete spec"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lean.data.element"
    local gen = HL._specs()[g].fg
    HL.set_override(g, { bold = true })
    local h = vim.api.nvim_get_hl(0, { name = g, link = false })
    return { gen = gen, fg = h.fg and string.format("#%06x", h.fg) or "nil",
             bold = h.bold or false }
  ]==])
  expect.equality(got.bold, true)
  expect.equality(got.fg, got.gen) -- restated, not inherited
  expect.no_equality(got.fg, "nil")
end

-- Raw mode has to reach groups the generator never produces, including the
-- themes.lua pins whose whole job is to stop catppuccin owning a standard
-- token name (B2). Those are defined as LINKS, so the fg has to be resolved
-- through the link and restated.
T["palette"]["an override reaches a group the generator never produces"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lsp.type.enum.lean"
    local before = vim.api.nvim_get_hl(0, { name = g, link = false })
    HL.set_override(g, { italic = true })
    local after = vim.api.nvim_get_hl(0, { name = g, link = false })
    return {
      generated = HL._specs()[g] ~= nil,
      before_fg = before.fg and string.format("#%06x", before.fg) or "nil",
      after_fg = after.fg and string.format("#%06x", after.fg) or "nil",
      italic = after.italic or false,
    }
  ]==])
  expect.equality(got.generated, false) -- genuinely outside the generator
  expect.equality(got.italic, true)
  expect.no_equality(got.after_fg, "nil") -- B1: complete spec
  expect.equality(got.after_fg, got.before_fg) -- and the colour did not move
end

-- A REGRESSION, and one that only a rendered cell could show. Clearing an
-- override on a group the generator does not produce used to CLEAR it
-- rather than restore it: `nvim_set_hl(0, name, {})` is not an undo for a
-- definition catppuccin installed at colorscheme time. Measured live on the
-- `sorry` chip, which went from `#151520 on bg#f9e2af bold` to a bare
-- foreground — the exact group themes.lua's SKIP list exists to protect.
T["palette"]["clearing a foreign override restores the theme, not nothing"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lsp.type.leanSorryLike.lean"
    local function snap()
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      return {
        fg = h.fg and string.format("#%06x", h.fg) or "nil",
        bg = h.bg and string.format("#%06x", h.bg) or "nil",
        bold = h.bold or false,
      }
    end
    local before = snap()
    HL.set_override(g, { fg = "#ffffff", bg = "#f38ba8", italic = true })
    local during = snap()
    HL.clear_override(g)
    local after = snap()
    -- and again through the clear-everything path
    HL.set_override(g, { fg = "#ffffff" })
    HL.clear_all_overrides()
    return { before = before, during = during, after = after, after_all = snap() }
  ]==])
  -- Non-vacuity: the chip really is a background chip to begin with.
  expect.no_equality(got.before.bg, "nil")
  expect.equality(got.before.bold, true)
  expect.equality(got.during.bg, "#f38ba8")
  -- The whole point: both clear paths put the chip back exactly.
  expect.equality(got.after, got.before)
  expect.equality(got.after_all, got.before)
end

-- B4: the underline style is a three-bit enum, so a hand-set style has to
-- displace the generated one rather than joining it.
T["palette"]["a hand-set underline replaces the generated one"] = function()
  local got = pal([==[
    HL.setup()
    local g = HL.group("theorem", { propWorld = true, element = true, simp = true })
    HL.set_override(g, { undercurl = true })
    local h = vim.api.nvim_get_hl(0, { name = g, link = false })
    local n = 0
    for _, k in ipairs({ "underline", "undercurl", "underdouble", "underdotted", "underdashed" }) do
      if h[k] then n = n + 1 end
    end
    return { n = n, undercurl = h.undercurl or false, underdotted = h.underdotted or false }
  ]==])
  expect.equality(got.n, 1)
  expect.equality(got.undercurl, true)
  expect.equality(got.underdotted, false)
end

T["palette"]["a malformed override is refused, not propagated"] = function()
  local got = pal([==[
    HL.setup()
    local ok1 = HL.set_override("@lean.data.element", { fg = "not a colour" })
    local ok2 = HL.set_override("@lean.data.element", { wobble = true })
    local clean, bad = HL.validate_override({ fg = "#123456", bold = 7, nonsense = 1 })
    return { ok1 = ok1, ok2 = ok2, clean = clean, nbad = #bad,
             still_clean = HL.overrides["@lean.data.element"] == nil }
  ]==])
  expect.equality(got.ok1, false)
  expect.equality(got.ok2, false)
  expect.equality(got.clean, { fg = "#123456" })
  expect.equality(got.nbad, 2)
  expect.equality(got.still_clean, true)
end

-- ── persistence ────────────────────────────────────────────────────────

T["palette"]["both layers survive a save and load"] = function()
  local got = pal([==[
    HL.setup()
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.poly = "#010203"
    inputs.dust = 0.7
    inputs.channels.axiom_underline = "none"
    HL.apply(inputs)
    HL.set_override("@lsp.type.leanSorryLike.lean", { fg = "#040506", bold = true })
    HL.save()
    local state = HL.load()
    return {
      poly = state.inputs.hues.poly,
      dust = state.inputs.dust,
      axiom = state.inputs.channels.axiom_underline,
      ov = state.overrides["@lsp.type.leanSorryLike.lean"],
    }
  ]==])
  expect.equality(got.poly, "#010203")
  expect.equality(got.dust, 0.7)
  expect.equality(got.axiom, "none")
  expect.equality(got.ov, { fg = "#040506", bold = true })
end

-- The load runs inside catppuccin's `config` function, where an error does
-- not degrade to "default colours" — it aborts the colorscheme and leaves
-- the editor unthemed. So every kind of damage must yield the defaults.
T["palette"]["a damaged state file yields the defaults instead of throwing"] = function()
  local got = pal([==[
    local d = HL.defaults()
    local out = {}
    local cases = {
      truncated = '{"inputs": {"hues"',
      wrong_type = '[1, 2, 3]',
      nonsense = 'not json at all',
      bad_values = '{"inputs":{"hues":{"prop":"green","data":"#f2cdcd"},"dust":"lots"},' ..
                   '"overrides":{"@lean.prop":{"fg":"nope","bold":"yes"}}}',
      out_of_range = '{"inputs":{"dust": 9000}}',
    }
    for name, body in pairs(cases) do
      HL.state_path = vim.fn.tempname()
      local fh = io.open(HL.state_path, "w"); fh:write(body); fh:close()
      local ok, state = pcall(HL.load)
      out[name] = {
        ok = ok,
        prop = ok and state.inputs.hues.prop or "THREW",
        dust = ok and state.inputs.dust or -1,
        overrides = ok and vim.tbl_count(state.overrides) or -1,
      }
    end
    return { out = out, default_prop = d.hues.prop, default_dust = d.dust }
  ]==])
  for _, name in ipairs({ "truncated", "wrong_type", "nonsense", "out_of_range" }) do
    expect.equality(got.out[name].ok, true)
    expect.equality(got.out[name].prop, got.default_prop)
  end
  -- A file with SOME good values keeps them and drops only the bad ones.
  expect.equality(got.out.bad_values.prop, got.default_prop) -- "green" rejected
  expect.equality(got.out.bad_values.dust, got.default_dust) -- "lots" rejected
  expect.equality(got.out.bad_values.overrides, 0) -- both attrs were junk
  -- Clamped rather than rejected: a slider overshoot should not discard the file.
  expect.equality(got.out.out_of_range.dust, 1)
end

-- stdpath("config") is a git repo AND a chezmoi external here. Writing a
-- colour choice into it would show up as a dirty worktree and, worse, as a
-- chezmoi diff pointing the wrong way.
T["palette"]["the state file is not written into the config repo"] = function()
  local got = child.lua_get([[(function()
    package.loaded["config.lean.highlights"] = nil
    local HL = require("config.lean.highlights")
    return { path = HL.state_path, cfg = vim.fn.stdpath("config") }
  end)()]])
  expect.equality(got.path:find(got.cfg, 1, true), nil)
  expect.equality(got.path:match("%.json$") ~= nil, true)
end

-- ── the picker's specimen ──────────────────────────────────────────────

-- The specimen's token positions are resolved by scanning for each token's
-- text, because the server reports UTF-16 offsets and the buffer is UTF-8 —
-- `α`, `ℕ`, `⊆` and `⁻¹` all make those disagree. If a scan ever lands on
-- the wrong occurrence the preview silently paints the wrong character, so
-- every resolved span is checked against the line it came from.
T["palette"]["every specimen token resolves to its own text"] = function()
  local got = pal([==[
    HL.setup()
    local P = require("config.lean.palette_picker")
    local spec = P._specimen()
    local expected = 0
    for _, row in ipairs(spec) do expected = expected + #row - 1 end
    local toks = P._tokens()
    local bad = {}
    for _, t in ipairs(toks) do
      local slice = spec[t.line][1]:sub(t.col + 1, t.col + t.len)
      if slice ~= t.text then
        bad[#bad+1] = ("%d:%d want %q got %q"):format(t.line, t.col, t.text, slice)
      end
    end
    return { expected = expected, resolved = #toks, bad = bad }
  ]==])
  expect.equality(got.bad, {})
  expect.equality(got.resolved, got.expected)
  expect.equality(got.resolved > 60, true)
end

-- A specimen that did not contain the confusable cases would be decoration.
-- These are exactly the distinctions the palette exists to draw.
T["palette"]["the specimen exercises every category the palette distinguishes"] = function()
  local groups = pal([==[
    HL.setup()
    local P = require("config.lean.palette_picker")
    local seen = {}
    for _, g in pairs(P._painting()) do seen[g] = true end
    return vim.tbl_keys(seen)
  ]==])
  local set = {}
  for _, g in ipairs(groups) do
    set[g] = true
  end
  local required = {
    ["@lean.prop.element.local"] = "a hypothesis",
    ["@lean.data.element.local"] = "a data local",
    ["@lean.data.sort.local"] = "a type variable",
    ["@lean.prop.former"] = "a Set-valued definition",
    ["@lean.prop.element.simp"] = "a simp lemma",
    ["@lean.prop.element.axiom"] = "an axiom reference",
    ["@lean.poly.sort.local"] = "a sort-polymorphic type variable",
    ["@lsp.type.leanSorryLike.lean"] = "a sorry",
  }
  local missing = {}
  for g, why in pairs(required) do
    if not set[g] then
      missing[#missing + 1] = g .. " (" .. why .. ")"
    end
  end
  table.sort(missing)
  expect.equality(missing, {})
end

-- The preview's claim is that it runs the recorded classifications through
-- the REAL generator. So an input change must move exactly the tokens that
-- input owns, and leave the rest alone — the "and nothing else" half.
T["palette"]["changing one input repaints only the tokens it owns"] = function()
  local got = pal([==[
    HL.setup()
    local P = require("config.lean.palette_picker")
    local function snapshot()
      local out = {}
      for key, g in pairs(P._painting()) do
        local h = vim.api.nvim_get_hl(0, { name = g, link = false })
        out[key] = { g = g, fg = h.fg and string.format("#%06x", h.fg) or "nil" }
      end
      return out
    end
    local before = snapshot()
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.data = "#00ff00"
    HL.apply(inputs)
    local after = snapshot()
    local moved, stayed_prop = {}, 0
    for key, b in pairs(before) do
      if after[key].fg ~= b.fg then
        moved[#moved+1] = b.g
      elseif b.g:match("%.prop%.") then
        stayed_prop = stayed_prop + 1
      end
    end
    table.sort(moved)
    local uniq, seen = {}, {}
    for _, g in ipairs(moved) do
      if not seen[g] then seen[g] = true; uniq[#uniq+1] = g end
    end
    return { moved = uniq, stayed_prop = stayed_prop, n_moved = #moved }
  ]==])
  -- Everything that moved is in the data world...
  for _, g in ipairs(got.moved) do
    expect.equality(g:match("^@lean%.data%.") ~= nil, true)
  end
  -- ...something actually did move (non-vacuity)...
  expect.equality(got.n_moved > 0, true)
  -- ...and the prop-world tokens were all still there, unmoved.
  expect.equality(got.stayed_prop > 0, true)
end

-- ── the catalogue ──────────────────────────────────────────────────────

T["palette"]["the catalogue reaches beyond the generated grid"] = function()
  local got = pal([==[
    HL.setup()
    HL.warm()
    HL.set_override("LspInlayHint", { fg = "#010101" })
    local cat = HL.catalogue()
    local by = {}
    for _, e in ipairs(cat) do by[e.name] = e end
    return {
      n = #cat,
      grid = by["@lean.prop.element"] and by["@lean.prop.element"].generated or false,
      variant = by["@lean.prop.element.local"] ~= nil,
      pin = by["@lsp.type.leanSorryLike.lean"] ~= nil,
      typemod = by["@lsp.typemod.function.defaultLibrary.lean"] ~= nil,
      inlay = by["LspInlayHint"] and by["LspInlayHint"].overridden or false,
      dochl = by["LeanDocumentHighlight"] ~= nil,
      gloss = by["@lean.prop.element.local"] and by["@lean.prop.element.local"].gloss or "",
    }
  ]==])
  expect.equality(got.grid, true)
  expect.equality(got.variant, true)
  expect.equality(got.pin, true)
  expect.equality(got.typemod, true)
  expect.equality(got.inlay, true)
  expect.equality(got.dochl, true)
  -- The gloss is the point of the catalogue: a name is not a meaning.
  expect.equality(got.gloss:find("proof", 1, true) ~= nil, true)
  expect.equality(got.gloss:find("bound here", 1, true) ~= nil, true)
end

T["palette"]["the picker registers its command"] = function()
  child.lua([[require("config.lean.palette_picker").setup()]])
  expect.equality(H.cmd_exists(child, "LeanPalette"), true)
end

return T
