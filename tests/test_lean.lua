-- tests/test_lean.lua — Lean 4 filetype support.
--
-- WHY THIS FILE EXISTS SEPARATELY, rather than a probe.lean entry in
-- tests/test_invariants.lua's PROBES list:
--
-- Opening a Lean buffer loads lean.nvim, which does two things the shared
-- invariants child cannot survive. It sets the GLOBAL 'breakat'
-- (" \t!@*-+;:,./?" -> " \t,="), which the option-snapshot case correctly
-- flags as a leak; and its autoopened infoview window carries 'winfixbuf',
-- so the next vim.cmd.edit() aborts with E1513 and takes the remaining
-- invariants cases with it. Both are lean.nvim's behaviour, not this
-- config's. Quarantining Lean in its own child keeps that blast radius to
-- this file while still testing the filetype.
--
-- The deprecation case below is the reason the file was written: lean.nvim
-- deprecated require("lean").setup in favour of vim.g.lean_config, and
-- because no test ever opened a .lean buffer, the config warned on every
-- Lean file for a while without anything catching it.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()
-- A second child for T["global option leaks"], which must snapshot the global
-- options BEFORE any Lean buffer exists.
local leak_child = MiniTest.new_child_neovim()
local tmp_dir

T["lean"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      -- No lakefile here on purpose: lean.nvim finds no project and starts
      -- no language server, so these cases test the config, not the server.
      vim.fn.writefile({
        "import Mathlib.Data.Real.Basic",
        "def dvalue : Nat := 3",
        "theorem tvalue (p : Prop) : p ∨ p → p := id",
        "  rw [← mul_assoc, Nat.succ_le_of_lt]",
      }, tmp_dir .. "/probe.lean")
      child.lua(string.format("vim.cmd.edit(%q)", tmp_dir .. "/probe.lean"))
      child.lua("vim.wait(2000)")
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

T["lean"]["filetype is detected"] = function()
  expect.equality(child.lua_get("vim.bo.filetype"), "lean")
end

-- The regression this file was created for. init.lua's vim.deprecate override
-- silences plugin-originated warnings, and snacks.notifier owns vim.notify, so
-- scan both sinks — same approach as test_invariants.
--
-- VACUITY: this asserted `hits == {}` with no sentinel, which is a pass both
-- when nothing is deprecated and when the DETECTOR is broken — if
-- Snacks.notifier.get_history() throws (it is wrapped in pcall) and :messages
-- happens to be clean, an empty result proves nothing at all. Inject a sentinel
-- and require exactly it, so the case fails unless the scan is actually
-- reaching the sink it claims to read. Same shape as test_invariants.lua.
T["lean"]["no deprecation warnings from opening a Lean buffer"] = function()
  local hits = child.lua_get([[(function()
    vim.notify("SENTINEL_fn is deprecated", vim.log.levels.WARN)
    local out = {}
    local msgs = vim.fn.execute("messages"):lower()
    if msgs:find("deprecat", 1, true) then
      table.insert(out, "messages")
    end
    local ok, hist = pcall(function() return Snacks.notifier.get_history() end)
    if ok and hist then
      for _, n in ipairs(hist) do
        local text = tostring(n.msg or ""):lower()
        if text:find("deprecat", 1, true) then
          table.insert(out, text:sub(1, 100))
        end
      end
    end
    return out
  end)()]])
  expect.equality(hits, { "sentinel_fn is deprecated" })
end

-- Configuring through lazy's `opts` is what triggered the deprecation: it makes
-- lazy call require("lean").setup(). The config must reach lean.nvim via the
-- global instead, and must actually be populated.
T["lean"]["configured via vim.g.lean_config, not setup()"] = function()
  expect.equality(child.lua_get("type(vim.g.lean_config)"), "table")
  expect.equality(child.lua_get("vim.g.lean_config.mappings"), true)
  expect.equality(child.lua_get("vim.g.lean_config.infoview.width"), 55)
  -- Pinned, because lean.nvim's default "auto" picks by aspect ratio and
  -- lands on a horizontal split in an ordinary ~100x50 window.
  expect.equality(child.lua_get("vim.g.lean_config.infoview.orientation"), "vertical")
end

-- textwidth=100 alone hard-wraps Lean terms mid-expression, because the global
-- formatoptions is "tcqj". The ftplugin must drop `t`.
T["lean"]["ftplugin: mathlib style without auto-wrap"] = function()
  expect.equality(child.lua_get("vim.bo.textwidth"), 100)
  expect.equality(child.lua_get("vim.bo.shiftwidth"), 2)
  expect.equality(child.lua_get("vim.bo.expandtab"), true)
  expect.equality(child.lua_get([[vim.bo.formatoptions:find("t") ~= nil]]), false)
  -- textwidth governs `gq` only. No colorcolumn: 100 is mathlib's contribution
  -- guideline, not a rule worth a permanent ruler competing with the infoview
  -- for width.
  expect.equality(child.lua_get("vim.wo.colorcolumn"), "")
end

T["lean"]["ftplugin: apostrophe is a keyword character"] = function()
  expect.equality(
    child.lua_get([[vim.tbl_contains(vim.opt_local.iskeyword:get(), "'")]]),
    true
  )
end

-- Buffer-local because mini.operators owns the `gr` prefix globally, shadowing
-- Neovim's built-in grn/gra/grr LSP maps.
T["lean"]["config-owned buffer-local maps exist"] = new_set({
  parametrize = { { "\\?" }, { "\\n" }, { "\\a" }, { "\\f" }, { "\\b" }, { "\\h" } },
}, {
  test = function(lhs)
    local found = child.lua_get(string.format(
      [[(function()
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
          if m.lhs == %q then return true end
        end
        return false
      end)()]],
      lhs
    ))
    expect.equality(found, true)
  end,
})

-- ── LSP folding ────────────────────────────────────────────────────────
-- This child has no language server, so what is under test is the WIRING:
-- the options are set, they are set at the right scope, and they do not
-- leak. That vim.lsp.foldexpr() then produces real folds was checked
-- against a live server in a pty-hosted TUI (see the commit).
T["lean"]["ftplugin: folds come from the language server"] = function()
  expect.equality(child.lua_get("vim.wo.foldmethod"), "expr")
  expect.equality(child.lua_get("vim.wo.foldexpr"), "v:lua.vim.lsp.foldexpr()")
  -- Every fold open on arrival. 'foldlevelstart' would be the idiomatic knob
  -- but is global-only, which this file may not touch.
  expect.equality(child.lua_get("vim.wo.foldlevel"), 99)
end

-- The leak this guards is one scope narrower than test_invariants' global
-- snapshot, which cannot cover Lean at all (see the PROBES comment there):
-- 'foldmethod' and friends are WINDOW options, so a plain :setlocal would
-- follow the window into the next buffer opened in it.
T["lean"]["ftplugin: fold settings are buffer-local, not window- or global"] = function()
  expect.equality(child.lua_get("vim.go.foldmethod"), "manual")
  expect.equality(child.lua_get("vim.go.foldexpr"), "0")

  local probe_lua = tmp_dir .. "/foldprobe.lua"
  vim.fn.writefile({ "return 1" }, probe_lua)
  -- Make sure we are in the window showing the Lean buffer and not the
  -- autoopened infoview, whose 'winfixbuf' would abort the :edit with E1513.
  child.lua([[
    local buf = vim.fn.bufnr("probe.lean")
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        vim.api.nvim_set_current_win(w)
      end
    end
  ]])
  child.lua(string.format("vim.cmd.edit(%q)", probe_lua))
  expect.equality(child.lua_get("vim.bo.filetype"), "lua")
  expect.no_equality(child.lua_get("vim.wo.foldexpr"), "v:lua.vim.lsp.foldexpr()")
  -- ...and back, so the remaining cases still see a Lean buffer.
  child.lua(string.format("vim.cmd.edit(%q)", tmp_dir .. "/probe.lean"))
  expect.equality(child.lua_get("vim.bo.filetype"), "lean")
  expect.equality(child.lua_get("vim.wo.foldexpr"), "v:lua.vim.lsp.foldexpr()")
end

-- ── inlay hints ────────────────────────────────────────────────────────
-- Lean's are auto-bound implicits, which is the signal that colouring
-- global constants costs us (see decisions.md / state.md DEF-3), so they
-- are on by default. is_enabled is a buffer-state flag set by
-- vim.lsp.inlay_hint.enable regardless of whether a client ever attaches,
-- so this is meaningful without a server.
T["lean"]["ftplugin: inlay hints are enabled for the buffer"] = function()
  expect.equality(
    child.lua_get([[vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })]]),
    true
  )
