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

-- (There was a `fg(name)` helper here. It was superseded — fifteen cases
-- inline the same `nvim_get_hl(..., { link = false })` read, and every
-- assertion it would have served is present — so it was a dead local, not a
-- dropped assertion. Checked before deleting.)

-- ── the input model ────────────────────────────────────────────────────

T["palette"]["defaults are complete and every colour is real"] = function()
  local got = pal([==[
    local d = HL.defaults()
    local bad = {}
    -- `alarm` is the axiom/auto underline `sp`; `simp_bg` is the @[simp]
    -- background tint, which is a real channel and must round-trip like any
    -- other colour. `simp_sp`, `recede` and `dust` used to be here and are
    -- retired — see "a retired input in a saved file is ignored" below.
    for _, k in ipairs({ "alarm", "simp_bg" }) do
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
    -- B8, without needing lua_ls on the PATH: a duplicate key in a Lua table
    -- literal is silently last-wins, so the source can list more `hues`
    -- entries than the table ends up holding, and every colour assertion
    -- still passes because it asserts on the winner. Count both sides.
    local src = 0
    local path = vim.api.nvim_get_runtime_file("lua/config/lean/highlights.lua", false)[1]
    local inside = false
    for line in io.lines(path) do
      if line:match("^%s*hues = {") then inside = true
      elseif inside and line:match("^%s*},%s*$") then inside = false
      elseif inside and line:match('^%s*[%a_][%w_]* = "#%x%x%x%x%x%x"') then src = src + 1 end
    end
    return { bad = bad, nhues = nhues, nsrc = src, channels = d.channels,
             -- presence as a boolean: a nil field vanishes on the way back
             has_simp_underline = d.channels.simp_underline ~= nil }
  ]==])
  expect.equality(got.bad, {})
  expect.equality(got.nhues > 0, true)
  expect.equality(got.nsrc, got.nhues) -- no silently shadowed duplicate
  expect.equality(got.channels.former_bold, true)
  expect.equality(got.channels.local_italic, true)
  expect.equality(got.channels.simp_marker, true)
  expect.equality(got.has_simp_underline, false) -- renamed, not kept alongside
end

-- `nvim_get_hl` ROUND-TRIPS LOWERCASE. So a palette string held as
-- `#FF1493` compares UNEQUAL to the `#ff1493` that comes back off the
-- rendered group, while looking identical in every diff and every log line.
-- Four uppercase literals in DEFAULTS cost three test failures exactly that
-- way. Two separate claims, because they fail separately:
--   1. nothing SHIPPED is uppercase, so a palette string can be compared to
--      a rendered one directly;
--   2. an uppercase hex a USER types is still accepted — `%x` matches A-F —
--      and is normalised, so it too compares equal to what renders.
T["palette"]["a hex given in uppercase compares equal to what renders"] = function()
  local got = pal([==[
    HL.setup()
    local function fg(n)
      local h = vim.api.nvim_get_hl(0, { name = n, link = false })
      return h.fg and string.format("#%06x", h.fg) or "nil"
    end
    local shouty = {}
    for k, v in pairs(HL.defaults().hues) do
      if v ~= v:lower() then shouty[#shouty+1] = k .. "=" .. v end
    end
    table.sort(shouty)
    -- A shipped value, compared to the cell it paints, with NO case coercion
    -- on either side. This is the comparison that broke.
    local hyp = HL.group("variable", { propWorld = true, element = true, ["local"] = true })
    local shipped_matches = HL.defaults().hues.prop_element_local == fg(hyp)

    -- A user typing SHOUTED hex into :LeanPalette must still work...
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.data_element = "#00FF00"
    local clean, bad = HL.validate(inputs)
    HL.apply(clean)
    return {
      shouty = shouty,
      shipped_matches = shipped_matches,
      nbad = #bad,                          -- accepted, not rejected
      stored = HL.opts.hues.data_element,   -- ...and normalised
      rendered = fg("@lean.data.element"),
    }
  ]==])
  expect.equality(got.shouty, {}) -- 1 · nothing shipped shouts
  expect.equality(got.shipped_matches, true)
  expect.equality(got.nbad, 0) -- 2 · uppercase input is accepted
  expect.equality(got.stored, "#00ff00") -- and stored lowercased
  expect.equality(got.rendered, got.stored) -- so it compares equal to the cell
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
      -- and the novel hue reaches the palette
      pal = HL.palette.propFormer,
    }
  ]==])
  expect.equality(got.prop, "#111111")
  expect.equality(got.novel, "#222222") -- kept, not dropped
  expect.equality(got.spaced_present, false) -- rejected: not an identifier
  expect.equality(got.junkval_present, false) -- rejected: not a hex
  expect.equality(got.data_present, true) -- shipped default retained
  expect.equality(got.nbad, 2)
  -- The generator counts nothing: a novel hue reaches the palette verbatim.
  expect.equality(got.pal, "#222222")
