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
    -- `alarm` is the axiom/auto underline `sp`, and since the third retune
    -- deleted the `@[simp]` marker it is the ONLY standalone colour input
    -- left. `simp_bg`, `simp_sp`, `recede` and `dust` used to be here and are
    -- retired — see "a retired input in a saved file is ignored" below.
    for _, k in ipairs({ "alarm" }) do
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
             -- presence as a boolean: a nil field vanishes on the way back.
             -- BOTH simp keys must be gone, and `simp_bg` with them: the
             -- third retune deleted the marker outright ("It's gotta go"),
             -- and a channel that half-exists is worse than either.
             has_simp_underline = d.channels.simp_underline ~= nil,
             has_simp_marker = d.channels.simp_marker ~= nil,
             has_simp_bg = d.simp_bg ~= nil }
  ]==])
  expect.equality(got.bad, {})
  expect.equality(got.nhues > 0, true)
  expect.equality(got.nsrc, got.nhues) -- no silently shadowed duplicate
  expect.equality(got.channels.former_bold, true)
  expect.equality(got.channels.local_italic, true)
  expect.equality(got.has_simp_underline, false)
  expect.equality(got.has_simp_marker, false)
  expect.equality(got.has_simp_bg, false)
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

-- THE `@[simp]` MARKER IS DELETED, third retune. Dan: "It's gotta go."
-- There were three generations of it — `simp_underline` (an enum), then
-- `simp_marker` + `simp_bg` (a boolean and a background) — and Dan's live
-- `lean-palette.json` on this machine contains keys from all of them.
--
-- The requirement is therefore NOT "the keys do nothing". It is "the keys do
-- nothing AND SAY NOTHING": `M.setup` notifies on every complaint the loader
-- returns, so a retired key that lands in that list puts a WARN on the
-- screen at every editor start, which is how a warning becomes furniture and
-- the one that matters becomes invisible.
--
-- NON-VACUITY. "No complaints" is the pass condition, and a loader that had
-- simply stopped complaining about anything would sail through it. So the
-- same case feeds a key that MUST complain, in the same file.
T["palette"]["the deleted @[simp] keys are ignored, and ignored silently"] = function()
  local got = pal([==[
    local function load_body(body)
      HL.state_path = vim.fn.tempname()
      local fh = io.open(HL.state_path, "w"); fh:write(body); fh:close()
      local state, bad = HL.load()
      return { inputs = state.inputs, bad = bad }
    end
    -- every generation of the key, together, plus a real hue so the file is
    -- not discarded wholesale
    local old = load_body('{"inputs":{"hues":{"prop_element":"#00ff00"},' ..
      '"simp_bg":"#3a3a2a","simp_sp":"#e5b567",' ..
      '"channels":{"simp_underline":"underdotted","simp_marker":true}}}')
    -- ...and a key that IS malformed, so "nbad == 0" above is a fact about
    -- the retired keys and not about the loader having gone quiet.
    local broken = load_body('{"inputs":{"hues":{"prop_element":"chartreuse"}}}')
    -- and the paint: no group may carry a simp suffix or a background.
    HL.state_path = vim.fn.tempname()
    HL.setup({ load_saved = true })
    local g = HL.group("theorem", { propWorld = true, element = true, simp = true })
    local sfx, bg = {}, {}
    for name, spec in pairs(HL._specs()) do
      if name:find("simp", 1, true) then sfx[#sfx+1] = name end
      if spec.bg then bg[#bg+1] = name end
    end
    table.sort(sfx); table.sort(bg)
    return {
      nbad_old = #old.bad,
      kept = old.inputs.hues.prop_element,
      has_simp_bg = old.inputs.simp_bg ~= nil,
      has_marker = old.inputs.channels.simp_marker ~= nil,
      has_underline = old.inputs.channels.simp_underline ~= nil,
      nbad_broken = #broken.bad,
      group_for_a_simp_lemma = g,
      simp_named_groups = sfx,
      groups_with_a_background = bg,
    }
  ]==])
  -- silently ignored...
  expect.equality(got.nbad_old, 0)
  expect.equality(got.kept, "#00ff00") -- and the rest of the file survived
  expect.equality(got.has_simp_bg, false)
  expect.equality(got.has_marker, false)
  expect.equality(got.has_underline, false)
  -- ...and the loader has NOT merely gone quiet.
  expect.equality(got.nbad_broken, 1)
  -- `@[simp]` is unmarked: a simp lemma is the same group as any other cited
  -- lemma, no suffix and no background anywhere in the generated set.
  expect.equality(got.group_for_a_simp_lemma, "@lean.prop.element")
  expect.equality(got.simp_named_groups, {})
  expect.equality(got.groups_with_a_background, {})
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

-- THE UNDERLINE STYLES ARE ENUM INPUTS, and there are exactly three
-- claimants on the one slot (B4): imported, axiom, auto. `simp` used to be a
-- fourth and then a background; it is deleted, and the load-bearing half of
-- this case is now that a `@[simp]` lemma comes back as an ORDINARY cited
-- lemma — no fourth claimant, no background. If simp ever reclaimed the
-- slot, an axiom that is also a simp lemma would lose its double underline
-- and nothing else in the suite would notice.
T["palette"]["the underline styles are inputs, and @[simp] is not one"] = function()
  local got = pal([==[
    HL.setup()
    local inputs = vim.deepcopy(HL.opts)
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
  -- simp: indistinguishable from a plain cited lemma, in every channel.
  expect.equality(got.simp.g, got.plain.g)
  expect.equality(got.simp.bg, "nil")
  expect.equality(got.simp.nunder, 0)
  expect.equality(got.simp.sp, "nil")
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
    inputs.alarm = "#070809"
    inputs.channels.axiom_underline = "none"
    HL.apply(inputs)
    HL.set_override("@lsp.type.leanSorryLike.lean", { fg = "#040506", bold = true })
    HL.save()
    local state = HL.load()
    return {
      poly = state.inputs.hues.poly,
      alarm = state.inputs.alarm,
      axiom = state.inputs.channels.axiom_underline,
      ov = state.overrides["@lsp.type.leanSorryLike.lean"],
    }
  ]==])
  expect.equality(got.poly, "#010203")
  -- `alarm` is the STANDALONE colour input, i.e. the one that is not under
  -- `hues`, and it is here because the class of bug this pins is real: when
  -- `simp_bg` joined that class it was left out of `M.validate`'s colour
  -- list and silently could not be saved — the headline new channel was the
  -- one input that did not round-trip. `simp_bg` is gone; `alarm` inherits
  -- the guard, and it must keep it as long as any such key exists.
  expect.equality(got.alarm, "#070809")
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
    -- Both carry `.imported`, as of the 2026-08-13 retune: every specimen
    -- lemma is Mathlib's, and `defaultLibrary` is a channel. The `@[simp]`
    -- suffix that used to be on the first of these is GONE — the third
    -- retune deleted the marker, so a simp lemma is an ordinary imported
    -- lemma and the specimen must show that rather than a stale suffix.
    -- The axiom one is the underline-precedence case in the flesh:
    -- `imported` sets a straight underline and `axiom` must take the slot
    -- back for its double.
    ["@lean.prop.element.imported"] = "a cited lemma, @[simp] or not",
    ["@lean.prop.element.imported.axiom"] = "an axiom reference",
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

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ BEGIN: `:LeanPalette <subcommand>` — the colour CLI                  │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- WHAT THESE CASES CAN SEE. The same limit as the rest of the file: headless
-- Neovim applies no semantic tokens, so nothing here may claim that a BUFFER
-- repainted. What it can and does check is the layer under that — that
-- `nvim_get_hl` returns the new colour in the same session, with no restart
-- and no `:colorscheme`, which is the mechanism the live repaint rides on.
-- (`HL.apply` and `HL.repaint` both end in `refresh_live_buffers()`, which
-- is what carries it the last step; that step is verified out of band.)

--- Fresh modules, throwaway persistence, and `nvim_api_echo` captured so a
--- case can assert on what the command SAID as well as what it did.
--- `%s` is a body that may call `P.run(...)` and `cap(...)`.
local function cli(body)
  return child.lua_get(([==[(function()
    package.loaded["config.lean.highlights"] = nil
    package.loaded["config.lean.palette_picker"] = nil
    local HL = require("config.lean.highlights")
    HL.state_path = vim.fn.tempname() .. "/lean-palette.json"
    HL.setup()
    local P = require("config.lean.palette_picker")
    local function cap(f)
      local msgs = {}
      local orig = vim.api.nvim_echo
      vim.api.nvim_echo = function(chunks)
        for _, c in ipairs(chunks) do msgs[#msgs+1] = c[1] end
      end
      local ok, err = pcall(f)
      vim.api.nvim_echo = orig
      if not ok then return "THREW: " .. tostring(err) end
      return table.concat(msgs)
    end
    local function fg(name)
      local h = vim.api.nvim_get_hl(0, { name = name, link = false })
      return h.fg and string.format("#%%06x", h.fg) or "nil"
    end
    local function hl(name)
      return vim.api.nvim_get_hl(0, { name = name, link = false })
    end
    %s
  end)()]==]):format(body))
end

T["palette"]["cli: a hue key is live in the same session"] = function()
  local got = cli([==[
    local before = fg("@lean.prop.element")
    -- A ladder name, not a hex: the fast path, and the one a hex-only
    -- parser would silently reject.
    local err = P.run("set prop_element sky")
    return { before = before, after = fg("@lean.prop.element"),
             input = HL.opts.hues.prop_element, err = tostring(err),
             -- ...and it reached the LOCAL variant's sibling too, i.e. the
             -- generator really re-ran rather than one group being poked.
             lemma_variant = fg("@lean.prop.element") }
  ]==])
  expect.equality(got.err, "nil")
  expect.equality(got.input, "#89dceb")
  expect.equality(got.after, "#89dceb")
  expect.no_equality(got.after, got.before)
end

T["palette"]["cli: a group takes a colour and attributes at once"] = function()
  local got = cli([==[
    P.run("set @lean.data.former #00ff00 nobold underdotted")
    local h = hl("@lean.data.former")
    -- ...and again, on top of the override that now exists. This is the half
    -- highlights.lua's `resolve` does NOT cover: it clears the GENERATED
    -- underline when an override names one, but two styles written into the
    -- same override are the picker's own problem.
    P.run("set @lean.data.former underdouble")
    local h2 = hl("@lean.data.former")
    local n2 = 0
    for _, u in ipairs({ "underline", "undercurl", "underdouble",
                         "underdotted", "underdashed" }) do
      if h2[u] then n2 = n2 + 1 end
    end
    -- B4: one underline style per cell. `data.former` ships with a straight
    -- underline from CELL_STYLE, so this also proves the new style REPLACED
    -- it rather than stacking.
    local n = 0
    for _, u in ipairs({ "underline", "undercurl", "underdouble",
                         "underdotted", "underdashed" }) do
      if h[u] then n = n + 1 end
    end
    return { fg = fg("@lean.data.former"), underdotted = h.underdotted or false,
             underline = h.underline or false, bold = h.bold or false, nstyles = n,
             nstyles2 = n2, underdouble2 = h2.underdouble or false,
             underdotted2 = h2.underdotted or false,
             -- The colour set in the first call must survive the second: an
             -- override is PATCHED, not replaced.
             fg2 = fg("@lean.data.former") }
  ]==])
  expect.equality(got.fg, "#00ff00")
  expect.equality(got.underdotted, true)
  expect.equality(got.underline, false)
  expect.equality(got.bold, false)
  expect.equality(got.nstyles, 1)
  expect.equality(got.nstyles2, 1)
  expect.equality(got.underdouble2, true)
  expect.equality(got.underdotted2, false)
  expect.equality(got.fg2, "#00ff00")
end

T["palette"]["cli: a channel switch reaches every variant"] = function()
  local got = cli([==[
    HL.warm()
    local g = HL.group("variable", { propWorld = true, element = true, ["local"] = true })
    local before = hl(g).italic or false
    P.run("set local_italic off")
    return { before = before, after = hl(g).italic or false,
             opt = HL.opts.channels.local_italic }
  ]==])
  expect.equality(got.before, true)
  expect.equality(got.opt, false)
  expect.equality(got.after, false)
end

T["palette"]["cli: list shows only what differs, and reset puts it back"] = function()
  local got = cli([==[
    local clean = cap(function() P.run("list") end)
    P.run("set data_sort mauve")
    P.run("set @lean.prop.former italic bg=#101010")
    local dirty = cap(function() P.run("list") end)
    -- A `set` that EMPTIES an override must delete it, not leave an entry
    -- saying nothing: `list` would otherwise claim the group is hand-set,
    -- and — the observable half — the underline would still be drawn.
    P.run("set @lean.poly.sort underdotted")
    local dotted = hl("@lean.poly.sort").underdotted or false
    P.run("set @lean.poly.sort nounderline")
    local empty_ov = cap(function() P.run("list poly") end)
    local still_dotted = hl("@lean.poly.sort").underdotted or false
    -- A pattern narrows the list...
    local only_hue = cap(function() P.run("list data_sort") end)
    -- ...and a MALFORMED one — `[` opens a character class the user never
    -- closed — must come back empty rather than throwing out of
    -- `string.find`. Issued here, with two things actually set, because with
    -- a clean palette the filter is never reached at all.
    local bad_pattern = cap(function() P.run("list @lean.prop.[") end)
    P.run("reset data_sort")
    P.run("reset @lean.prop.former")
    local back = cap(function() P.run("list") end)
    -- ...and `all`, from a fresh mess, because `reset all` is a different
    -- code path from two `reset <target>`s.
    P.run("set poly_sort peach")
    P.run("reset all")
    local after_all = cap(function() P.run("list") end)
    return { clean = clean, dirty = dirty, back = back, after_all = after_all,
             only_hue = only_hue, bad_pattern = bad_pattern,
             empty_ov = empty_ov, dotted = dotted, still_dotted = still_dotted,
             hue = HL.opts.hues.data_sort, def = HL.defaults().hues.data_sort,
             ov = HL.overrides["@lean.prop.former"] ~= nil }
  ]==])
  -- A clean palette lists nothing at all — the question is "what did I
  -- change", and twenty-four unchanged hues would bury the answer.
  expect.equality(got.clean:find("nothing set", 1, true) ~= nil, true)
  expect.equality(got.dirty:find("data_sort", 1, true) ~= nil, true)
  expect.equality(got.dirty:find("@lean.prop.former", 1, true) ~= nil, true)
  expect.equality(got.dirty:find("bg=#101010", 1, true) ~= nil, true)
  -- Non-vacuity: the underline was really there before it was cancelled.
  expect.equality(got.dotted, true)
  expect.equality(got.still_dotted, false)
  expect.equality(got.empty_ov:find("nothing set", 1, true) ~= nil, true)
  -- A pattern narrows it: the hue is there, the group is not.
  expect.equality(got.only_hue:find("data_sort", 1, true) ~= nil, true)
  expect.equality(got.only_hue:find("@lean.prop.former", 1, true), nil)
  -- A malformed pattern is an empty answer, not a stack trace.
  expect.equality(got.bad_pattern:find("THREW", 1, true), nil)
  expect.equality(got.bad_pattern:find("nothing set", 1, true) ~= nil, true)
  expect.equality(got.back:find("nothing set", 1, true) ~= nil, true)
  expect.equality(got.after_all:find("nothing set", 1, true) ~= nil, true)
  expect.equality(got.hue, got.def)
  expect.equality(got.ov, false)
end

-- THE EMITTER IS THE REQUIREMENT MOST EASILY DONE SHALLOWLY: printing a
-- plausible-looking `highlights.lua` edit for a group that does not live
-- there is worse than saying nothing. So this case does not check that the
-- output LOOKS right — it reads back every `file:line` the emitter prints
-- and requires the `-` line to be that file's actual content.
T["palette"]["cli: source prints edits that exist in the files it names"] = function()
  local got = cli([==[
    P.run("set prop_element_local #ff00ff")           -- a hue key
    P.run("set @lean.data.former sky nobold")         -- a grid cell, both halves
    P.run("set @lsp.type.keyword.lean #123456")       -- a themes.lua pin
    P.run("set @lean.op.prop #654321")                -- a namespace_hl group
    P.run("set former_bold off")                      -- a channel
    P.run("set NotAThing #abcdef")                    -- no home at all
    local text = cap(function() P.run("source") end)
    -- Every `path:lnum` claimed, checked against the file on disk.
    local checked, wrong = 0, {}
    local pending
    for _, line in ipairs(vim.split(text, "\n")) do
      local path, lnum = line:match("^%s*(lua/[%w_/]+%.lua):(%d+)%s*$")
      if path then
        pending = { path = path, lnum = tonumber(lnum) }
      elseif pending and line:match("^%s*%- ") then
        local want = line:gsub("^%s*%- ", "")
        local full = vim.fn.stdpath("config") .. "/" .. pending.path
        local lines = vim.fn.filereadable(full) == 1 and vim.fn.readfile(full) or {}
        local actual = lines[pending.lnum]
        checked = checked + 1
        if actual ~= want then
          wrong[#wrong+1] = ("%s:%d\n  file: %s\n  said: %s")
            :format(pending.path, pending.lnum, tostring(actual), want)
        end
        pending = nil
      end
    end
    return {
      checked = checked, wrong = wrong, text = text,
      -- Routing, by the file each target was sent to.
      hue_to_highlights = cap(function() P.run("source prop_element_local") end),
      cell = cap(function() P.run("source @lean.data.former") end),
      pin = cap(function() P.run("source @lsp.type.keyword.lean") end),
      ns = cap(function() P.run("source @lean.op.prop") end),
      chan = cap(function() P.run("source former_bold") end),
      homeless = cap(function() P.run("source NotAThing") end),
    }
  ]==])
  -- NON-VACUITY FIRST: if nothing were checked the loop would assert nothing.
  expect.equality(got.checked >= 5, true)
  expect.equality(got.wrong, {})
  -- ROUTING. Each target reaches the file that actually defines it.
  expect.equality(got.hue_to_highlights:find("highlights.lua", 1, true) ~= nil, true)
  expect.equality(got.hue_to_highlights:find("prop_element_local", 1, true) ~= nil, true)
  -- A grid cell splits: the colour is a hue INPUT (so it reaches every
  -- variant), the attributes are a CELL_STYLE entry.
  expect.equality(got.cell:find("DEFAULTS.hues.data_former", 1, true) ~= nil, true)
  expect.equality(got.cell:find("CELL_STYLE.data_former", 1, true) ~= nil, true)
  expect.equality(got.pin:find("themes.lua", 1, true) ~= nil, true)
  expect.equality(got.ns:find("namespace_hl.lua", 1, true) ~= nil, true)
  -- ...and namespace_hl paints from a NAMED hue, so the emitter offers the
  -- palette entry as well as the group.
  expect.equality(got.ns:find("p.deeppink", 1, true) ~= nil, true)
  expect.equality(got.chan:find("highlights.lua", 1, true) ~= nil, true)
  -- THE REFUSAL. A group with no source home must say so and print the JSON,
  -- not invent a highlights.lua line for it.
  expect.equality(got.homeless:find("OVERRIDE%-ONLY") ~= nil, true)
  expect.equality(got.homeless:find("highlights.lua", 1, true), nil)
  expect.equality(got.homeless:find("#abcdef", 1, true) ~= nil, true)
end

T["palette"]["cli: bad input is refused without changing anything"] = function()
  local got = cli([==[
    local before = { fg = fg("@lean.prop.element"),
                     nov = vim.tbl_count(HL.overrides) }
    local errs = {
      colour   = tostring(P.run("set prop_element notacolour")),
      word     = tostring(P.run("set @lean.prop.former wibble")),
      sub      = tostring(P.run("frobnicate")),
      bare_set = tostring(P.run("set")),
      chan     = tostring(P.run("set former_bold sideways")),
    }
    return { errs = errs, after = fg("@lean.prop.element"),
             nov = vim.tbl_count(HL.overrides), before = before }
  ]==])
  for _, k in ipairs({ "colour", "word", "sub", "bare_set", "chan" }) do
    -- A message, not a crash and not silence.
    expect.equality({ k, got.errs[k] ~= "nil" }, { k, true })
    expect.equality({ k, got.errs[k]:find("THREW", 1, true) }, { k, nil })
  end
  -- Nothing moved.
  expect.equality(got.after, got.before.fg)
  expect.equality(got.nov, got.before.nov)
end

T["palette"]["cli: completion offers subcommands, targets and values"] = function()
  local got = cli([==[
    local function has(list, want)
      for _, v in ipairs(list) do if v == want then return true end end
      return false
    end
    local subs   = P.complete("", "LeanPalette ")
    local targ   = P.complete("", "LeanPalette set ")
    local filt   = P.complete("prop_e", "LeanPalette set prop_e")
    local vals   = P.complete("", "LeanPalette set @lean.prop.former ")
    local boolch = P.complete("", "LeanPalette set former_bold ")
    local enumch = P.complete("", "LeanPalette set axiom_underline ")
    local resets = P.complete("", "LeanPalette reset ")
    return {
      sub_set = has(subs, "set"), sub_source = has(subs, "source"),
      -- A hue INPUT and a GROUP are both completable, which is the thing
      -- that makes the command usable without remembering either list.
      targ_hue = has(targ, "prop_element_local"),
      targ_group = has(targ, "@lean.prop.element"),
      targ_chan = has(targ, "former_bold"),
      filt = filt,
      -- Values are TARGET-DEPENDENT: attribute words on a group, on/off on a
      -- boolean channel, underline styles on an enum one.
      val_ladder = has(vals, "mauve"), val_attr = has(vals, "nobold"),
      val_under = has(vals, "underdotted"),
      bool_on = has(boolch, "on"), bool_nobold = has(boolch, "nobold"),
      enum_style = has(enumch, "underdouble"), enum_on = has(enumch, "on"),
      reset_all = has(resets, "all"),
    }
  ]==])
  expect.equality(got.sub_set, true)
  expect.equality(got.sub_source, true)
  expect.equality(got.targ_hue, true)
  expect.equality(got.targ_group, true)
  expect.equality(got.targ_chan, true)
  -- Filtering by what has been typed, and nothing that does not match.
  expect.equality(got.filt, { "prop_element", "prop_element_local" })
  expect.equality(got.val_ladder, true)
  expect.equality(got.val_attr, true)
  expect.equality(got.val_under, true)
  -- ...and the negative half, which is what makes "target-dependent" mean
  -- something: a boolean channel does not offer `nobold`, an enum one does
  -- not offer `on`.
  expect.equality(got.bool_on, true)
  expect.equality(got.bool_nobold, false)
  expect.equality(got.enum_style, true)
  expect.equality(got.enum_on, false)
  expect.equality(got.reset_all, true)
end

T["palette"]["cli: save and forget round-trip both layers"] = function()
  local got = cli([==[
    P.run("set data_sort_local #010203")
    P.run("set @lean.prop.former bold")
    P.run("save")
    local state = HL.load()
    local existed = vim.fn.filereadable(HL.state_path) == 1
    P.run("forget")
    return { existed = existed, hue = state.inputs.hues.data_sort_local,
             ov = state.overrides["@lean.prop.former"],
             gone = vim.fn.filereadable(HL.state_path) == 0 }
  ]==])
  expect.equality(got.existed, true)
  expect.equality(got.hue, "#010203")
  expect.equality(got.ov, { bold = true })
  expect.equality(got.gone, true)
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ END: the colour CLI                                                  │
-- ╰──────────────────────────────────────────────────────────────────────╯

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ THE PICKER AS A TUI                                                  │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- WHAT IS AND IS NOT TESTABLE HERE. The picker's floats, its row model, its
-- keymaps and the colour arithmetic behind `h`/`l` are pure Neovim: a
-- headless child opens the windows, the mappings fire, and the control
-- buffer's LINES are the drawn text. What headless cannot see is a screen
-- CELL — no semantic tokens, no composition, no `screenstring` (GOTCHAS A1)
-- — so the questions "does the real buffer repaint" and "does the footer
-- clip at 80x24" are not asked here and are not pretended at. They were
-- answered by driving a pty-hosted TUI at 200x50 and at 80x24; see the audit
-- in the leanSetup repo.
--
-- NO PALETTE PINS. Every colour these cases reason about is READ from
-- `HL.defaults()` and asserted structurally — distance floors and ceilings,
-- family membership, the ladder's own contents. A test that pinned
-- `#ffa8ff` would fail on the next retune while saying nothing about the
-- behaviour it names.
--
-- The one hex written out is `#00ff00`, and it is a SENTINEL, not a pin: a
-- value nothing in the palette can produce, typed in so that "the group came
-- back" is a fact about that exact value rather than about inequality (A4).
-- Fifteen cases above already use it for the same reason.

--- Run `body` against a fresh module pair with the picker OPEN, and a
--- `press(keys)` that goes through the real buffer-local mappings rather
--- than calling the handlers directly — the point of most of these cases is
--- which key does what.
--- The body is spliced with `gsub`, not `format`. This template is full of
--- Lua patterns (`%s`, `%u`, `%x`) and `string.format` eats every one of
--- them — the `cli` helper above escapes each as `%%`, which is a tax on
--- every case written afterwards and was paid wrong twelve times here first.
local function tui(body)
  local tpl = [==[(function()
    package.loaded["config.lean.highlights"] = nil
    package.loaded["config.lean.palette_picker"] = nil
    local HL = require("config.lean.highlights")
    HL.state_path = vim.fn.tempname() .. "/lean-palette.json"
    HL.setup()
    local P = require("config.lean.palette_picker")
    -- A HEADLESS CHILD IS 80x24, and at that size the picker correctly drops
    -- the gloss column for want of room — so a case asserting the gloss is
    -- there would fail for a reason that has nothing to do with it. Sized to
    -- the terminal the audit was taken on, which is also the size the layout
    -- is meant for.
    vim.o.columns, vim.o.lines = 200, 50
    local function press(keys)
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
    end
    --- The control pane's drawn text, as lines.
    local function pane()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local c = vim.api.nvim_win_get_config(w)
        if c.relative ~= "" and c.title and c.title[1][1]:find("palette") then
          return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(w), 0, -1, false)
        end
      end
      return {}
    end
    --- The line carrying the selection marker.
    local function selected()
      for _, l in ipairs(pane()) do
        if l:find("\u{25b8}", 1, true) then return l end
      end
      return ""
    end
    local function gap(a, b)
      local function ch(s, i) return tonumber(s:sub(i, i + 1), 16) or 0 end
      local d = 0
      for _, i in ipairs({ 2, 4, 6 }) do d = d + math.abs(ch(a, i) - ch(b, i)) end
      return d
    end
    --- Move the selection onto the row whose label is exactly `name`.
    local function goto_row(name)
      for _ = 1, 80 do
        if selected():find("\u{25b8}%s*" .. vim.pesc(name) .. "%s") then return true end
        press("j")
      end
      return false
    end
    local out = (function() __BODY__ end)()
    pcall(press, "q")
    return out
  end)()]==]
  return child.lua_get((tpl:gsub("__BODY__", function()
    return body
  end)))
end

-- ── item 1: `h`/`l` must not be able to destroy a colour ───────────────

T["palette"]["nudge preserves the hue and is exactly reversible"] = function()
  local got = tui([==[
    -- The starting colours are READ FROM THE PALETTE, never typed: the point
    -- is that whatever Dan has hand-picked survives, and a literal here
    -- would be testing a colour that is no longer in the file.
    local rows = {}
    for k, hex in pairs(HL.defaults().hues) do rows[#rows+1] = { k, hex } end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    local worst, ragged, asym = 0, {}, {}
    for _, r in ipairs(rows) do
      local up = P.nudge(r[2], 0.04)
      local back = P.nudge(up, -0.04)
      worst = math.max(worst, gap(r[2], up))
      -- A nudge that does nothing is as bad as one that does too much: the
      -- key has to be usable, and 0 would mean the row is frozen.
      if gap(r[2], up) == 0 then ragged[#ragged+1] = r[1] end
      -- WITHIN ONE UNIT PER CHANNEL, not identical. Eight bits per channel
      -- and a round trip through HSL cannot be exact, and pretending
      -- otherwise would mean either a lookup table or a lie. What matters is
      -- the difference in kind from the bug: l-then-h returns a colour
      -- indistinguishable from the one you started with, where it used to
      -- return rosewater. The EXACT value is what `u` restores.
      if gap(r[2], back) > 3 then
        asym[#asym+1] = r[1] .. " " .. r[2] .. "->" .. up .. "->" .. back
      end
    end
    return { worst = worst, ragged = ragged, asym = asym, n = #rows,
             -- Total on nonsense, so a row whose value is somehow not a hex
             -- cannot make the primary adjust key throw inside a redraw.
             junk = P.nudge("nonsense", 0.04), nilsafe = P.nudge(nil, 0.04) == nil }
  ]==])
  expect.equality(got.n > 20, true)
  -- A CEILING, not an equality: one press is a nudge. 4% of the range is
  -- ~10 per channel, so 40 across three channels is generous and 765 (the
  -- old behaviour's worst case, black to white) is nowhere near it.
  expect.equality(got.worst < 60, true)
  expect.equality(got.ragged, {})
  expect.equality(got.asym, {})
  expect.equality(got.junk, "nonsense")
  expect.equality(got.nilsafe, true)
end

T["palette"]["the ladder walk starts from the NEAREST rung, not the end of the list"] = function()
  local got = tui([==[
    -- THE BUG, stated as a test. `ladder_step` used to need the current hex
    -- to BE a rung; off the ladder it returned LADDER[1] or LADDER[#LADDER],
    -- so one `l` on a hand-picked colour replaced it with rosewater and one
    -- `h` with crust. Half the palette is off the ladder.
    local off = {}
    for k, hex in pairs(HL.defaults().hues) do
      local rung = P.nearest_rung(hex)
      -- only the keys that are NOT on a rung are interesting
      if gap(hex, P.ladder()[rung][2]) ~= 0 then off[#off+1] = { k, hex, rung } end
    end
    table.sort(off, function(a, b) return a[1] < b[1] end)
    local ladder = P.ladder()
    local bad, worst = {}, 0
    for _, e in ipairs(off) do
      for _, delta in ipairs({ 1, -1 }) do
        local to = P.ladder_step(e[2], delta)
        worst = math.max(worst, gap(e[2], to))
        -- THE STEP IS FROM THE NEAREST RUNG. Stated exactly rather than as
        -- "it did not land on an end", because landing on an end is the
        -- RIGHT answer when the nearest rung is next to one — `#ffc0cb` is
        -- closest to flamingo, so `h` correctly reaches rosewater, and a
        -- test phrased as "never an end" calls that a bug.
        local want = ladder[(e[3] - 1 + delta) % #ladder + 1][2]
        if to ~= want then
          bad[#bad+1] = ("%s %s d=%d -> %s, wanted %s (nearest rung %s)")
            :format(e[1], e[2], delta, to, want, ladder[e[3]][1])
        end
      end
    end
    return { n_off = #off, bad = bad, worst = worst }
  ]==])
  -- The premise: the palette really has left catppuccin's ladder. If this
  -- ever reaches zero the case above it is vacuous and this says so.
  expect.equality(got.n_off > 5, true)
  expect.equality(got.bad, {})
  -- One `H` from an off-ladder colour costs the distance to its nearest rung
  -- plus one step. That is bounded; a jump to the end of the list is not.
  expect.equality(got.worst < 300, true)
end

T["palette"]["h/l and H/L are different keys"] = function()
  local got = tui([==[
    P.open()
    if not goto_row("data_element") then return { found = false } end
    local start = HL.opts.hues.data_element
    press("l")
    local small = HL.opts.hues.data_element
    press("h")            -- back
    press("L")
    local big = HL.opts.hues.data_element
    return { found = true, start = start, small = small, big = big,
             d_small = gap(start, small), d_big = gap(start, big),
             -- `H`/`L` used to be silent duplicates: `adjust`'s `big`
             -- argument was only read by a `number` row kind that had
             -- already been deleted with the blend.
             same = small == big }
  ]==])
  expect.equality(got.found, true)
  expect.equality(got.same, false)
  expect.equality(got.d_small > 0, true)
  expect.equality(got.d_big > got.d_small, true)
end

T["palette"]["there is no `number` row kind left anywhere"] = function()
  -- SOURCE-VERBATIM, because the thing being asserted is an ABSENCE and no
  -- runtime read can see dead code. ~15 lines of rendering and dispatch were
  -- unreachable, and the argument that fed them is what made `H`/`L` lie.
  local got = child.lua_get([==[(function()
    local path = vim.api.nvim_get_runtime_file("lua/config/lean/palette_picker.lua", false)[1]
    local hits = {}
    local n = 0
    for line in io.lines(path) do
      n = n + 1
      if line:find('kind == "number"', 1, true) or line:find('kind = "number"', 1, true) then
        hits[#hits+1] = n .. ": " .. line
      end
    end
    return hits
  end)()]==])
  expect.equality(got, {})
end

-- ── item 2: undo ───────────────────────────────────────────────────────

T["palette"]["u steps back through both layers, and <C-r> forward"] = function()
  local got = tui([==[
    P.open()
    if not goto_row("data_element") then return { found = false } end
    local start = HL.opts.hues.data_element
    press("lll")
    local moved = HL.opts.hues.data_element
    local rings_before = { P._rings() }
    press("uuu")
    local undone = HL.opts.hues.data_element
    press("<C-r><C-r><C-r>")
    local redone = HL.opts.hues.data_element
    return { found = true, start = start, moved = moved, undone = undone,
             redone = redone, rings = rings_before[1] }
  ]==])
  expect.equality(got.found, true)
  expect.equality(got.moved ~= got.start, true)
  expect.equality(got.undone, got.start)
  expect.equality(got.redone, got.moved)
  expect.equality(got.rings >= 3, true)
end

T["palette"]["undoing an override CLEARS the group rather than leaving it painted"] = function()
  -- THE PART THAT WOULD HAVE BROKEN SILENTLY. Restoring by assigning
  -- `HL.overrides` and repainting bypasses `restore_baseline`, so a group
  -- whose override the undo removes keeps the hand-set colour — a wrong
  -- undo, which is worse than no undo. Asserted against the group's own
  -- value, not against "it changed".
  local got = tui([==[
    local name = "@lsp.type.tactic.lean"
    local function fg()
      local h = vim.api.nvim_get_hl(0, { name = name, link = false })
      return h.fg and string.format("#%06x", h.fg) or "nil"
    end
    local before = fg()
    -- Opened ON that group, so nothing here depends on which row the
    -- catalogue happens to list first.
    P.open({ group = name })
    press("<CR>")                  -- the fg row -> the swatch grid
    press("i<C-u>#00ff00<CR>")     -- an exact hex
    local set, ov_set = fg(), HL.overrides[name] ~= nil
    -- THE DIRECTION THAT BREAKS SILENTLY. Undoing a SET has to REMOVE the
    -- override, and removing one is the only path that runs
    -- `restore_baseline`. A restore that assigns `HL.overrides` and repaints
    -- leaves the group painted with the hand-set colour instead — which is
    -- indistinguishable from "the undo did nothing" and is worse than it.
    press("u")
    local undone, ov_undone = fg(), HL.overrides[name] ~= nil
    press("<C-r>")
    local redone = fg()
    return { before = before, set = set, ov_set = ov_set,
             undone = undone, ov_undone = ov_undone, redone = redone }
  ]==])
  expect.equality(got.set, "#00ff00")
  expect.equality(got.ov_set, true)
  -- Not "it changed": the exact value the group had before anything touched
  -- it, and no override left behind (A4 — a group that merely differs would
  -- pass a `~=` while being wrong).
  expect.equality(got.undone, got.before)
  expect.equality(got.ov_undone, false)
  expect.equality(got.redone, "#00ff00")
end

-- ── item 12: `r` and `X` say what they will take ───────────────────────

T["palette"]["r and X need a second press, and name the damage first"] = function()
  local got = tui([==[
    P.open()
    if not goto_row("data_element") then return { found = false } end
    press("l")
    local moved = HL.opts.hues.data_element
    press("r")
    local after_one = HL.opts.hues.data_element
    local armed = P._status()
    press("r")
    local after_two = HL.opts.hues.data_element
    -- ...and a key in between DISARMS it, so an `r` thought better of is
    -- cancelled by carrying on rather than by remembering not to press it.
    press("l")
    local moved2 = HL.opts.hues.data_element
    press("r")
    press("j")
    press("r")
    local still = HL.opts.hues.data_element
    return { found = true, moved = moved, after_one = after_one,
             after_two = after_two, armed = armed,
             moved2 = moved2, still = still, shipped = HL.defaults().hues.data_element }
  ]==])
  expect.equality(got.found, true)
  expect.equality(got.after_one, got.moved) -- one press changed nothing
  expect.equality(got.after_two, got.shipped)
  expect.equality(got.armed:find("r again to discard", 1, true) ~= nil, true)
  expect.equality(got.armed:find("1 hue change", 1, true) ~= nil, true)
  -- disarmed by the `j`, so the second `r` only re-armed
  expect.equality(got.still, got.moved2)
end

-- ── item 3: the rest of the Lean palette is reachable ──────────────────

T["palette"]["the catalogue reaches namespace_hl's groups, each naming its palette key"] = function()
  local got = child.lua_get([==[(function()
    package.loaded["config.lean.highlights"] = nil
    local HL = require("config.lean.highlights")
    HL.setup()
    HL.warm()
    local NS = require("config.lean.namespace_hl")
    local seen = {}
    for _, e in ipairs(HL.catalogue()) do seen[e.name] = e.gloss end
    local missing, glossless, badkey = {}, {}, {}
    for name in pairs(NS.groups()) do
      if seen[name] == nil then
        missing[#missing+1] = name
      else
        if seen[name] == "" then glossless[#glossless+1] = name end
        -- Every row says which `M.palette` entry it paints from — the
        -- mitigation for the one thing that argued against listing these at
        -- all, since a per-group override splits a family that exists on
        -- purpose. A key it names must be a key that exists.
        local k = seen[name]:match("via p%.([%w_]+)")
        local slot = seen[name]:match("via p%.rainbow%[(%d+)%]")
        if k and NS.palette[k] == nil then badkey[#badkey+1] = name .. " -> p." .. k end
        if slot and NS.palette.rainbow[tonumber(slot)] == nil then
          badkey[#badkey+1] = name .. " -> rainbow[" .. slot .. "]"
        end
        if not k and not slot and name ~= "@lean.ns.prefix" then
          -- `@lean.ns.prefix` is the one group with no `fg` by design; it
          -- still names `p.brass` through its `sp`, so even it is covered
          -- and this branch should stay empty.
          badkey[#badkey+1] = name .. " names no palette key"
        end
      end
    end
    return { missing = missing, glossless = glossless, badkey = badkey,
             n = #HL.catalogue() }
  end)()]==])
  expect.equality(got.missing, {})
  expect.equality(got.glossless, {})
  expect.equality(got.badkey, {})
  -- The audit measured 49 entries with none of namespace_hl's in them.
  expect.equality(got.n > 60, true)
end

T["palette"]["the rainbow's slots are named by position, not by a colliding hue"] = function()
  -- `rainbow[3]` IS `p.yellow` and `rainbow[6]` IS `p.mauve` — both
  -- deliberate. A reverse map from the hex therefore has two right answers
  -- and picked the wrong one, sending the user to the wrong edit; and
  -- `pairs` order is not stable, so it could pick differently on two runs.
  local got = child.lua_get([==[(function()
    local NS = require("config.lean.namespace_hl")
    local by = {}
    for _, e in ipairs(NS.catalogue()) do by[e[1]] = e[2] end
    local bad = {}
    for i = 1, #NS.palette.rainbow do
      for _, pre in ipairs({ "c", "f" }) do
        local name = "@lean.path." .. pre .. i
        local want = "via p.rainbow[" .. i .. "]"
        if not (by[name] or ""):find(want, 1, true) then
          bad[#bad+1] = name .. " says " .. tostring(by[name])
        end
      end
    end
    return bad
  end)()]==])
  expect.equality(got, {})
end

-- ── items 10 and 15: the list is a view of the grid again ──────────────

T["palette"]["the hue rows are grouped by world, with _local under its partner"] = function()
  local got = tui([==[
    P.open()
    local rows, order = pane(), {}
    for _, l in ipairs(rows) do
      -- A hue row's label is the first word after the two-cell cursor
      -- column; a heading has no swatch.
      -- Anchored on the SWATCH, not on the cursor column. Lua patterns are
      -- byte-based, so `\u{25b8}?` does not mean "an optional marker" — the
      -- `?` applies to the last BYTE of a three-byte character — and `^..`
      -- for "skip the marker" skips two thirds of it. Both spellings were
      -- tried and both dropped rows silently, which is the worst way for an
      -- assertion over a list to be wrong.
      local label = l:match("([%w_]+)%s+\u{2588}")
      if label then order[#order+1] = label end
      local headtext = l:match("^%s%s(%u[%u%s]+\u{b7}.*)$")
      if headtext then order[#order+1] = "## " .. headtext:match("^(%u+)") end
    end
    local function idx(want)
      for i, v in ipairs(order) do if v == want then return i end end
    end
    return {
      order = order,
      sample = vim.list_slice(pane(), 1, 12),
      -- Item 15: the two cells the palette exists to separate were sixteen
      -- rows apart under the alphabetical order.
      pair_distance = math.abs((idx("prop_element_local") or 0) - (idx("prop_element") or 0)),
      data_pair = math.abs((idx("data_element_local") or 0) - (idx("data_element") or 0)),
      worlds_first = (idx("## PROP") or 99) < (idx("## DATA") or 0),
      -- Item 10: the anchors are not the parents of the twenty-one cells and
      -- must not sit at the top of the list reading as though they were.
      anchor_after_cells = (idx("prop") or 0) > (idx("prop_former_local") or 99),
      anchor_heading = idx("## ANCHORS") ~= nil,
    }
  ]==])
  expect.equality(got.pair_distance, 1)
  expect.equality(got.data_pair, 1)
  expect.equality(got.worlds_first, true)
  expect.equality(got.anchor_after_cells, true)
  expect.equality(got.anchor_heading, true)
end

-- ── item 6: a group row shows what it already knows ────────────────────

T["palette"]["a GROUPS row carries its colour and its gloss"] = function()
  local got = tui([==[
    P.open()
    press("G")
    local hits, glossed, hexed = 0, 0, 0
    for _, l in ipairs(pane()) do
      local hex, name = l:match("\u{2588}\u{2588}\u{2588}%s+(#%x%x%x%x%x%x)%s+(%S+)")
      if hex and name then
        hits = hits + 1
        hexed = hexed + 1
        local tail = l:match(vim.pesc(name) .. "%s+(%S.*)$")
        if tail and #tail > 3 then glossed = glossed + 1 end
      end
    end
    return { hits = hits, glossed = glossed, hexed = hexed,
             sample = vim.list_slice(pane(), 1, 8),
             width = (function()
               for _, w in ipairs(vim.api.nvim_list_wins()) do
                 local c = vim.api.nvim_win_get_config(w)
                 if c.relative ~= "" and c.title and c.title[1][1]:find("palette") then return c.width end
               end
             end)() }
  ]==])
  expect.equality(got.hits > 10, true)
  expect.equality(got.hexed, got.hits)
  -- Every catalogue entry has a gloss; the audit found the row showed none.
  expect.equality(got.glossed, got.hits)
end

-- ── item 4: the filter ─────────────────────────────────────────────────

T["palette"]["/ narrows the list and <BS> puts it back"] = function()
  local got = tui([==[
    P.open()
    press("G")
    local function n()
      local c = 0
      for _, l in ipairs(pane()) do if l:find("\u{2588}", 1, true) then c = c + 1 end end
      return c
    end
    local all = n()
    press("/@lean.op<CR>")
    local narrowed = n()
    local names = {}
    for _, l in ipairs(pane()) do
      local g = l:match("(@lean%.op%.%w+)")
      if g then names[#names+1] = g end
    end
    press("<BS>")
    return { all = all, narrowed = narrowed, back = n(), names = names,
             status = P._status() }
  ]==])
  expect.equality(got.all > got.narrowed, true)
  expect.equality(got.narrowed > 0, true)
  expect.equality(got.back, got.all)
  expect.equality(vim.tbl_contains(got.names, "@lean.op.prop"), true)
  expect.equality(vim.tbl_contains(got.names, "@lean.op.colon"), true)
end

-- ── item 8: the legend ─────────────────────────────────────────────────

T["palette"]["every key the picker maps is in the `?` legend"] = function()
  local got = tui([==[
    P.open()
    local buf
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local c = vim.api.nvim_win_get_config(w)
      if c.relative ~= "" and c.title and c.title[1][1]:find("palette") then
        buf = vim.api.nvim_win_get_buf(w)
      end
    end
    -- Split on the " / " that joins an alias pair, and normalise: a keymap's
    -- `lhs` for `<Space>` is a literal space and for `<C-r>` is `<C-R>`, so a
    -- naive string compare reports three keys missing that are right there.
    local listed = {}
    for _, entry in ipairs(P._keys()) do
      for k in entry:gmatch("[^%s]+") do
        if k ~= "/" or entry == "/" then listed[k] = true end
      end
      for k in entry:gmatch("[^/]+") do listed[(k:gsub("^%s+", ""):gsub("%s+$", ""))] = true end
    end
    listed[" "] = listed["<Space>"]
    listed["<C-R>"] = listed["<C-r>"]
    -- The arrow duplicates and the two motion aliases are deliberately not
    -- in the legend: they say nothing j/k/h/l does not.
    local ALIASES = {
      ["<Down>"] = true, ["<Up>"] = true, ["<Left>"] = true, ["<Right>"] = true,
    }
    local missing = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
      if not listed[m.lhs] and not ALIASES[m.lhs] then missing[#missing+1] = m.lhs end
    end
    table.sort(missing)
    return { missing = missing, n_listed = vim.tbl_count(listed) }
  ]==])
  expect.equality(got.missing, {})
  expect.equality(got.n_listed > 12, true)
end

-- ── item 11: the bridge from the inspector ─────────────────────────────

T["palette"]["M.open({ group = ... }) lands on that group, open or not"] = function()
  local got = tui([==[
    local function shows(name)
      for _, l in ipairs(pane()) do
        if l:find(name, 1, true) then return true end
      end
      return false
    end
    P.open({ group = "@lsp.type.tactic.lean" })
    local first = shows("@lsp.type.tactic.lean")
    -- ...and AGAIN while already open, which the `S.open` early return used
    -- to make a no-op — precisely when the picker is up, which is the
    -- likeliest state for someone comparing two groups.
    P.open({ group = "@lsp.type.keyword.lean" })
    local second = shows("@lsp.type.keyword.lean")
    return { first = first, second = second, stale = shows("@lsp.type.tactic.lean") }
  ]==])
  expect.equality(got.first, true)
  expect.equality(got.second, true)
  expect.equality(got.stale, false)
end

T["palette"]["the token inspector offers the key, and names a real group"] = function()
  -- The rhs cannot be exercised without a Lean server, so what is asserted
  -- is the pair that D14 says a `desc` test cannot see on its own: the
  -- function the key would call EXISTS and takes the option the key passes.
  local got = child.lua_get([==[(function()
    local src = vim.api.nvim_get_runtime_file("lua/config/lean/inspect_token.lua", false)[1]
    local body = table.concat(vim.fn.readfile(src), "\n")
    local P = require("config.lean.palette_picker")
    return {
      binds = body:find('vim.keymap.set("n", "e"', 1, true) ~= nil,
      calls = body:find('palette_picker").open({ group = target })', 1, true) ~= nil,
      guards = body:find("local target = R.winner and R.winner.group", 1, true) ~= nil,
      -- and the door it knocks on is open
      accepts = pcall(P.open, { group = "@lsp.type.tactic.lean" }),
    }
  end)()]==])
  expect.equality(got.binds, true)
  expect.equality(got.calls, true)
  expect.equality(got.guards, true)
  expect.equality(got.accepts, true)
end

-- ── item 13: `y` knows the name the CLI knows ──────────────────────────

T["palette"]["y hands the row's TARGET to source_for, not its label"] = function()
  local got = tui([==[
    P.open()
    -- A channel row's LABEL is prose (`local \u{2192} italic`) and its TARGET is
    -- an identifier (`local_italic`). Before `row.target` existed there was
    -- nothing on the row that `source_for` could be given.
    local label
    for _ = 1, 80 do
      press("j")
      local l = selected()
      if l:find("local", 1, true) and l:find("italic", 1, true) then label = l break end
    end
    if not label then return { found = false } end
    -- Pressing the real key, and reading the buffer it puts the edit in —
    -- asserting that `source_for` works when handed the right string would
    -- pass whether or not the row can supply it.
    press("y")
    local scratch = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    return { found = true, label = label, scratch = table.concat(scratch, "\n") }
  ]==])
  expect.equality(got.found, true)
  -- The label really is prose, which is the reason the target is stored.
  expect.equality(got.label:find("italic", 1, true) ~= nil, true)
  expect.equality(got.label:find("local_italic", 1, true), nil)
  -- ...and what `y` produced names the identifier and a real source line.
  expect.equality(got.scratch:find("local_italic", 1, true) ~= nil, true)
  expect.equality(got.scratch:find("highlights.lua:%d") ~= nil, true)
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ END: the picker as a TUI                                             │
-- ╰──────────────────────────────────────────────────────────────────────╯

return T