end

-- enable(true) with no filter would set a GLOBAL flag and turn hints on in
-- every loaded buffer; the ftplugin must pass { bufnr = ... }.
T["lean"]["ftplugin: inlay hints are not enabled globally"] = function()
  expect.equality(child.lua_get([[vim.lsp.inlay_hint.is_enabled()]]), false)
end

T["lean"]["\\h toggles inlay hints for this buffer only"] = function()
  local states = child.lua_get([[(function()
    local out = {}
    local b = vim.api.nvim_get_current_buf()
    local other = vim.api.nvim_create_buf(true, true)
    vim.lsp.inlay_hint.enable(true, { bufnr = other })
    local function press()
      vim.api.nvim_feedkeys(vim.keycode("\\h"), "x", false)
    end
    press()
    table.insert(out, vim.lsp.inlay_hint.is_enabled({ bufnr = b }))
    table.insert(out, vim.lsp.inlay_hint.is_enabled({ bufnr = other }))
    press()
    table.insert(out, vim.lsp.inlay_hint.is_enabled({ bufnr = b }))
    vim.api.nvim_buf_delete(other, { force = true })
    return out
  end)()]])
  expect.equality(states, { false, true, true })
end

-- An ftplugin re-runs on every :edit of the same buffer, and this one calls
-- vim.lsp.inlay_hint.enable(true, { bufnr }) unconditionally at the top level.
-- So a toggle the user deliberately made is silently reverted by any :edit,
-- :edit!, or anything that reloads the buffer (a checktime reload after an
-- external write, a `lake build` touching the file). The toggle looks like it
-- works — press \h and the hints go away — and then quietly stops holding.
--
-- Guarded with a buffer-local flag rather than by dropping the default: `b:`
-- variables survive :edit, because :edit reloads a buffer's CONTENTS without
-- destroying the buffer, so "have I already decided about this buffer?" is
-- exactly what they can answer.
T["lean"]["\\h toggle survives the ftplugin re-running on :edit"] = function()
  local states = child.lua_get([[(function()
    -- Be in the window showing the Lean buffer, not the autoopened infoview,
    -- whose 'winfixbuf' would abort the :edit with E1513.
    local buf = vim.fn.bufnr("probe.lean")
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(w) == buf then
        vim.api.nvim_set_current_win(w)
      end
    end
    local out = {}
    -- Establish the default, then turn hints OFF the way a user would.
    vim.lsp.inlay_hint.enable(true, { bufnr = buf })
    vim.api.nvim_feedkeys(vim.keycode("\\h"), "x", false)
    table.insert(out, vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
    -- ...and reload. The ftplugin runs again here.
    vim.cmd.edit({ bang = true })
    table.insert(out, vim.lsp.inlay_hint.is_enabled({ bufnr = buf }))
    return out
  end)()]])
  -- off after the toggle, and STILL off after the reload.
  expect.equality(states, { false, false })
end

T["lean"]["mini.clue trigger is registered for this buffer"] = function()
  expect.equality(
    child.lua_get([[(vim.b.miniclue_config or {}).triggers ~= nil]]),
    true
  )
end

-- A map with no clue is a map nobody finds: `\` opens the hint window and
-- anything missing from it is invisible. Config-owned maps only — lean.nvim's
-- own are listed too but are its to rename.
T["lean"]["config-owned maps have mini.clue entries"] = new_set({
  parametrize = { { "<LocalLeader>?" }, { "<LocalLeader>n" }, { "<LocalLeader>a" },
    { "<LocalLeader>f" }, { "<LocalLeader>b" }, { "<LocalLeader>h" } },
}, {
  test = function(keys)
    local found = child.lua_get(string.format(
      [[(function()
        for _, c in ipairs((vim.b.miniclue_config or {}).clues or {}) do
          if c.keys == %q then return c.desc end
        end
        return false
      end)()]],
      keys
    ))
    expect.equality(type(found), "string")
  end,
})

-- ── experimental client capability ─────────────────────────────────────
-- The patched server gates its rich token legend on this; the point of the
-- test is the MERGE, since lean.nvim ships its own lsp/leanls.lua and
-- plugins/lsp.lua contributes blink.cmp's capabilities via vim.lsp.config("*").
-- All three layers must survive tbl_deep_extend, in both directions.
T["lean"]["leanls advertises experimental.leanRichTokens"] = function()
  expect.equality(
    child.lua_get(
      [[vim.tbl_get(vim.lsp.config["leanls"], "capabilities", "experimental", "leanRichTokens")]]
    ),
    true
  )
end

T["lean"]["adding the capability does not displace lean.nvim's own"] = function()
  expect.equality(
    child.lua_get(
      [[vim.tbl_get(vim.lsp.config["leanls"], "capabilities", "lean", "silentDiagnosticSupport")]]
    ),
    true
  )
  -- blink.cmp's, applied to every server by vim.lsp.config("*").
  expect.equality(
    child.lua_get([[
      vim.tbl_get(vim.lsp.config["leanls"], "capabilities", "textDocument", "completion") ~= nil
    ]]),
    true
  )
end

-- ── the server's token vocabulary ──────────────────────────────────────
-- lua/plugins/themes.lua styles the patched server's semantic tokens by
-- highlight-group NAME: `@lsp.type.<tokenType>.lean`, `@lsp.mod.<modifier>.lean`
-- and `@lsp.typemod.<tokenType>.<modifier>.lean`. Neovim invents those groups
-- from whatever the server actually sends, so a group naming a token type the
-- server does not emit is not an error anywhere — it is simply dead. It shows
-- up in `:highlight` looking exactly like a working one, and the only symptom
-- is that some identifiers are never the colour you asked for.
--
-- THIS IS WHY THE TEST EXISTS: when it was written it found SEVEN dead groups
-- at once. Four (`leanProof`, `leanHypothesis`, `leanProp`, `leanInductive`)
-- named a token vocabulary that had been replaced by the world/tower modifier
-- axes commits earlier, so they had never matched anything. Three more
-- (`leanTactic`, `leanAxiom`, `leanRecursor`) were live until the server
-- dropped its `lean` prefix and died silently at that moment.
--
-- The legend is READ FROM THE SERVER'S OWN ENUM rather than listed here. A
-- hardcoded copy would be the identical bug one level up: it would agree with
-- itself forever while the server moved. Only the two `names` arrays are
-- parsed, because `Watchdog.lean` advertises exactly those as the LSP legend.
local LEAN_LEGEND_SRC = vim.fn.expand("~")
  .. "/ClaudeProjects/leanSetup/lean4-rich-tokens/src/Lean/Data/Lsp/LanguageFeatures.lean"

local function lean_legend()
  local f = io.open(LEAN_LEGEND_SRC, "r")
  -- Fail loudly rather than skipping. A silent skip when the checkout moves
  -- would turn every case below into a vacuous pass, which is the exact
  -- failure mode this file is being hardened against.
  if not f then
    error("patched Lean server source not found: " .. LEAN_LEGEND_SRC)
  end
  local src = f:read("*a")
  f:close()
  local function names(decl)
    local anchor = src:find("def " .. decl .. " : Array String :=", 1, true)
    if not anchor then
      error("no `" .. decl .. "` in " .. LEAN_LEGEND_SRC)
    end
    local open = src:find("#[", anchor, true)
    local close = src:find("]", open, true)
    local out = {}
    for name in src:sub(open, close):gmatch('"([^"]*)"') do
      out[name] = true
    end
    return out
  end
  return names("SemanticTokenType.names"), names("SemanticTokenModifier.names")
end

-- The parser is load-bearing for the two cases below, and a parser that
-- silently matched nothing would make them fail rather than pass — but one
-- that matched the WRONG array would mislead. Pin the entries that must be
-- present under any naming scheme, including across the `lean`-prefix rename.
T["lean"]["token legend parses"] = function()
  local types, mods = lean_legend()
  expect.equality(types["keyword"], true)
  expect.equality(types["variable"], true)
  expect.equality(types["leanSorryLike"], true)
  expect.equality(mods["deprecated"], true)
  expect.equality(mods["defaultLibrary"], true)
  -- The LSP standard set alone is 20-odd of each; the extensions push both
  -- past that. A truncated parse would not clear this.
  expect.equality(vim.tbl_count(types) > 20, true)
  expect.equality(vim.tbl_count(mods) > 20, true)
end

T["lean"]["token legend: every @lsp.*.lean group names a token the server emits"] = function()
  local types, mods = lean_legend()
  local groups = child.lua_get([[(function()
    local out = {}
    for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
      if name:match("^@lsp%..*%.lean$") then
        table.insert(out, name)
      end
    end
    table.sort(out)
    return out
  end)()]])
  -- Non-vacuity guard: if the colorscheme never applied, there would be no
  -- groups at all and the loop below would vacuously find nothing dead.
  expect.equality(#groups >= 10, true)

  local dead = {}
  for _, g in ipairs(groups) do
    -- `@lsp.typemod.<t>.<m>.lean` cannot collide with `@lsp.type.<t>.lean`:
    -- the literal "." after "type" fails against the "m" of "typemod".
    local tmt, tmm = g:match("^@lsp%.typemod%.([^.]+)%.([^.]+)%.lean$")
    local t = g:match("^@lsp%.type%.([^.]+)%.lean$")
    local m = g:match("^@lsp%.mod%.([^.]+)%.lean$")
    if tmt then
      if not types[tmt] or not mods[tmm] then
        table.insert(dead, g)
      end
    elseif t then
      if not types[t] then
        table.insert(dead, g)
      end
    elseif m then
      if not mods[m] then
        table.insert(dead, g)
      end
    end
  end
  expect.equality(dead, {})
end

-- The other half of "this group does nothing": the name is real but the colour
-- is not. Neovim's `@`-group inheritance is not a safety net here — it aborts
-- as soon as a child defines anything of its own (`sg_cleared`) — so a group
-- linked to a cleared or undefined target renders as plain text while looking
-- perfectly configured. `@lsp.type.tactic.lean` links to `@lsp.type.keyword.lean`,
-- which no file in this config defines; it resolves only through Neovim's own
-- fallback chain, and would silently go colourless if that ever stopped.
T["lean"]["token legend: every Lean token group resolves to real attributes"] = function()
  local unstyled = child.lua_get([[(function()
    local out = {}
    for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
      if name:match("^@lsp%..*%.lean$") then
        -- link = false follows the chain to the end.
        if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name, link = false })) then
          table.insert(out, name)
        end
      end
    end
    table.sort(out)
    return out
  end)()]])
  expect.equality(unstyled, {})
end

-- LspInlayHint is styled in the catppuccin overrides (so it survives a
-- colorscheme reload, as with LineNrWrap). catppuccin's stock value is
-- Comment's exact fg, which makes a hint read as a comment; ours must not be.
T["lean"]["LspInlayHint is distinguishable from Comment"] = function()
  local hl = child.lua_get([[(function()
    local hint = vim.api.nvim_get_hl(0, { name = "LspInlayHint", link = false })
    local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
    return { hint = hint.fg or "MISSING", comment = comment.fg or "MISSING" }
  end)()]])
  expect.no_equality(hl.hint, "MISSING")
  expect.no_equality(hl.hint, hl.comment)
end

-- \? reads this at press time; a rename would fail silently into the fallback.
T["lean"]["cheatsheet file exists"] = function()
  local path = H.cfg .. "/lean-cheatsheet.md"
  expect.equality(vim.uv.fs_stat(path) ~= nil, true)
end

-- ── after/syntax/lean.vim ──────────────────────────────────────────────
-- Lemma references are the one part of a proof nothing highlights: leanls
-- sends no semantic token for them and lean.nvim's syntax file has no rule
-- that reaches them. These pin the rule that claims them, and the two
-- exclusions it has to respect. Byte columns are found by search rather than
-- counted, because the probe lines contain multibyte operators.
--
-- NOTE this child has no language server (no lakefile in the temp dir), so
-- what is under test is the SYNTAX layer alone. In a live buffer the locals
-- are painted back over by @lsp.type.variable.lean, which is the whole reason
-- a rule this broad is safe; that half was verified in a pty-hosted TUI.
local function syntax_at(lnum, needle)
  return child.lua_get(string.format(
    [[(function()
      local line = vim.api.nvim_buf_get_lines(0, %d - 1, %d, false)[1] or ""
      local s = line:find(%q, 1, true)
      if not s then return "NOT FOUND" end
      return vim.fn.synIDattr(vim.fn.synID(%d, s, 1), "name")
    end)()]],
    lnum,
    lnum,
    needle,
    lnum
  ))
end

T["lean"]["lemma references are highlighted"] = new_set({
  parametrize = {
    { 4, "mul_assoc", "leanConstant" },
    -- Dotted names stay one item rather than fragmenting at the dot.
    { 4, "Nat.succ_le_of_lt", "leanConstant" },
    -- Declaration names keep lean.nvim's own group: the rule must lose to
    -- leanDeclaration's nextgroup, not shadow it.
    { 2, "dvalue", "leanDeclarationName" },
    { 3, "tvalue", "leanDeclarationName" },
    -- Numbers are defined earlier in lean.nvim's syntax file and would lose
    -- the tie to any rule starting with \w.
    { 2, "3", "leanNumber" },
    -- Module paths were plain text before and stay that way.
    { 1, "Mathlib.Data.Real.Basic", "leanModulePath" },
    -- Untouched: the stock keyword and sort groups, which this file no longer
    -- splits. Colours the user already had must not move.
    { 2, "def", "leanDeclaration" },
    { 3, "theorem", "leanDeclaration" },
    { 3, "Prop", "leanSort" },
    { 3, "∨", "leanOp" },
  },
}, {
  test = function(lnum, needle, group)
    expect.equality(syntax_at(lnum, needle), group)
  end,
})

-- ── infoview background ────────────────────────────────────────────────
-- Pure colour arithmetic, so it runs in the parent against a synthetic
-- colorscheme rather than needing a live infoview window. (Whether the
-- namespace actually lands on the window was checked directly instead: in a
-- pty-hosted TUI the leaninfo window reports a non-global hl namespace whose
-- Normal links to LeanInfoviewNormal.)
T["infoview background"] = new_set({
  hooks = {
    pre_case = function()
      local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
      local func = vim.api.nvim_get_hl(0, { name = "Function" })
      MiniTest.finally(function()
        vim.api.nvim_set_hl(0, "Normal", normal)
        vim.api.nvim_set_hl(0, "Function", func)
        vim.api.nvim_set_hl(0, "LeanInfoviewNormal", {})
      end)
    end,
  },
})

T["infoview background"]["tints the colorscheme background"] = function()
  vim.api.nvim_set_hl(0, "Normal", { fg = 0xcdd6f4, bg = 0x151520 })
  vim.api.nvim_set_hl(0, "Function", { fg = 0x89b4fa })
  dofile(H.cfg .. "/lua/config/lean/infoview_hl.lua").refresh()
  -- 12% of catppuccin mocha's blue mixed into this config's base.
  expect.equality(vim.api.nvim_get_hl(0, { name = "LeanInfoviewNormal" }).bg, 0x23283a)
end

-- A transparent colorscheme has no background to tint, and inventing one would
-- paint over the terminal.
--
-- VACUITY: this used to clear LeanInfoviewNormal and then assert its `bg` was
-- nil. `nvim_get_hl(0, { name = ... })` answers `{}` for an UNDEFINED group
-- exactly as it does for a defined-but-empty one (verified: an undefined group
-- is absent from `nvim_get_hl(0, {})` but still reads back as `{}` by name), so
-- that assertion held whether refresh() declined to tint, tinted nothing
-- because it never ran, or the group name were simply misspelled.
--
-- A SENTINEL bg that must SURVIVE refresh() can only pass if refresh() really
-- looked at the transparent Normal and really declined to write. The
-- membership check pins the other half — that the name exists at all — so a
-- typo cannot pass either.
T["infoview background"]["leaves a transparent scheme alone"] = function()
  vim.api.nvim_set_hl(0, "LeanInfoviewNormal", { bg = 0xabcdef })
  vim.api.nvim_set_hl(0, "Normal", { fg = 0xcdd6f4 })
  dofile(H.cfg .. "/lua/config/lean/infoview_hl.lua").refresh()
  expect.equality(vim.api.nvim_get_hl(0, {})["LeanInfoviewNormal"] ~= nil, true)
  expect.equality(vim.api.nvim_get_hl(0, { name = "LeanInfoviewNormal" }).bg, 0xabcdef)
end

-- ── \b book-page resolution ────────────────────────────────────────────
-- Pure path logic, so it runs against a fixture instead of a real MIL
-- checkout: no network, no browser, and no dependency on ~/LeanCourse
-- existing. Built to mirror MIL's real shape — chapter-per-HTML-page, a
-- solutions/ subdirectory, and a section whose anchor is missing.
T["book"] = new_set()

local function book_fixture()
  local dir = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  vim.fn.mkdir(dir .. "/MIL/C02_Basics/solutions", "p")
  vim.fn.mkdir(dir .. "/html", "p")
  vim.fn.writefile({ "" }, dir .. "/lakefile.toml")
  for _, f in ipairs({
    "/MIL/C02_Basics/S01_Calculating.lean",
    "/MIL/C02_Basics/S09_Missing_Anchor.lean",
    "/MIL/C02_Basics/scratchpad.lean",
    "/MIL/C02_Basics/solutions/Solutions_S01_Calculating.lean",
    "/MIL/Common.lean",
  }) do
    vim.fn.writefile({ "" }, dir .. f)
  end
  vim.fn.writefile(
    { '<section id="basics">', '<section id="calculating">' },
    dir .. "/html/C02_Basics.html"
  )
  return dir
end

T["book"]["resolves section, solutions, fallback and non-sections"] = function()
  local dir = book_fixture()
  local book = dofile(H.cfg .. "/lua/config/lean/book.lua")
  local function target(rel)
    local url, err = book.target(dir .. rel)
    return url and url:gsub(".*/html/", "html/") or ("ERR: " .. tostring(err))
  end

  -- section file -> anchored
  expect.equality(
    target("/MIL/C02_Basics/S01_Calculating.lean"),
    "html/C02_Basics.html#calculating"
  )
  -- solutions live a level deeper but share the section's anchor
  expect.equality(
    target("/MIL/C02_Basics/solutions/Solutions_S01_Calculating.lean"),
    "html/C02_Basics.html#calculating"
  )
  -- derived anchor absent from the page -> chapter page, no dead fragment
  expect.equality(
    target("/MIL/C02_Basics/S09_Missing_Anchor.lean"),
    "html/C02_Basics.html"
  )
  -- not a section at all
  expect.equality(
    target("/MIL/C02_Basics/scratchpad.lean"),
    "html/C02_Basics.html"
  )
  -- outside any chapter directory -> declines, with a reason
  expect.equality(target("/MIL/Common.lean"):match("^ERR:") ~= nil, true)
end

T["book"]["declines quietly when a project has no html build"] = function()
  local dir = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  vim.fn.mkdir(dir .. "/MIL/C01_Intro", "p")
  vim.fn.writefile({ "" }, dir .. "/lakefile.toml")
  vim.fn.writefile({ "" }, dir .. "/MIL/C01_Intro/S01_Thing.lean")
  local book = dofile(H.cfg .. "/lua/config/lean/book.lua")
  local url, err = book.target(dir .. "/MIL/C01_Intro/S01_Thing.lean")
  expect.equality(url, nil)
  expect.equality(err:find("no rendered page") ~= nil, true)
end

-- ── the coverage test_invariants.lua had to give up ────────────────────
-- The PROBES list there deliberately has no probe.lean, because lean.nvim
-- leaks the GLOBAL 'breakat' and the shared invariants child cannot survive it
-- (see the long comment at the top of this file). But "we cannot run the shared
-- check" is not the same as "this filetype gets no check": the leak is
-- MEASURABLE, so it can be pinned instead of skipped.
--
-- Exact-set equality, never a subset test. A subset check ("breakat may
-- change") would pass no matter how many NEW globals a future config change
-- leaked, which is precisely the vacuity this file is being audited for. If
-- lean.nvim stops leaking 'breakat', this fails too — and it should, because
-- the quarantine at the top of this file could then be lifted.
--
-- Its own child, because the snapshot has to be taken BEFORE any Lean buffer
-- is opened and the T["lean"] child opens one in pre_once.
T["global option leaks"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(leak_child)
    end,
    post_once = function()
      leak_child.stop()
    end,
  },
})

T["global option leaks"]["opening a Lean buffer leaks exactly lean.nvim's breakat"] = function()
  local dir = vim.fn.tempname()
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  vim.fn.mkdir(dir, "p")
  -- No lakefile, so no language server starts and this measures the config
  -- and lean.nvim only.
  vim.fn.writefile({ "def x : Nat := 3" }, dir .. "/probe.lean")

  leak_child.lua([[
    _G.__snap = {}
    -- Same exclusions as tests/test_invariants.lua, and for the same reasons:
    -- lazy.nvim mutates rtp/packpath while lazy-loading, and Neovim's own
    -- python ftplugin does `set wildignore+=*.pyc`.
    local skip = { runtimepath = true, packpath = true, wildignore = true }
    for name, info in pairs(vim.api.nvim_get_all_options_info()) do
      if info.scope == "global" and not skip[name] then
        _G.__snap[name] = vim.go[name]
      end
    end
  ]])
  leak_child.lua(string.format("vim.cmd.edit(%q)", dir .. "/probe.lean"))
  leak_child.lua("vim.wait(2000)")

  -- Guard against measuring nothing: if the filetype never resolved, lean.nvim
  -- never loaded and an empty diff would mean the test did not run.
  expect.equality(leak_child.lua_get("vim.bo.filetype"), "lean")

  local changed = leak_child.lua_get([[(function()
    local out = {}
    for name, old in pairs(_G.__snap) do
      if not vim.deep_equal(vim.go[name], old) then
        out[#out + 1] = name
      end
    end
    table.sort(out)
    return out
  end)()]])
  expect.equality(changed, { "breakat" })
end

return T