end

-- ONE INPUT OWNS ONE CELL, and that is a change from the generated palette:
-- `hues.prop` used to move the whole Prop column because sort and former
-- were computed from it. Now every cell is hand-picked, so `prop_element`
-- moves `@lean.prop.element` and NOTHING else — not its own `.local`
-- sibling, which has its own key, and not the rest of the world.
--
-- The property that survives is the one worth keeping: a change reaches
-- everything it owns and nothing it does not. Both halves are asserted,
-- because the interesting failure is either one alone.
T["palette"]["changing a cell hue moves that cell and no other"] = function()
  local got = pal([==[
    HL.setup()
    HL.warm()  -- so the lazily-built .local variants exist to be watched
    local watched = { "@lean.prop.element", "@lean.prop.element.local",
                      "@lean.prop.sort", "@lean.prop.former",
                      "@lean.data.element", "@lean.data.element.local",
                      "@lean.poly.element" }
    local function snap()
      local out = {}
      for _, g in ipairs(watched) do
        local h = vim.api.nvim_get_hl(0, { name = g, link = false })
        out[g] = h.fg and string.format("#%06x", h.fg) or "nil"
      end
      return out
    end
    local before = snap()
    local inputs = vim.deepcopy(HL.opts)
    inputs.hues.prop_element = "#00ff00"
    HL.apply(inputs)
    local one = snap()
    -- ...and now the whole Prop world at once, which is what the picker's
    -- family of rows adds up to.
    inputs = vim.deepcopy(HL.opts)
    for k in pairs(inputs.hues) do
      if k:match("^prop") then inputs.hues[k] = "#0000ff" end
    end
    HL.apply(inputs)
    return { before = before, one = one, all = snap() }
  ]==])
  -- One cell key moved exactly one cell...
  expect.equality(got.one["@lean.prop.element"], "#00ff00")
  expect.equality(got.one["@lean.prop.element.local"], got.before["@lean.prop.element.local"])
  expect.equality(got.one["@lean.prop.sort"], got.before["@lean.prop.sort"])
  expect.equality(got.one["@lean.prop.former"], got.before["@lean.prop.former"])
  expect.equality(got.one["@lean.data.element"], got.before["@lean.data.element"])
  expect.equality(got.one["@lean.poly.element"], got.before["@lean.poly.element"])
  -- Non-vacuity for the "and no other" half: the untouched groups are real
  -- colours, not two `nil`s comparing equal.
  expect.no_equality(got.before["@lean.prop.element.local"], "nil")
  expect.no_equality(got.before["@lean.poly.element"], "nil")
  -- ...and the whole family moved together when the whole family was set.
  for _, g in ipairs({ "@lean.prop.element", "@lean.prop.element.local",
                       "@lean.prop.sort", "@lean.prop.former" }) do
    expect.equality(got.all[g], "#0000ff")
  end
  expect.equality(got.all["@lean.data.element"], got.before["@lean.data.element"])
  expect.equality(got.all["@lean.poly.element"], got.before["@lean.poly.element"])
end

-- DELETED: "the blend factor drives every dusty shade identically". The
-- blend is gone — Dan, "FUCK any blending. It's HORSESHIT." — along with
-- `dust`, `recede` and every `*_dust` palette entry. The case tested the
-- deleted mechanism exactly and had nothing to be repointed at.

-- A retired input must not turn a saved palette into a damaged one. Dan's
-- live `lean-palette.json` was written by the version that had `dust`,
-- `recede` and `simp_sp`, and `M.load()` now NOTIFIES on complaints — so an
-- ignorable key that produced one would put a warning on his screen at every
-- start and teach him that the warning means nothing.
T["palette"]["a retired input in a saved file is ignored, not complained about"] = function()
  local got = pal([==[
    HL.state_path = vim.fn.tempname()
    local fh = io.open(HL.state_path, "w")
    fh:write('{"inputs":{"dust":0.42,"recede":"#7f849c","simp_sp":"#f9e2af",' ..
             '"hues":{"data_element":"#00ff00"}},"overrides":{}}')
    fh:close()
    local state, bad = HL.load()
    return {
      nbad = #bad,
      kept = state.inputs.hues.data_element,   -- the rest of the file survived
      dust = state.inputs.dust,                -- and the retired keys did not
      recede = state.inputs.recede,
      simp_sp = state.inputs.simp_sp,
      -- presence as booleans: a nil field vanishes on the way back.
      has_dust = state.inputs.dust ~= nil,
      has_recede = state.inputs.recede ~= nil,
      has_simp_sp = state.inputs.simp_sp ~= nil,
    }
  ]==])
  expect.equality(got.nbad, 0) -- ignored, not complained about
  expect.equality(got.kept, "#00ff00") -- and the file was not discarded
  expect.equality(got.has_dust, false)
  expect.equality(got.has_recede, false)
  expect.equality(got.has_simp_sp, false)
end

-- The one retired key that is MIGRATED rather than dropped.
-- `channels.simp_underline` was an enum over underline styles; the channel
-- became a background tint and the key became `simp_marker`, a boolean. A
-- key whose name lies about what it does is worse than a rename, so the
-- rename happened — and a saved palette written before it must still say
-- what it meant, in both directions.
T["palette"]["the retired simp_underline key migrates to simp_marker"] = function()
  local got = pal([==[
    local function load_channels(body)
      HL.state_path = vim.fn.tempname()
      local fh = io.open(HL.state_path, "w"); fh:write(body); fh:close()
      local state, bad = HL.load()
      return { marker = state.inputs.channels.simp_marker, nbad = #bad }
    end
    local on  = load_channels('{"inputs":{"channels":{"simp_underline":"underdotted"}}}')
    local off = load_channels('{"inputs":{"channels":{"simp_underline":"none"}}}')
    -- the NEW key wins outright when both are present
    local both = load_channels('{"inputs":{"channels":' ..
                               '{"simp_underline":"underdotted","simp_marker":false}}}')
    -- and the migrated value really reaches the paint
    HL.state_path = vim.fn.tempname()
    local fh = io.open(HL.state_path, "w")
    fh:write('{"inputs":{"channels":{"simp_underline":"none"}}}'); fh:close()
    HL.setup({ load_saved = true })
    local g = HL.group("theorem", { propWorld = true, element = true, simp = true })
    return { on = on, off = off, both = both,
             -- the channel is off, so the suffix must be gone from the NAME
             -- as well as the paint
             group_when_off = g,
             bg_when_off = HL._specs()[g].bg or "nil" }
  ]==])
  expect.equality(got.on.marker, true) -- a style meant "on"
  expect.equality(got.off.marker, false) -- "none" meant "off"
  expect.equality(got.both.marker, false) -- the new key wins
  expect.equality(got.on.nbad, 0) -- and none of it is a complaint
  expect.equality(got.off.nbad, 0)
  expect.equality(got.group_when_off, "@lean.prop.element")
  expect.equality(got.bg_when_off, "nil")
end

-- `M.load` is TOTAL by design — it runs inside catppuccin's `config`
-- function, where throwing costs the whole colorscheme — so a hand-edited or
-- half-corrupt `lean-palette.json` was repaired in silence and the user
-- simply got some of the colours he had chosen. For a file whose entire
-- purpose is to hold deliberate choices that is the wrong trade. Both
-- directions are asserted: it speaks up when something was dropped, and it
-- stays quiet when nothing was.
T["palette"]["a partly unreadable saved palette is reported, not silently repaired"] = function()
  local got = pal([==[
    local function run(body)
      HL.state_path = vim.fn.tempname()
      local fh = io.open(HL.state_path, "w"); fh:write(body); fh:close()
      local seen = {}
      local real = vim.notify
      vim.notify = function(msg, lvl) seen[#seen+1] = { msg = tostring(msg), lvl = lvl } end
      HL.setup({ load_saved = true })
      vim.wait(500, function() return #seen > 0 end)   -- the notify is scheduled
      vim.notify = real
      -- `kept` has to be read HERE: each run replaces HL.opts wholesale, so
      -- reading it after the last run reports the last file's inputs.
      return { seen = seen, kept = HL.opts.hues.data_element }
    end
    local noisy = run('{"inputs":{"hues":{"prop_element":"chartreuse",' ..
                      '"data_element":"#00ff00"}},"overrides":{}}')
    local clean = run('{"inputs":{"hues":{"data_element":"#00ff00"}},"overrides":{}}')
    -- retired keys are ignorable, not complaints: this file must be silent
    local old = run('{"inputs":{"dust":0.42,"recede":"#7f849c","simp_sp":"#f9e2af"},' ..
                    '"overrides":{}}')
    return {
      n_noisy = #noisy.seen,
      msg = noisy.seen[1] and noisy.seen[1].msg or "",
      lvl = noisy.seen[1] and noisy.seen[1].lvl or -1,
      warn = vim.log.levels.WARN,
      n_clean = #clean.seen,
      n_old = #old.seen,
      -- and the GOOD half of the noisy file was still applied
      kept = noisy.kept,
    }
  ]==])
  expect.equality(got.n_noisy, 1)
  expect.equality(got.lvl, got.warn)
  expect.equality(got.msg:find("prop_element", 1, true) ~= nil, true) -- names the key
  expect.equality(got.msg:find("chartreuse", 1, true) ~= nil, true) -- and the value
  expect.equality(got.n_clean, 0) -- non-vacuity: not notifying unconditionally
  expect.equality(got.n_old, 0) -- a retired key is not a complaint
  expect.equality(got.kept, "#00ff00") -- the rest of the file still applied
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

-- TWO CHANNELS, and they moved apart in the rebuild. `simp` is now a
-- BACKGROUND TINT, so its input is `simp_bg` and it stacks with whatever
-- else the token carries. `axiom` and `auto` still compete for the single
-- underline slot (B4), and their style is still an enum input.
--
-- Asserting simp's underline flags are absent is the load-bearing half: if
-- simp ever reclaims the slot, an axiom that is also a simp lemma loses its
-- double underline and nothing else would notice.
T["palette"]["simp is a background, and the underline styles are inputs"] = function()
  local got = pal([==[
    HL.setup()
    local inputs = vim.deepcopy(HL.opts)
    inputs.simp_bg = "#123456"
    inputs.channels.axiom_underline = "undercurl"
    HL.apply(inputs)
    local function look(ty, mods)
      local g = HL.group(ty, mods)
      local s = HL._specs()[g]
      local n = 0
      for _, k in ipairs({ "underline", "undercurl", "underdouble",
                           "underdotted", "underdashed" }) do
        if s[k] then n = n + 1 end
      end
      return { g = g, bg = s.bg or "nil", sp = s.sp or "nil", nunder = n,
               undercurl = s.undercurl or false, underdouble = s.underdouble or false,
               underdashed = s.underdashed or false }
    end
    return {
      simp  = look("theorem", { propWorld = true, element = true, simp = true }),
      plain = look("theorem", { propWorld = true, element = true }),
      axiom = look("axiom",   { propWorld = true, element = true }),
      auto  = look("variable", { dataWorld = true, sort = true, autoImplicit = true }),
    }
  ]==])
  -- simp: a background, driven by its own input, and NOT an underline.
  expect.equality(got.simp.bg, "#123456")
  expect.equality(got.simp.nunder, 0)
  expect.equality(got.simp.sp, "nil")
  expect.equality(got.plain.bg, "nil") -- non-vacuity: the bg came from simp
  -- axiom: still the single underline slot, still an enum input.
  expect.equality(got.axiom.undercurl, true) -- followed the input...
  expect.equality(got.axiom.underdouble, false) -- ...off the shipped default
  expect.equality(got.axiom.nunder, 1) -- B4: exactly one
  expect.no_equality(got.axiom.sp, "nil")
  -- auto: the other claimant on the slot, left at its shipped style.
  expect.equality(got.auto.underdashed, true)
  expect.equality(got.auto.nunder, 1)
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
    -- The key of the VARIANT, not of its parent cell. `local` picks a
    -- different hue now, so `prop_element` would (correctly) leave
    -- `@lean.prop.element.local` exactly where it was and this case would
    -- pass for the wrong reason — the group would be undefined AND the
    -- wrong colour, and only the second half would be checked.
    inputs.hues.prop_element_local = "#123456"
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
    -- The CELL key. `hues.prop` is only the family anchor `@lean.prop`; it
    -- feeds no cell, so setting it alone would (correctly) move nothing.
    inputs.hues.prop_element = "#00ff00"
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
    -- OWN THE PRECONDITION. The child loads the full config, which runs
    -- setup({ load_saved = true }) and paints the USER's saved overrides
    -- onto real groups. The fresh module `pal()` builds starts with an empty
    -- override table, so it does not undo that — it simply does not know
    -- about it. Reading the "before" state off the live group would
    -- therefore read whatever Dan last saved, and the two non-vacuity
    -- guards below would fail the moment he saves an override on this group
    -- without a bg or without bold. Plant the chip explicitly instead: the
    -- case is about set-then-clear being an identity, not about what the
    -- chip happens to be.
    vim.api.nvim_set_hl(0, g, { fg = "#151520", bg = "#f9e2af", bold = true })
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

-- `:colorscheme` clears every group, and catppuccin then REBUILDS its own
-- @lsp.* pins from highlight_overrides. A hand-set colour on one of those
-- would therefore survive exactly until the next reload and then vanish,
-- which is the same class of failure the pre-existing "synthesised groups
-- survive a colorscheme reload" case guards for generated groups — but
-- nothing covered the foreign ones. The baselines have to be re-captured in
-- the same handler, AFTER the theme rebuilds and BEFORE the overrides go
-- back on, or a later clear restores a definition from the previous theme.
T["palette"]["a foreign override survives a colorscheme reload"] = function()
  local got = pal([==[
    HL.setup()
    local g = "@lsp.type.enum.lean"
    local function fg()
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      return h.fg and string.format("#%06x", h.fg) or "nil"
    end
    local pinned = fg()
    HL.set_override(g, { fg = "#ff00ff" })
    local before = fg()
    vim.cmd.colorscheme("catppuccin")
    local after = fg()
    -- and the clear must still restore the theme's FRESH definition
    HL.clear_override(g)
    return { pinned = pinned, before = before, after = after, cleared = fg() }
  ]==])
  expect.no_equality(got.pinned, "nil") -- non-vacuity: the pin is real
  expect.equality(got.before, "#ff00ff")
  expect.equality(got.after, "#ff00ff") -- survived the reload
  expect.equality(got.cleared, got.pinned) -- and undoes cleanly afterwards
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
    inputs.simp_bg = "#070809"
    inputs.channels.axiom_underline = "none"
    HL.apply(inputs)
    HL.set_override("@lsp.type.leanSorryLike.lean", { fg = "#040506", bold = true })
    HL.save()
    local state = HL.load()
    return {
      poly = state.inputs.hues.poly,
      simp_bg = state.inputs.simp_bg,
      axiom = state.inputs.channels.axiom_underline,
      ov = state.overrides["@lsp.type.leanSorryLike.lean"],
    }
  ]==])
  expect.equality(got.poly, "#010203")
  -- `simp_bg` is the @[simp] background tint. It was NOT in validate's
  -- colour list when the channel was introduced, so it silently could not
  -- be saved — the headline new channel was the one input that did not
  -- round-trip.
  expect.equality(got.simp_bg, "#070809")
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
      bad_values = '{"inputs":{"hues":{"prop":"green","data":"#f2cdcd"},"alarm":"lots"},' ..
                   '"overrides":{"@lean.prop":{"fg":"nope","bold":"yes"}}}',
      bad_channel = '{"inputs":{"channels":{"axiom_underline":"squiggly"}}}',
    }
    for name, body in pairs(cases) do
      HL.state_path = vim.fn.tempname()
      local fh = io.open(HL.state_path, "w"); fh:write(body); fh:close()
      local ok, state = pcall(HL.load)
      out[name] = {
        ok = ok,
        prop = ok and state.inputs.hues.prop or "THREW",
        alarm = ok and state.inputs.alarm or "THREW",
        axiom = ok and state.inputs.channels.axiom_underline or "THREW",
        data = ok and state.inputs.hues.data or "THREW",
        overrides = ok and vim.tbl_count(state.overrides) or -1,
      }
    end
    return { out = out, default_prop = d.hues.prop, default_alarm = d.alarm,
             default_axiom = d.channels.axiom_underline }
  ]==])
  for _, name in ipairs({ "truncated", "wrong_type", "nonsense", "bad_channel" }) do
    expect.equality(got.out[name].ok, true)
    expect.equality(got.out[name].prop, got.default_prop)
  end
  -- A file with SOME good values keeps them and drops only the bad ones.
  expect.equality(got.out.bad_values.prop, got.default_prop) -- "green" rejected
  expect.equality(got.out.bad_values.data, "#f2cdcd") -- ...but this one kept
  expect.equality(got.out.bad_values.alarm, got.default_alarm) -- "lots" rejected
  expect.equality(got.out.bad_values.overrides, 0) -- both attrs were junk
  -- An unknown underline style is refused rather than reaching nvim_set_hl,
  -- which throws on a bad key — inside catppuccin's `config` function.
  expect.equality(got.out.bad_channel.axiom, got.default_axiom)
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
    -- The whole DATA world, cell by cell. One cell key is not enough here:
    -- `local` picks its own hue now, so `data_element` alone reaches only
    -- the specimen's global data tokens, and whether the specimen has any
    -- is an accident of which lines it quotes. Moving the world is the
    -- claim the picker actually makes anyway.
    for k in pairs(inputs.hues) do
      if k:match("^data") then inputs.hues[k] = "#00ff00" end
    end
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

-- DELETED: "a cleared cell falls back to its family anchor". It documented
-- the blend fallback, which is gone. It was ALSO testing something that
-- could not happen: it cleared a hue by assigning nil to a deepcopy of
-- `HL.opts` and calling `apply`, but `M.validate` refills every missing key
-- out of `DEFAULTS` — the case only reached the fallback because `apply`
-- was handed the raw table. Through any real path (a saved file, the
-- picker) the cell can never be empty. Both halves are in GOTCHAS.
--
-- What the anchors still do is covered elsewhere: `@lean.prop` / `.data` /
-- `.poly` are named groups, required to exist by "the world x level grid is
-- complete" and required to carry an `fg` by "every generated group carries
-- its own fg after a re-apply", both in tests/test_lean.lua.

return T
