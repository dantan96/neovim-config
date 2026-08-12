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
-- A third, for T["snippets"], which must assert against a cold start rather
-- than against whatever the shared child has already pulled in.
local snippet_child = MiniTest.new_child_neovim()
local tmp_dir

T["lean"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      -- No lakefile here on purpose, so nothing is ever elaborated and these
      -- cases test the config rather than the server. NOTE this is not the
      -- same as "no client": measured directly, leanls still attaches to this
      -- buffer and still advertises its full capability set — it simply has
      -- no project to serve. The occurrence-highlighting cases at the bottom
      -- of this file depend on that distinction.
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
  -- A FRACTION, not a column count. lean.nvim's `res_dim` reads < 1 as a
  -- proportion of vim.o.columns and >= 1 as a literal width, so the property
  -- worth pinning is which side of 1 this falls on -- pinning 0.4 exactly
  -- would just re-break on any retune.
  local width = child.lua_get("vim.g.lean_config.infoview.width")
  expect.equality(type(width), "number")
  expect.equality(width > 0 and width < 1, true)
  -- Pinned, because lean.nvim's default "auto" picks by aspect ratio and
  -- lands on a horizontal split in an ordinary ~100x50 window.
  expect.equality(child.lua_get("vim.g.lean_config.infoview.orientation"), "vertical")
end

-- The fraction above is resolved ONCE, when the infoview is created
-- (infoview.lua:400), and the only VimResized handler lean.nvim installs
-- re-renders pin content (tui.lua:1204) without touching the window -- which
-- also carries `winfixwidth`. So without this autocmd the width matches the
-- terminal at startup and then drifts permanently. Verified in a live TUI:
-- with it, 80->120 columns moves the infoview 32->48; without it, the
-- infoview stays at 32 while the code window grows 47->87.
T["lean"]["a VimResized hook re-resolves the infoview's fractional width"] = function()
  local n = child.lua_get([[#vim.api.nvim_get_autocmds({
    group = "LeanInfoviewWidth", event = "VimResized" })]])
  expect.equality(n, 1)
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

-- Buffer-local aliases for the LSP actions. These began as workarounds for
-- mini.operators DELETING Neovim's built-in grn/gra/grr (see the gr* cases
-- below, which pin the fix); they are kept because `\`-prefixed maps are
-- where every other Lean action lives.
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
-- This child has no PROJECT (no lakefile), so no folding ranges ever arrive
-- and what is under test is the WIRING: the options are set, they are set at
-- the right scope, and they do not leak. That vim.lsp.foldexpr() then produces
-- real folds was checked against a live server in a pty-hosted TUI (see the
-- commit).
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

-- ── the rich/standard switch ───────────────────────────────────────────
-- lua/config/lean/rich_tokens.lua. Three settings, and the ADVERTISEMENT is
-- the half that can be tested without a server: `nil` and `true` both put the
-- capability on the wire (detection is impossible otherwise — the patched
-- server withholds the rich legend from a client that did not ask), and only
-- an explicit `false` withholds it.
--
-- Withholding must OMIT the key rather than send `leanRichTokens = false`.
-- The server's gate is written against absence, and a `false` on the wire is a
-- different claim; the deep-merge makes that easy to get wrong, since setting
-- the key to `false` in after/lsp/leanls.lua would look like it worked.
T["lean"]["rich tokens: the capability tracks vim.g.lean_rich_tokens"] = new_set({
  parametrize = {
    { "nil", true }, -- auto: ask, then look at what came back
    { "true", true }, -- forced on: same wire, plus a warning if it is not there
    -- Forced off: the key is ABSENT, not false. vim.NIL because a nil crossing
    -- the child RPC boundary arrives as vim.NIL, and the distinction between
    -- "absent" and "false" is the whole assertion.
    { "false", vim.NIL },
  },
}, {
  test = function(setting, expected)
    -- Re-resolving is the point: the value is recomputed by loadfile() on
    -- every resolution, and disabling the server is what drops the cache.
    local got = child.lua_get(string.format(
      [[(function()
        vim.g.lean_rich_tokens = %s
        vim.lsp.enable("leanls", false)
        vim.lsp.config("leanls", {})
        return vim.tbl_get(
          vim.lsp.config["leanls"], "capabilities", "experimental", "leanRichTokens"
        )
      end)()]],
      setting
    ))
    expect.equality(got, expected)
    -- Re-ENABLE, not just reset the config. `vim.lsp.enable("leanls", false)`
    -- above is what drops the cached resolution, but leaving it disabled
    -- silently prevents leanls attaching for the rest of this shared child —
    -- which broke "a real Lean buffer is armed" further down the file, a case
    -- in a different feature area that looked unrelated.
    child.lua([[vim.g.lean_rich_tokens = nil; vim.lsp.config("leanls", {})
      vim.lsp.enable("leanls", true)]])
  end,
})

-- The module's own view of the same three settings, which is what every
-- consumer reads. `enabled()` is deliberately NOT "the user asked for rich":
-- forcing rich against a stock server cannot conjure the tokens, so with no
-- rich legend attached it stays false in all three settings.
T["lean"]["rich tokens: advertise() and enabled() agree with the setting"] = function()
  local got = child.lua_get([[(function()
    local m = require("config.lean.rich_tokens")
    local out = {}
    -- Spelled out rather than `and`/`or`: `x and false or nil` is nil, which
    -- would silently test "auto" three times.
    for _, v in ipairs({ "auto", "on", "off" }) do
      if v == "auto" then
        vim.g.lean_rich_tokens = nil
      else
        vim.g.lean_rich_tokens = (v == "on")
      end
      -- tostring() on purpose: a nil-valued field does not survive the RPC
      -- round trip as a key, so `override = nil` would be indistinguishable
      -- from a typo'd field name.
      table.insert(out, {
        override = tostring(m.override()),
        advertise = m.advertise(),
        -- No leanls client in this child, so nothing rich is attached.
        enabled = m.enabled(),
      })
    end
    vim.g.lean_rich_tokens = nil
    return out
  end)()]])
  expect.equality(got, {
    { override = "nil", advertise = true, enabled = false },
    { override = "true", advertise = true, enabled = false },
    { override = "false", advertise = false, enabled = false },
  })
end

T["lean"]["rich tokens: :LeanRichTokens exists and takes the four words"] = function()
  expect.equality(H.cmd_exists(child, "LeanRichTokens"), true)
  expect.equality(
    child.lua_get([[require("config.lean.rich_tokens").setup ~= nil]]),
    true
  )
  local words = child.lua_get([[vim.fn.getcompletion("LeanRichTokens ", "cmdline")]])
  table.sort(words)
  expect.equality(words, { "auto", "off", "on", "status", "toggle" })
end

-- `status` must report BOTH halves — which toolchain elan resolved, and what
-- the legend actually contains — because those can disagree, and the
-- disagreement is the thing a user needs to see.
T["lean"]["rich tokens: status reports toolchain and legend separately"] = function()
  local text = child.lua_get([[
    table.concat(require("config.lean.rich_tokens").status_lines(), "\n")
  ]])
  for _, needle in ipairs({
    "mode in effect",
    "requested",
    -- Half one: elan's answer.
    "active toolchain",
    "project root",
    -- Half two: the wire's answer.
    "legend (the server decides",
    -- The distinction the command exists to draw: a mode change restarts the
    -- server, a toolchain change is elan's and is NOT what this command does.
    "Changing MODE",
    "Changing TOOLCHAIN",
    "elan override set",
  }) do
    expect.equality({ needle, text:find(needle, 1, true) ~= nil }, { needle, true })
  end
end

-- Whether a client is attached is not a fixed property of this child — leanls
-- attaches to the temp buffer even with no lakefile (see the top of this file)
-- and does not attach on a machine with no Lean. Both are fine; what must not
-- happen is `status` erroring, or claiming a legend it never saw.
T["lean"]["rich tokens: status describes the legend it actually has"] = function()
  local got = child.lua_get([[(function()
    local m = require("config.lean.rich_tokens")
    local text = table.concat(m.status_lines(), "\n")
    return {
      attached = #m.clients() > 0,
      says_none = text:find("no leanls client attached", 1, true) ~= nil,
      says_size = text:find("legend size", 1, true) ~= nil,
    }
  end)()]])
  -- Exactly one of the two branches, and the right one.
  expect.equality(got.says_none, not got.attached)
  expect.equality(got.says_size, got.attached)
end

-- ── the warning, and the nil/false trap under it ───────────────────────
-- diagnose() takes a client and decides whether to complain, so it can be
-- exercised with a plain table carrying a legend — no server, no toolchain.
--
-- THIS CASE EXISTS BECAUSE OF A REAL BUG. `local rich = client and
-- legend_is_rich(client) or nil` reads fine and is wrong: Lua's `and`/`or`
-- collapses a legitimate `false` to nil, so a STOCK legend — the only input
-- the warning fires on — came out as "no legend at all" and the forced-on
-- warning could never trigger. Nothing failed; the warning was simply never
-- raised. Caught by running against a stock toolchain and reading
-- `legend_rich=nil` where it had to say `false`.
local FAKE_CLIENT = [[(function(mods)
  return {
    id = 4242,
    config = { capabilities = { experimental = { leanRichTokens = true } } },
    server_capabilities = {
      semanticTokensProvider = {
        legend = { tokenTypes = { "keyword" }, tokenModifiers = mods },
      },
    },
  }
end)]]

T["lean"]["rich tokens: a stock legend reads as false, not as absent"] = function()
  local got = child.lua_get(([[(function()
    local m = require("config.lean.rich_tokens")
    local stock = %s({ "declaration", "deprecated" })
    local rich  = %s({ "declaration", "propWorld" })
    return {
      stock = tostring(m.legend_is_rich(stock)),
      rich = tostring(m.legend_is_rich(rich)),
      none = tostring(m.legend_is_rich({ server_capabilities = {} })),
    }
  end)()]]):format(FAKE_CLIENT, FAKE_CLIENT))
  -- Three distinct answers, and the middle one is the one that got lost.
  expect.equality(got, { stock = "false", rich = "true", none = "nil" })
end

T["lean"]["rich tokens: forced on warns against a stock legend"] = function()
  local got = child.lua_get(([[(function()
    local m = require("config.lean.rich_tokens")
    local out = {}
    local stock = %s({ "declaration", "deprecated" })

    vim.g.lean_rich_tokens = true
    out.forced_on = vim.deepcopy(m.diagnose(stock))
    -- Second look at the SAME client: still a mismatch, but do not re-notify.
    out.again = vim.deepcopy(m.diagnose(stock))

    -- Auto against the same stock legend is not a mismatch and must be silent.
    vim.g.lean_rich_tokens = nil
    out.auto = vim.deepcopy(m.diagnose(%s({ "declaration" })))

    vim.g.lean_rich_tokens = nil
    return out
  end)()]]):format(FAKE_CLIENT, FAKE_CLIENT))

  expect.equality(got.forced_on.mode, "standard")
  expect.equality(got.forced_on.legend_rich, false)
  expect.equality(got.forced_on.warned, true)
  expect.equality(got.forced_on.notified, true)
  -- The mismatch persists; the message does not repeat.
  expect.equality(got.again.warned, true)
  expect.equality(got.again.notified, false)
  -- Auto detects standard and says nothing at all.
  expect.equality(got.auto.mode, "standard")
  expect.equality(got.auto.warned, false)
  expect.equality(got.auto.notified, false)
end

-- Reading `elan show` rather than lean-toolchain: the file is only one of the
-- four things elan consults. Skipped rather than failed where elan is absent,
-- since this config is used on machines with no Lean at all.
T["lean"]["rich tokens: the toolchain comes from elan"] = function()
  if vim.fn.executable("elan") == 0 then
    MiniTest.skip("elan is not on PATH; cannot check toolchain resolution")
  end
  local got = child.lua_get(
    [[require("config.lean.rich_tokens").toolchain(vim.fn.expand("~"))]]
  )
  expect.equality(type(got), "string")
  expect.no_equality(got, "")
  -- `elan show`'s active line always names a toolchain; "unknown (…)" is the
  -- module's own fallback and means the parse broke.
  expect.equality(got:find("^unknown") == nil, true)
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
--
-- ── the checkout this needs, and what happens without it ──────────────────
-- Reading the enum means reading the patched server's SOURCE, which lives
-- outside this repo. That checkout is on the machine this branch was written
-- on and on no other; this config is pushed and used elsewhere.
--
-- So the two cases that parse it SKIP, loudly, rather than fail — but they
-- skip from INSIDE the case body, via MiniTest.skip(). Guarding at file load
-- would drop them from the collection entirely, and a case that is not there
-- is indistinguishable from a case that passed, which is the precise failure
-- mode this whole section exists to prevent. A skipped case reports as `O`
-- (pass with notes) and its reason is printed under "Fails and Notes", so the
-- suite says out loud what it could not check and why.
--
-- Everything else in this file — including the sibling case asserting that
-- every `@lsp.*.lean` group resolves to real attributes — is independent of
-- the checkout and still runs.
local LEAN_LEGEND_SRC = vim.fn.expand("~")
  .. "/ClaudeProjects/leanSetup/lean4-rich-tokens/src/Lean/Data/Lsp/LanguageFeatures.lean"

--- Skip the current case unless the patched server's source is here.
--- Call from a case body; MiniTest.skip() is implemented as a thrown error.
local function need_legend_src()
  if not vim.uv.fs_stat(LEAN_LEGEND_SRC) then
    MiniTest.skip(
      "SKIPPED: needs the patched Lean server checkout at "
        .. LEAN_LEGEND_SRC
        .. " — the token legend is read from the server's own enum and there is "
        .. "nothing to read it from here. This case was NOT run; it did not pass."
    )
  end
end

local function lean_legend()
  local f = io.open(LEAN_LEGEND_SRC, "r")
  -- Still an error, not a skip: need_legend_src() already established the file
  -- is there, so failing to open it now is a real fault (permissions, a race),
  -- not an absent checkout.
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
  need_legend_src()
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
  need_legend_src()
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
-- perfectly configured. `@lsp.type.tactic.lean` used to link to
-- `@lsp.type.keyword.lean`, which resolves only through Neovim's own fallback
-- chain and would have gone colourless if that ever stopped; it now carries
-- its own colour, and the keyword group is pinned. The sweep stays: the next
-- group added by link is the one this catches.
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

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ BEGIN: Lean colour design (palette synthesis + the inheritance trap) │
-- ╰──────────────────────────────────────────────────────────────────────╯
-- Everything between this banner and the matching END banner was added by
-- the colour-design pass and is self-contained.
--
-- Neither of the two legend cases above can see the bug this block exists
-- for. "names a token the server emits" passes for a group with the WRONG
-- colour, and "resolves to real attributes" passes for a group that
-- inherited someone else's. The failure is specifically:
--
--   catppuccin defines the language-agnostic `@lsp.type.enum`; Neovim's
--   fallback strips `.lean` from the right (M3); so an undefined
--   `@lsp.type.enum.lean` silently becomes catppuccin's yellow, and every
--   `Nat`, `List` and `True` changes colour the day the server learns to
--   emit `enum`. That is what happened, and it is what D6 forbids.
--
-- Pinning the four names is the fix; this is the tripwire. Any future
-- standard LSP token name the server starts emitting belongs in this list.
T["lean"]["standard token names are pinned, not inherited from catppuccin"] = function()
  local got = child.lua_get([[(function()
    local out = {}
    -- `function` is the reference: it is what after/syntax/lean.vim's
    -- leanConstant rule resolves to, i.e. the colour globals had BEFORE the
    -- server started tokenising them.
    local ref = vim.api.nvim_get_hl(0, { name = "Function", link = false }).fg
    for _, t in ipairs({ "enum", "property", "theorem", "opaque",
                         "struct", "enumMember", "function", "class",
                         "axiom", "recursor" }) do
      local g = "@lsp.type." .. t .. ".lean"
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      -- Was: "is it the same colour as Function?". The fall-through layer now
    -- takes each kind's own widened-grid colour, so uniformity is no longer
    -- the property worth asserting -- BEING PINNED AT ALL is. An unpinned
    -- group is the actual bug (catppuccin silently owns it).
    out[t] = h.fg and string.format("#%06x", h.fg) or "nil"
    end
    out._ref = ref and string.format("#%06x", ref) or "nil"
    return out
  end)()]])
  -- Non-vacuity: if the colorscheme never applied, `ref` would be nil and
  -- every comparison below would be nil == nil.
  expect.no_equality(got._ref, "nil")
  for _, t in ipairs({ "enum", "property", "theorem", "opaque",
                       "struct", "enumMember", "function", "class",
                       "axiom", "recursor" }) do
    expect.no_equality({ t, got[t] }, { t, "nil" })
  end
end

-- The same trap, stated as the general rule and swept over EVERY group
-- catppuccin could leak from — types AND typemods, which is where the first
-- version of this test was too narrow. `@lsp.typemod.function.defaultLibrary`
-- is peach and sits at priority 127, above the type mark at 125, so it
-- silently recoloured every imported `def` (`Nat.factorial`, `Nat.Prime`)
-- while `@lsp.type.function.lean` looked correctly pinned.
--
-- Method: enumerate the language-agnostic `@lsp.*` groups that are actually
-- defined (25 of them, all catppuccin's), keep the ones whose name Lean's
-- legend can produce, and require each to be pinned in themes.lua — or
-- named in EXEMPT with the reason it cannot arise.
--
-- HONEST LIMIT OF THIS TEST: an EXEMPT entry claims "the classifier never
-- emits this token type", which was established by reading the tokens off a
-- live server, and the test cannot re-establish it. What the test does catch
-- is the case that actually happens — someone teaches the server a new
-- standard name and does not pin a colour for it — because a name that is
-- neither pinned nor exempt fails here.
T["lean"]["no Lean token group inherits a colour from a language-agnostic group"] = function()
  local types, mods = lean_legend()
  -- Token types Lean's legend contains but the classifier has never been
  -- observed to emit. Checked against a live patched server over
  -- TokenProbe.lean and two MIL files; every one of these is a standard LSP
  -- name kept in the enum for legend compatibility (NAMES.md).
  local EXEMPT = {
    ["@lsp.type.comment"] = "comments are the syntax layer's; no token is sent",
    ["@lsp.type.decorator"] = "never emitted",
    ["@lsp.type.event"] = "never emitted",
    ["@lsp.type.interface"] = "never emitted; a Lean class is `class`",
    ["@lsp.type.macro"] = "never emitted",
    ["@lsp.type.method"] = "never emitted; everything is `function`",
    ["@lsp.type.modifier"] = "never emitted",
    ["@lsp.type.namespace"] = "module paths are leanModulePath, a syntax rule",
    ["@lsp.type.number"] = "literals are leanNumber, a syntax rule",
    ["@lsp.type.operator"] = "never emitted; notation atoms come as `keyword`",
    ["@lsp.type.parameter"] = "never emitted; every local is `variable`",
    ["@lsp.type.regexp"] = "never emitted",
    ["@lsp.type.string"] = "string literals are the syntax layer's",
  }
  local unpinned = child.lua_get([[(function(types, mods, exempt)
    local out = {}
    for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
      if name:match("^@lsp%.") and not name:match("%.lean$") then
        local h = vim.api.nvim_get_hl(0, { name = name, link = false })
        if not vim.tbl_isempty(h) and not exempt[name] then
          -- Can Lean's legend produce this name at all?
          local reachable = false
          local t = name:match("^@lsp%.type%.(.+)$")
          local m = name:match("^@lsp%.mod%.(.+)$")
          local tmt, tmm = name:match("^@lsp%.typemod%.([^.]+)%.(.+)$")
          if t then reachable = types[t] == true
          elseif m then reachable = mods[m] == true
          elseif tmt then reachable = types[tmt] == true and mods[tmm] == true end
          if reachable then
            -- Pinned means: WE defined the `.lean` group, so no fallback runs.
            if vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name .. ".lean" })) then
              table.insert(out, name)
            end
          end
        end
      end
    end
    table.sort(out)
    return out
  end)(...)]], { types, mods, EXEMPT })
  -- Non-vacuity: the sweep must actually be seeing catppuccin's groups. If
  -- the colorscheme never applied there would be nothing to leak from and
  -- an empty result would prove nothing.
  local agnostic_count = child.lua_get([[(function()
    local n = 0
    for name, _ in pairs(vim.api.nvim_get_hl(0, {})) do
      if name:match("^@lsp%.") and not name:match("%.lean$") then
        if not vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = name, link = false })) then
          n = n + 1
        end
      end
    end
    return n
  end)()]])
  expect.equality(agnostic_count >= 20, true)
  expect.equality(unpinned, {})
end

-- ── the synthesis module ───────────────────────────────────────────────
-- lua/config/lean/highlights.lua turns a token's (type, modifier-set) into
-- ONE merged highlight group, because Neovim never generates
-- modifier × modifier and because a partial child definition kills
-- inheritance (M3's caveat: the guard is `sg_cleared`, so `@a.b = {bold}`
-- under `@a = {fg green}` renders bold and COLOURLESS). The module is
-- therefore required to emit COMPLETE specs, never deltas.
--
-- These are pure-function cases ON PURPOSE. A case that tried to prove a
-- colour lands on a screen cell would be vacuous here — headless Neovim
-- applies no semantic tokens at all (M5), so it would assert nothing while
-- looking like end-to-end coverage, which is the exact failure mode the
-- hardening pass was hunting. Live verification is a real TUI in a real
-- window: docs/lean-highlighting/tools/hl_cells.sh in the leanSetup repo,
-- reading `nvim__inspect_cell`.
--
-- `dofile` rather than `require` so each case gets a fresh module instance
-- and cannot be influenced by the setup() the config already ran.
local HLMOD = H.cfg .. "/lua/config/lean/highlights.lua"
local function hl(body)
  return child.lua_get(
    ("(function() local M = dofile(%q) %s end)()"):format(HLMOD, body)
  )
end

-- Mechanic 1, stated as a test: no group may rely on inheritance for its
-- colour, because inheritance aborts the moment a child sets anything.
T["lean"]["highlights: every synthesised group carries its own fg"] = function()
  local bad = hl([[
    M.setup()
    -- Exercise the lazily-built variants too, not just the eager grid.
    M.group("variable", { propWorld = true, element = true, ["local"] = true })
    M.group("theorem", { propWorld = true, element = true, simp = true })
    M.group("axiom", { dataWorld = true, element = true })
    M.group("variable", { polyWorld = true, sort = true, autoImplicit = true, ["local"] = true })
    local out = {}
    for name, spec in pairs(M._specs()) do
      if not spec.fg then table.insert(out, name) end
    end
    table.sort(out)
    return out
  ]])
  expect.equality(bad, {})
end

-- The grid is the whole point of the module: world × level is the pair
-- Neovim cannot express, and it is what `leanProof` / `leanHypothesis` /
-- `leanProp` used to mean before they became modifier pairs. Eight of the
-- nine cells are observable in a single 106-line probe against the live
-- server; the Mathlib census (M12) has all nine.
T["lean"]["highlights: the world x level grid is complete"] = function()
  local missing = hl([[
    M.setup()
    local specs = M._specs()
    local out = {}
    for _, w in ipairs({ "prop", "data", "poly" }) do
      if not specs["@lean." .. w] then table.insert(out, "@lean." .. w) end
      for _, l in ipairs({ "element", "sort", "former" }) do
        local n = "@lean." .. w .. "." .. l
        if not specs[n] then table.insert(out, n) end
      end
    end
    return out
  ]])
  expect.equality(missing, {})
end

-- THE CASE THE PALETTE EXISTS FOR. In
--   theorem two_le {m : ℕ} (h0 : m ≠ 0) (h1 : m ≠ 1) : 2 ≤ m
-- `m`, `h0` and `h1` are all `variable` + `local` + `element` and differ
-- ONLY in world — and today all three render as `Identifier`, #f2cdcd,
-- three characters apart. That is the most confusable thing in real Lean
-- and it is where the contrast is spent. Also pinned: a data local against
-- a data SORT, the other binder-list confusion (`(a : G)` vs `{G : Type*}`).
--
-- THE EXACT HEXES ARE PINNED HERE ON PURPOSE. Everywhere else the palette
-- is asserted structurally, so that a recolour is one edit; this case is the
-- one Dan judged the whole design against, and if `h0`, `m` and `G` ever
-- collapse onto one colour again it must fail loudly and by name rather
-- than by three groups happening to be non-nil.
T["lean"]["highlights: hypothesis, datum and type differ from each other"] = function()
  local got = hl([[
    M.setup()
    local function fg(g)
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      return h.fg and string.format("#%06x", h.fg) or "nil"
    end
    local hyp  = M.group("variable", { propWorld = true, element = true, ["local"] = true })
    local dat  = M.group("variable", { dataWorld = true, element = true, ["local"] = true })
    local srt  = M.group("variable", { dataWorld = true, sort = true, ["local"] = true })
    local poly = M.group("variable", { polyWorld = true, element = true, ["local"] = true })
    return {
      names = { hyp = hyp, dat = dat, srt = srt, poly = poly },
      fgs   = { hyp = fg(hyp), dat = fg(dat), srt = fg(srt), poly = fg(poly) },
      -- A cited lemma is the same CELL as a hypothesis. It used to share the
      -- hue and differ only in slant; the rebuild splits the hue too,
      -- because those two together are most of what is on a screen of
      -- Mathlib and one blue for both is what read as monochrome.
      lemma = (function()
        local g = M.group("theorem", { propWorld = true, element = true })
        local h = vim.api.nvim_get_hl(0, { name = g, link = false })
        return { fg = fg(g), italic = h.italic or false }
      end)(),
      hyp_italic = vim.api.nvim_get_hl(0, { name = hyp, link = false }).italic or false,
    }
  ]])
  -- Non-vacuity: every group must actually have resolved to a colour.
  for _, k in ipairs({ "hyp", "dat", "srt", "poly" }) do
    expect.no_equality(got.fgs[k], "nil")
  end
  -- THE THREE IN `two_le`'s BINDER LIST, by name and by hex.
  -- RETUNED 2026-08-13: the loud pinks moved off the two commonest cells and
  -- onto the rare ones. A hypothesis is the single most frequent identifier
  -- in a proof and now takes a CALM pink; magenta went to the type variable,
  -- which Dan named for it.
  expect.equality(got.fgs.hyp, "#f5c2e7") -- h0, h1 — pink, calm
  expect.equality(got.fgs.dat, "#a6e3a1") -- m     — green
  expect.equality(got.fgs.srt, "#ff5fff") -- G, α  — magenta
  -- ...and pairwise distinct, stated separately so a future recolour that
  -- moves two of them onto one hue fails here and not only on the hexes.
  expect.no_equality(got.fgs.hyp, got.fgs.dat)
  expect.no_equality(got.fgs.hyp, got.fgs.srt)
  expect.no_equality(got.fgs.dat, got.fgs.srt)
  -- Different hue again: any of those vs sort-polymorphic.
  expect.no_equality(got.fgs.poly, got.fgs.hyp)
  expect.no_equality(got.fgs.poly, got.fgs.dat)
  expect.no_equality(got.fgs.poly, got.fgs.srt)
  -- A hypothesis and a cited lemma: same cell, now DIFFERENT HUE, and the
  -- italic still carries locality on top of it.
  expect.no_equality(got.lemma.fg, got.fgs.hyp)
  expect.equality(got.hyp_italic, true)
  expect.equality(got.lemma.italic, false)
end

-- One underline style per cell — `HL_UNDERLINE_MASK` is three bits, so two
-- underline flags on one token is not a thing that can render. The module
-- must resolve it deterministically rather than leaving it to table order.
T["lean"]["highlights: at most one underline style per group"] = function()
  local bad = hl([[
    M.setup()
    M.group("theorem", { propWorld = true, element = true, simp = true })
    M.group("axiom", { propWorld = true, element = true, simp = true })
    M.group("variable", { dataWorld = true, sort = true, autoImplicit = true, simp = true })
    local out = {}
    for name, spec in pairs(M._specs()) do
      local n = 0
      for _, k in ipairs({ "underline", "undercurl", "underdouble",
                           "underdotted", "underdashed" }) do
        if spec[k] then n = n + 1 end
      end
      if n > 1 then table.insert(out, name .. "=" .. n) end
    end
    table.sort(out)
    return out
  ]])
  expect.equality(bad, {})
end

-- THE `sp` INVARIANT, stated precisely and swept. A coloured underline whose
-- colour is the foreground it sits under carries no signal at all — and it
-- fails silently, because the group is defined, the style bit is set and
-- `nvim_get_hl` returns exactly what was asked for.
--
-- The old rule was a blanket ban on yellow and red FOREGROUNDS, which cost a
-- palette whose whole complaint was that it had too few colours two entire
-- hues. `#f38ba8` is deliberately both the alarm `sp` and `kind_class`, and
-- `#f9e2af` is both a cited lemma and the colour the simp underline used to
-- be. Neither can collide on one token. This sweep is what makes reusing an
-- `sp` hex a decision rather than a gamble: it covers every combination the
-- flag table can produce, not the two anybody thought of.
T["lean"]["highlights: no group's underline colour is its own foreground"] = function()
  local bad = hl([[
    M.setup()
    M.warm()
    -- Every flag that sets an `sp`, on every cell it can reach, including
    -- the combinations: a token can be both an axiom and a simp lemma.
    for _, w in ipairs({ "propWorld", "dataWorld", "polyWorld" }) do
      for _, l in ipairs({ "element", "sort", "former" }) do
        for _, extra in ipairs({ {}, { simp = true }, { autoImplicit = true },
                                 { simp = true, autoImplicit = true },
                                 { ["local"] = true } }) do
          for _, ty in ipairs({ "variable", "theorem", "function", "axiom", "class" }) do
            local mods = { [w] = true, [l] = true }
            for k, v in pairs(extra) do mods[k] = v end
            M.group(ty, mods)
          end
        end
      end
    end
    local out, with_sp = {}, 0
    for name, spec in pairs(M._specs()) do
      if spec.sp then with_sp = with_sp + 1 end
      if spec.fg and spec.sp and spec.fg == spec.sp then
        table.insert(out, name .. " fg=sp=" .. spec.fg)
      end
    end
    table.sort(out)
    return { bad = out, n = vim.tbl_count(M._specs()), with_sp = with_sp }
  ]])
  expect.equality(bad.bad, {})
  -- Non-vacuity, both halves: the sweep really built a large set of groups,
  -- and some of them really do carry an `sp` — otherwise the condition
  -- being asserted is unreachable and this passes on an empty set.
  expect.equality(bad.n > 40, true)
  expect.equality(bad.with_sp > 0, true)
end

-- Memoisation is the entire performance story (D12: ~30 distinct pairs in a
-- 5,000-token file; 63 measured in a 106-line probe). If the cache key
-- depended on the order Lua walks the modifier set, every token would miss
-- while still producing the right colour — invisible until it is slow.
T["lean"]["highlights: the group name is independent of modifier order"] = function()
  local got = hl([[
    M.setup()
    local a = M.group("variable", { propWorld = true, element = true, ["local"] = true })
    local b = M.group("variable", { ["local"] = true, element = true, propWorld = true })
    local before = M._stats().misses
    for _ = 1, 50 do
      M.group("variable", { propWorld = true, element = true, ["local"] = true })
    end
    return { a = a, b = b, extra = M._stats().misses - before, hits = M._stats().hits }
  ]])
  expect.no_equality(got.a, vim.NIL)
  expect.equality(got.a, got.b)
  expect.equality(got.extra, 0)
  expect.equality(got.hits >= 50, true)
end

-- Tokens outside the world × level grid must be left to themes.lua. The one
-- that would be VISIBLY broken is `leanSorryLike`: it carries a yellow
-- background chip with a dark fg, and a priority-128 foreground on top of it
-- would leave the chip unreadable. Verified against the live server that
-- keyword/tactic/leanSorryLike all arrive with an empty modifier set; the
-- early return makes that independent of the server changing its mind.
T["lean"]["highlights: keyword, tactic and sorry are not repainted"] = function()
  local got = hl([[
    M.setup()
    return {
      kw    = M.group("keyword", {}) or "nil",
      tac   = M.group("tactic", {}) or "nil",
      -- even if it ever DID arrive classified:
      sorry = M.group("leanSorryLike", { propWorld = true, element = true }) or "nil",
      -- and a classified token with no level is not ours either
      partial = M.group("variable", { dataWorld = true }) or "nil",
      -- ...while a fully classified one is
      full = M.group("variable", { dataWorld = true, element = true }) or "nil",
    }
  ]])
  expect.equality(got.kw, "nil")
  expect.equality(got.tac, "nil")
  expect.equality(got.sorry, "nil")
  expect.equality(got.partial, "nil")
  expect.no_equality(got.full, "nil")
end

-- THE FALL-THROUGH SEAM, PINNED TO THE PALETTE IT CLAIMS TO FOLLOW.
--
-- A token that arrives without both a world and a level never reaches the
-- `@lean.*` grid, so themes.lua's `@lsp.type.*.lean` pins decide how it
-- looks. Each is supposed to take the colour its own kind takes in the grid,
-- so a classification miss degrades to a near neighbour instead of to an
-- unrelated hue.
--
-- THIS IS NOT HYPOTHETICAL. For one commit those pins held hand-copied hexes
-- with a comment naming the palette key each came from, and FOUR OF SEVEN
-- were already stale: `theorem` was still #89b4fa when prop_element had
-- become #f9e2af, `enumMember` still green, `class` still magenta, `enum`
-- still peach. Every one of them passed the "standard token names are
-- pinned" sweep above, because that sweep only asks whether a colour exists.
--
-- themes.lua now reads `defaults().hues` symbolically, which removes the
-- copy — but a symbolic read that goes stale is INVISIBLE where a wrong hex
-- was at least readable, and catppuccin caches compiled highlight output
-- under stdpath("cache"). So the equality is asserted rather than assumed.
--
-- HOW TO BREAK IT, because the obvious way does not: changing a hue in
-- DEFAULTS moves BOTH sides together — themes.lua reads the same table this
-- case does — and the assertion still holds, correctly. The break that
-- matters is a MIS-POINTED KEY (`enum` reading `prop_element` instead of
-- `data_sort`), which fails with both the pin and the key named. A stale
-- compiled colorscheme fails it too, because the left side is the APPLIED
-- highlight and the right side is the module.
T["lean"]["the fall-through pins take their own kind's palette colour"] = function()
  local PINS = {
    ["enum"] = "data_sort", -- inductives: Nat, List, True
    ["struct"] = "data_sort",
    ["class"] = "kind_class",
    ["enumMember"] = "kind_constructor",
    ["property"] = "kind_projection",
    ["function"] = "data_element", -- a plain def is most often data-valued
    ["theorem"] = "prop_element", -- a cited lemma
  }
  local got = child.lua_get(([[(function()
      local pins = %s
      local HL = require("config.lean.highlights")
      local hues = HL.defaults().hues
      local out = {}
      for g, key in pairs(pins) do
        local h = vim.api.nvim_get_hl(0, { name = "@lsp.type." .. g .. ".lean", link = false })
        out[g] = {
          want = hues[key] or ("NO SUCH HUE KEY: " .. key),
          got = h.fg and string.format("#%%06x", h.fg) or "nil",
        }
      end
      return out
    end)()]]):format(vim.inspect(PINS)))
  for g, key in pairs(PINS) do
    -- Both sides in the message, so a failure names the pin and the key.
    expect.equality({ g, key, got[g].got }, { g, key, got[g].want })
  end
end

-- TACTICS ARE NOT KEYWORDS ANY MORE. Dan: "SO MUCH FUCKING PURPLE ... Yes,
-- split the keyword purple too." `@lsp.type.tactic.lean` used to LINK to
-- `@lsp.type.keyword.lean`, so every `rw`, `simp`, `exact` and `ring` was
-- mauve along with `theorem` and `fun` — and tactics are the verbs of a
-- proof, so by count they were most of the purple.
--
-- This is a themes.lua assertion rather than a palette one: both groups are
-- outside the `@lean.*` grid (SKIP), so nothing in highlights.lua can see
-- them. The failure it guards is someone "tidying" the split back into a
-- link, which is invisible in review and reverts the whole change.
T["lean"]["highlights: tactics are split off the keyword purple"] = function()
  local got = child.lua_get([[(function()
    local function look(n)
      local h = vim.api.nvim_get_hl(0, { name = n, link = false })
      return { fg = h.fg and string.format("#%06x", h.fg) or "nil", bold = h.bold or false }
    end
    return { tac = look("@lsp.type.tactic.lean"), kw = look("@lsp.type.keyword.lean") }
  end)()]])
  -- Non-vacuity: both are real, resolved colours, not two nils comparing
  -- equal and not one group that was never defined (A4).
  expect.no_equality(got.tac.fg, "nil")
  expect.no_equality(got.kw.fg, "nil")
  expect.no_equality(got.tac.fg, got.kw.fg)
  expect.equality(got.tac.fg, "#89b4fa") -- blue, bold: the verbs of a proof
  -- Bold, and DELIBERATELY exempt from the retune's "no bold on a loud
  -- colour" sweep below. Put to Dan explicitly, because bright-plus-bold on
  -- something this frequent is the shape he had just corrected; he said keep
  -- it. Recorded here so nobody "finishes the sweep" later.
  expect.equality(got.tac.bold, true)
end

-- B4: HL_UNDERLINE_MASK is three bits, so a cell has exactly ONE underline
-- style. Three flags now want it — `imported` (a Mathlib lemma), `axiom` and
-- `auto` — and the order in `build_flags` is the whole of the precedence.
--
-- RARITY WINS THE SLOT. `defaultLibrary` is on the majority of identifiers in
-- a Mathlib-importing file (258 of 1,189 tokens in MIL C09 S01); `axiom` and
-- `auto` are rare and urgent. `Classical.choice` is imported AND an axiom,
-- so this is a real constant and not a constructed case.
--
-- Asserting on the SPEC and not on `nvim_get_hl`: a style that lost still
-- shows as absent either way, but a leftover `sp` from the loser only shows
-- in the spec, and B4 records that a stray `sp` survives an overridden style
-- and draws a coloured underline from a group that lost.
T["lean"]["highlights: the underline precedence is imported < axiom < auto"] = function()
  local got = hl([[
    M.setup()
    local function spec(ty, mods)
      return M._specs()[M.group(ty, mods)]
    end
    local function styles(s)
      local out = {}
      for _, k in ipairs({ "underline", "undercurl", "underdouble",
                           "underdotted", "underdashed" }) do
        if s[k] then out[#out + 1] = k end
      end
      out[#out + 1] = "sp=" .. tostring(s.sp)
      return table.concat(out, "+")
    end
    local prop = { propWorld = true, element = true }
    local both = { propWorld = true, element = true, defaultLibrary = true }
    return {
      imported = styles(spec("theorem", both)),
      -- SCOPE. `defaultLibrary` is on every imported name; only the cited
      -- lemma cell is marked. A type constructor is imported too and must
      -- come back bare, or 220 of the 258 underlines in MIL C09 S01 are on
      -- things nobody asked to distinguish.
      imported_former = styles(spec("function",
        { dataWorld = true, former = true, defaultLibrary = true })),
      axiom_only = styles(spec("axiom", prop)),
      imported_axiom = styles(spec("axiom", both)),
      imported_auto = styles(spec("variable",
        { propWorld = true, element = true, defaultLibrary = true, autoImplicit = true })),
      plain = styles(spec("theorem", prop)),
    }
  ]])
  -- Non-vacuity: the plain cell must carry NO underline, or "the imported one
  -- lost" and "nothing ever sets an underline" are the same observation.
  expect.equality(got.plain, "sp=nil")
  expect.equality(got.imported, "underline+sp=nil")
  expect.equality(got.imported_former, "sp=nil")
  expect.equality(got.axiom_only, "underdouble+sp=#f38ba8")
  -- ...and the collision. `Classical.choice` keeps "rests on nothing".
  expect.equality(got.imported_axiom, "underdouble+sp=#f38ba8")
  expect.equality(got.imported_auto, "underdashed+sp=nil")
end

-- The retune, stated as an invariant rather than as a list of hexes.
--
-- Dan, 2026-08-13: "making such a bright colour almost always bold as well
-- was not a good idea lmao. So get rid of the boldness of the pink." The
-- instruction is general — every bright pink and magenta, not the three
-- entries he happened to name — so it is enforced by SWEEPING the whole
-- generated set rather than by asserting on the groups we remembered.
--
-- "Bright pink or magenta" is defined arithmetically and not by a list: a
-- strong red channel, a present blue channel, and a green channel below both
-- by a clear margin. Measured against every hex in play, it catches
-- `#ff1493`, `#ff5fff`, `#f5c2e7`, `#ff69b4` and `#f38ba8`, and lets
-- `#fab387` peach, `#f9e2af` yellow, `#89b4fa` blue, `#cba6f7` mauve,
-- `#eba0ac` maroon and `#f5e0dc` rosewater through — which is the
-- distinction the instruction actually draws.
T["lean"]["highlights: no bright pink or magenta is bold"] = function()
  local got = hl([[
    M.setup()
    M.warm()
    local bold = {}
    local function bright_pink(hex)
      local r = tonumber(hex:sub(2, 3), 16)
      local g = tonumber(hex:sub(4, 5), 16)
      local b = tonumber(hex:sub(6, 7), 16)
      return r >= 0xd0 and b >= 0x80 and g <= r - 0x30 and g <= b - 0x18
    end
    local pink = {}
    for name, spec in pairs(M._specs()) do
      if spec.fg and bright_pink(spec.fg) then
        pink[#pink + 1] = name
        if spec.bold then bold[#bold + 1] = name .. " " .. spec.fg end
      end
    end
    table.sort(bold)
    table.sort(pink)
    return { bold = bold, pink = pink,
             prop_former = vim.api.nvim_get_hl(0, { name = "@lean.prop.former", link = false }),
             data_former = vim.api.nvim_get_hl(0, { name = "@lean.data.former", link = false }),
             cls = vim.api.nvim_get_hl(0, { name = "@lean.data.former.class", link = false }) }
  ]])
  -- NON-VACUITY, TWICE OVER. A predicate that matched nothing would leave
  -- the loop asserting nothing at all — the "green suite that cannot fail"
  -- mode (GOTCHAS E). So the matched set is named in full rather than
  -- counted: it is the answer to "how much pink is on screen", which is the
  -- other half of the retune ("I do love magenta and pink — we're gonna try
  -- to make sure those aren't too rare!").
  expect.equality(got.pink, {
    "@lean.data.former.class",     -- #f38ba8  Group, Monoid
    "@lean.data.sort.auto",        -- #f38ba8  the alarm recolour
    "@lean.data.sort.class",       -- #f38ba8
    "@lean.data.sort.local",       -- #ff5fff  a type variable
    "@lean.prop",                  -- #ff1493  the world anchor
    "@lean.prop.element.local",    -- #f5c2e7  a hypothesis
    "@lean.prop.former",           -- #ff1493  a predicate
  })
  expect.equality(got.bold, {})
  -- The two cells Dan named, spelled out, because the sweep above would also
  -- pass if `prop.former` had quietly stopped being pink at all.
  expect.equality(got.prop_former.fg, tonumber("ff1493", 16))
  expect.equality(got.prop_former.italic, true)
  expect.equality(got.prop_former.bold, nil)
  expect.equality(got.cls.italic, true)
  expect.equality(got.cls.bold, nil)
  -- ...and the scope of the exemption: `former` is still a BOLD channel, so
  -- the data-world former keeps it. Without this the CELL_STYLE table could
  -- be widened to every cell and nothing would notice.
  expect.equality(got.data_former.bold, true)
  expect.equality(got.data_former.italic, nil)
end

-- The failure that is invisible in review and fatal in use: a module with a
-- "already defined" cache stops defining anything after `:colorscheme`
-- clears the groups, and every synthesised colour silently disappears. This
-- is why LineNrWrap and @lsp.type.variable.lean live in catppuccin's
-- highlight_overrides in the first place.
T["lean"]["highlights: synthesised groups survive a colorscheme reload"] = function()
  local got = hl([[
    M.setup()
    local g = M.group("variable", { propWorld = true, element = true, ["local"] = true })
    local function fg()
      local h = vim.api.nvim_get_hl(0, { name = g, link = false })
      return h.fg and string.format("#%06x", h.fg) or "nil"
    end
    local before = fg()
    vim.cmd.colorscheme("catppuccin")
    return { before = before, after = fg(), grid_after =
      (vim.api.nvim_get_hl(0, { name = "@lean.data.former", link = false }).bold == true) }
  ]])
  expect.no_equality(got.before, "nil")
  expect.equality(got.after, got.before)
  expect.equality(got.grid_after, true)
end

-- A typo'd palette key would surface as one uncoloured token type in one
-- rare cell, months later. Every entry must be a real hex colour, and every
-- cell of the grid must HAVE an entry — there is no computed shade behind
-- them any more and no blend to fall back on, so a missing key is a group
-- painted with its world's anchor and nobody would see the difference until
-- two cells rendered alike.
T["lean"]["highlights: the palette resolves to real hex colours"] = function()
  local got = hl([[
    local bad, n = {}, 0
    for name, hex in pairs(M.palette) do
      n = n + 1
      if type(hex) ~= "string" or not hex:match("^#%x%x%x%x%x%x$") then
        table.insert(bad, name .. "=" .. tostring(hex))
      end
    end
    -- Every cell, both localities, plus the three kind overrides.
    local missing, distinct = {}, {}
    for _, w in ipairs({ "prop", "data", "poly" }) do
      if not M.palette[w] then table.insert(missing, w) end
      for _, l in ipairs({ "element", "sort", "former" }) do
        for _, suffix in ipairs({ "", "_local" }) do
          local k = w .. "_" .. l .. suffix
          if not M.palette[k] then table.insert(missing, k) end
        end
      end
    end
    for _, k in ipairs({ "kind_constructor", "kind_projection", "kind_class" }) do
      if not M.palette[k] then table.insert(missing, k) end
    end
    for k, v in pairs(M.palette) do
      if k ~= "alarm" and k ~= "simp_bg" then distinct[v] = true end
    end
    table.sort(bad); table.sort(missing)
    return { bad = bad, n = n, missing = missing, ndistinct = vim.tbl_count(distinct) }
  ]])
  expect.equality(got.bad, {})
  expect.equality(got.missing, {})
  expect.equality(got.n >= 24, true)
  -- THE HEADLINE NUMBER. The rejected palette was three hues at two computed
  -- brightnesses; the complaint was "SO MUCH FUCKING PURPLE ... Too much
  -- blue". 24 keys deliberately hold fewer than 24 values (a `.local`
  -- variant repeats its partner wherever the two are not confusable), but a
  -- table that collapsed back toward a handful would be the rejected
  -- palette wearing more keys, and nothing else in the suite would notice.
  expect.equality(got.ndistinct, 15)
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ END: Lean colour design                                              │
-- ╰──────────────────────────────────────────────────────────────────────╯

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ BEGIN: <leader>K token inspector                                     │
-- ╰──────────────────────────────────────────────────────────────────────╯
--
-- lua/config/lean/inspect_token.lua. WHAT CAN AND CANNOT BE TESTED HERE:
--
-- The interesting half of that module reads the RENDERED SCREEN, and this
-- child is headless, so it applies no semantic tokens at all (M5 / GOTCHAS
-- A1) and would report an empty stack at every position while looking like a
-- clean pass. Anything asserting a colour, a priority or a winner therefore
-- belongs in a pty-hosted TUI and NOT in this file — see the commit, which
-- pastes the live output for six token kinds.
--
-- What is testable without a server, and is tested below:
--   * the binding exists, is buffer-local, is not global, and is
--     discoverable from both the clue window and the cheatsheet;
--   * adding a <Leader> clue to vim.b.miniclue_config did not CLOBBER the
--     <LocalLeader> clues already there (mini.clue concatenates — clue.lua
--     H.get_config — but that is its behaviour to change, not ours to assume);
--   * the module survives the positions that produce no data at all, which
--     is where a display tool actually breaks;
--   * every name in the server's legend has an English gloss. That is the
--     one property most likely to rot: the legend is 29 types and 31
--     modifiers today and the module's tables are hand-written.
--   * the merge rules the display teaches are the rules it implements.

local INSPECT_MOD = H.cfg .. "/lua/config/lean/inspect_token.lua"

--- Fresh module instance per case, as with `hl()` above: the config has
--- already required this module in the ftplugin and a shared instance would
--- let one case's state reach another.
local function ins(body)
  return child.lua_get(
    ("(function() local M = dofile(%q) %s end)()"):format(INSPECT_MOD, body)
  )
end

-- `@lean.*` is no longer the grid's private namespace: namespace_hl.lua
-- synthesises `@lean.ns.prefix` at priority 129, ABOVE highlights.lua's 128,
-- and after/syntax/lean.vim contributes `@lean.path.*`. The grid attribution
-- must still name the grid cell — reporting a namespace-prefix mark as "the
-- @lean.* grid" would be exactly the confident wrong answer this tool exists
-- to prevent, and nothing about the output would look off.
T["lean"]["inspector: the grid attribution ignores non-grid @lean.* marks"] = function()
  local got = ins([[
    local layers = {
      { group = "leanConstant",       priority = 50 },
      { group = "@lsp.type.theorem.lean", priority = 125 },
      { group = "@lean.prop.element", priority = 128 },
      { group = "@lean.ns.prefix",    priority = 129 },
    }
    local grid = M.grid_layer(layers)
    return {
      picked = grid and grid.group or "nil",
      -- and it is nil, not a wrong guess, when only non-grid marks are there
      none = (M.grid_layer({ { group = "@lean.ns.dot", priority = 129 },
                             { group = "@lean.path.final", priority = 50 },
                             { group = "@lean.binder.keyword", priority = 129 } })
              or { group = "nil" }).group,
      worlds = vim.tbl_count(M.GRID_WORLD),
    }
  ]])
  expect.equality(got.picked, "@lean.prop.element")
  expect.equality(got.none, "nil")
  expect.equality(got.worlds, 3)
end

T["lean"]["inspector: <leader>K is buffer-local, not global"] = function()
  -- Buffer-local maps report the lhs with the leader already expanded.
  local got = child.lua_get([[(function()
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
      if m.lhs == " K" then return m.desc or "" end
    end
    return "MISSING"
  end)()]])
  expect.equality(got, "Inspect token highlighting")
  -- tests/test_keymap_ownership.lua sees global maps only, so this is the
  -- only place the Lean-only-ness of a <Leader> map can be pinned. A global
  -- one would fire the Lean inspector from a Lua buffer.
  expect.equality(
    child.lua_get([[(function()
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        if m.lhs == " K" then return true end
      end
      return false
    end)()]]),
    false
  )
end

-- The clobber check. after/ftplugin/lean.lua appends one <Leader> clue to
-- vim.b.miniclue_config, which already held a dozen <LocalLeader> ones; if
-- the append were ever rewritten as an assignment, every Lean clue but this
-- one would vanish and `\` would stop being a discovery key. Asserting only
-- that the new entry is present would not catch that.
T["lean"]["inspector: the <Leader>K clue did not displace the <LocalLeader> ones"] = function()
  local got = child.lua_get([[(function()
    local c = vim.b.miniclue_config or {}
    local keys = {}
    for _, x in ipairs(c.clues or {}) do keys[x.keys] = x.desc or "" end
    local triggers = {}
    for _, t in ipairs(c.triggers or {}) do triggers[#triggers + 1] = t.keys end
    return { leaderK = keys["<Leader>K"], localleader_i = keys["<LocalLeader>i"],
             cheatsheet = keys["<LocalLeader>?"], n = vim.tbl_count(keys),
             triggers = triggers }
  end)()]])
  expect.equality(got.leaderK, "Inspect token highlighting")
  -- ...and the pre-existing ones are all still there.
  expect.equality(got.localleader_i, "Toggle infoview")
  expect.equality(got.cheatsheet, "Lean cheatsheet")
  expect.equality(got.n > 20, true)
  -- The buffer trigger for `\` must survive too; the global <Leader> trigger
  -- comes from plugins/mini.lua and is what shows the new clue.
  expect.equality(got.triggers, { "<LocalLeader>" })
end

-- Same rule as the parity bindings: a key absent from the cheatsheet is a
-- key nobody finds even after pressing the discovery key.
T["lean"]["inspector: <leader>K is in the cheatsheet"] = function()
  local f = assert(io.open(H.cfg .. "/lean-cheatsheet.md", "r"))
  local text = f:read("*a")
  f:close()
  expect.equality(text:find("`<leader>K`", 1, true) ~= nil, true)
end

-- The positions where a display tool actually breaks. All three must produce
-- LINES that SAY something, not an error and not silence — and they must say
-- DIFFERENT things, because "no client", "no token" and "on whitespace" are
-- three different facts and collapsing them is the A4 failure mode.
T["lean"]["inspector: empty positions report rather than error"] = function()
  local got = ins([[
    -- A buffer with no language server at all. `report` must still work: two
    -- of its three sections are read from the buffer, not from a server.
    --
    -- 'syntax' rather than 'filetype': setting the filetype would run the
    -- FileType chain and could start a leanls for an unnamed buffer, which is
    -- exactly the condition this case is trying to be the absence of. The
    -- window is restored by hand because every case after this one reads
    -- buffer 0, and `:bwipeout` returns to the PREVIOUS window, which in a
    -- Lean child may be lean.nvim's infoview.
    local prev_win = vim.api.nvim_get_current_win()
    vim.cmd("new")
    local w, b = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "theorem t : True := trivial", "" })
    vim.bo[b].syntax = "lean"
    local out = {}
    local function grab(key, row, col)
      local ok, R = pcall(M.report, w, b, row, col)
      if not ok then out[key] = { err = tostring(R) } return end
      local ok2, lines = pcall(M.render, R)
      out[key] = {
        err = not ok2 and tostring(lines) or nil,
        n = ok2 and #lines or 0,
        text = ok2 and table.concat(lines, "\n") or "",
        on_blank = R.on_blank,
        attached = R.attached,
        highlighter = R.highlighter_running,
        ntokens = #R.tokens,
      }
    end
    grab("word", 0, 8)        -- on `t`
    grab("blank", 0, 7)       -- the space before it
    grab("emptyline", 1, 0)   -- an entirely empty line
    vim.cmd("bwipeout!")
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
    return {
      word = { err = out.word.err, n = out.word.n, blank = out.word.on_blank,
               attached = out.word.attached,
               says_no_client = out.word.text:find("No `leanls` client", 1, true) ~= nil },
      blank = { err = out.blank.err, n = out.blank.n, blank = out.blank.on_blank,
                says_blank = out.blank.text:find("whitespace or end of line", 1, true) ~= nil },
      emptyline = { err = out.emptyline.err, n = out.emptyline.n,
                    blank = out.emptyline.on_blank },
    }
  ]])
  for _, case in ipairs({ "word", "blank", "emptyline" }) do
    expect.equality(got[case].err, nil)
    -- Non-vacuity: a report that rendered nothing would also raise nothing.
    expect.equality(got[case].n > 20, true)
  end
  expect.equality(got.word.blank, false)
  expect.equality(got.word.attached, false)
  expect.equality(got.word.says_no_client, true)
  expect.equality(got.blank.blank, true)
  expect.equality(got.blank.says_blank, true)
  expect.equality(got.emptyline.blank, true)
end

-- ── the glosses ────────────────────────────────────────────────────────
-- The display's whole value in section 1 is that it translates the server's
-- vocabulary. A name with no gloss is a blank column in the one place the
-- user came to read prose.
--
-- Read from the server's own enum for the same reason the sibling case above
-- does: a hardcoded copy here would agree with itself forever while the
-- server moved. Skips loudly (from INSIDE the case) when the checkout is
-- absent, and the hardcoded core case below still runs.
T["lean"]["inspector: every name in the server legend has an English gloss"] = function()
  need_legend_src()
  local types, mods = lean_legend()
  local have = ins([[
    local t, m = {}, {}
    for k in pairs(M.TYPE_GLOSS) do t[#t + 1] = k end
    for k in pairs(M.MOD_GLOSS) do m[#m + 1] = k end
    return { types = t, mods = m }
  ]])
  local have_t, have_m = {}, {}
  for _, k in ipairs(have.types) do
    have_t[k] = true
  end
  for _, k in ipairs(have.mods) do
    have_m[k] = true
  end

  local missing = {}
  for name in pairs(types) do
    if not have_t[name] then
      table.insert(missing, "type " .. name)
    end
  end
  for name in pairs(mods) do
    if not have_m[name] then
      table.insert(missing, "modifier " .. name)
    end
  end
  table.sort(missing)
  expect.equality(missing, {})

  -- ...and nothing glossed that the server cannot send, which is how the
  -- three `lean`-prefixed groups died silently in themes.lua.
  local dead = {}
  for _, k in ipairs(have.types) do
    if not types[k] then
      table.insert(dead, "type " .. k)
    end
  end
  for _, k in ipairs(have.mods) do
    if not mods[k] then
      table.insert(dead, "modifier " .. k)
    end
  end
  table.sort(dead)
  expect.equality(dead, {})

  -- Non-vacuity: an empty legend would clear both loops above.
  expect.equality(vim.tbl_count(types) >= 29, true)
  expect.equality(vim.tbl_count(mods) >= 31, true)
end

-- The half of the coverage that does not depend on a checkout being present,
-- so the suite is never silently uncovered here. Every name NAMES.md's own
-- tables turn on, plus the historical-note names that must NOT come back.
T["lean"]["inspector: the NAMES.md core vocabulary is glossed"] = function()
  local CORE_TYPES = {
    "keyword", "variable", "function", "property", "struct", "class", "enum",
    "enumMember", "typeParameter", "theorem", "axiom", "opaque", "recursor",
    "tactic", "leanSorryLike",
  }
  local CORE_MODS = {
    "propWorld", "dataWorld", "polyWorld", "element", "sort", "former",
    "implicit", "strictImplicit", "instBinder", "local", "autoImplicit",
    "simp", "instance", "reducible", "irreducible", "private", "protected",
    "noncomputable", "matchPattern", "elabWithoutExpectedType", "abbrev",
    "declaration", "deprecated", "defaultLibrary",
  }
  local got = ins(([[
    local out = { missing = {}, empty = {}, unordered = {} }
    for _, t in ipairs(%s) do
      if not M.TYPE_GLOSS[t] then table.insert(out.missing, "type " .. t)
      elseif M.TYPE_GLOSS[t] == "" then table.insert(out.empty, "type " .. t) end
    end
    for _, m in ipairs(%s) do
      if not M.MOD_GLOSS[m] then table.insert(out.missing, "mod " .. m)
      elseif M.MOD_GLOSS[m] == "" then table.insert(out.empty, "mod " .. m) end
      -- Every real modifier must also have a place in the display order, or
      -- it silently sorts to the end with the never-set ones.
      if not M.MOD_ORDER[m] then table.insert(out.unordered, m) end
    end
    -- The names NAMES.md's historical note retired. A gloss for one of these
    -- would mean the module was written against a stale document.
    out.zombies = {}
    for _, z in ipairs({ "leanProof", "leanHypothesis", "leanProp",
                         "leanInductive", "leanTheorem", "leanAxiom",
                         "leanRecursor", "leanTactic", "leanPropWorld",
                         "leanSortType", "leanFormer", "leanElement" }) do
      if M.TYPE_GLOSS[z] or M.MOD_GLOSS[z] then table.insert(out.zombies, z) end
    end
    table.sort(out.missing) table.sort(out.empty) table.sort(out.unordered)
    return out
  ]]):format(vim.inspect(CORE_TYPES), vim.inspect(CORE_MODS)))
  expect.equality(got.missing, {})
  expect.equality(got.empty, {})
  expect.equality(got.unordered, {})
  expect.equality(got.zombies, {})
end

-- The sentence NAMES.md itself writes: propWorld + element + local must read
-- as "a hypothesis: a local whose type is a proposition". If only one thing
-- in this section is worth pinning, it is that one.
T["lean"]["inspector: the world x level grid reads as English"] = function()
  local got = ins([[
    local function say(ty, mods)
      local s = M.sentence(ty, mods)
      return s.headline .. " | " .. (s.detail or "") ..
             (#s.clauses > 0 and (" | " .. table.concat(s.clauses, " / ")) or "")
    end
    return {
      hypothesis = say("variable", { propWorld = true, element = true, ["local"] = true }),
      datum      = say("variable", { dataWorld = true, element = true, ["local"] = true }),
      typevar    = say("variable", { dataWorld = true, sort = true, ["local"] = true }),
      lemma      = say("theorem", { propWorld = true, element = true, defaultLibrary = true }),
      predicate  = say("theorem", { propWorld = true, former = true }),
      sorrylike  = say("leanSorryLike", {}),
      tactic     = say("tactic", {}),
      -- Degrade: no token at all, and a type the module has never heard of.
      nothing    = say(nil, nil),
      unknown    = say("someNewTokenType", { propWorld = true }),
    }
  ]])
  -- NAMES.md's own words, near enough to be recognisable as them.
  expect.equality(got.hypothesis, "a hypothesis | a local whose type is a proposition — so it is a proof")
  expect.equality(got.datum, "a data local | a local whose type is some `Type u` — so it is a datum")
  expect.equality(got.typevar, "a type variable | a local that IS a type")
  expect.equality(
    got.lemma,
    "a theorem | a term whose type is a proposition — so it is a proof"
      .. " | imported from the library, not proved in this file"
  )
  expect.equality(
    got.predicate,
    "a theorem | a term that is a predicate: a function producing propositions"
  )
  -- The three token types outside the grid say so rather than inventing a
  -- world; that is what makes them fall through to themes.lua.
  expect.equality(got.sorrylike:find("^a hole | the server sent no world/level") ~= nil, true)
  expect.equality(got.tactic:find("^a tactic | the server sent no world/level") ~= nil, true)
  -- Total: never a blank line, whatever it is handed.
  expect.equality(got.nothing, "no semantic token here | ")
  expect.equality(
    got.unknown,
    "a `someNewTokenType` token | in the propWorld, but the server sent no level (element / sort / former)"
  )
end

-- The sentence must be a function of the modifier SET, not of the order Lua
-- happens to walk it in — the same property highlights.lua's group names have,
-- and for the same reason: it is invisible until it is wrong.
T["lean"]["inspector: modifier order is stable and categorical"] = function()
  local got = ins([[
    local a = M.sorted_mods({ ["local"] = true, element = true, propWorld = true,
                              declaration = true, simp = true })
    local b = M.sorted_mods({ simp = true, declaration = true, propWorld = true,
                              element = true, ["local"] = true })
    return { a = a, b = b,
             -- an unknown name must still appear, and last
             novel = M.sorted_mods({ zzUnknown = true, propWorld = true }) }
  ]])
  -- Universe, then level, then flags, then the standard LSP ones: NAMES.md's
  -- own categories, so the two axes that decide the colour are read first.
  expect.equality(got.a, { "propWorld", "element", "local", "simp", "declaration" })
  expect.equality(got.b, got.a)
  expect.equality(got.novel, { "propWorld", "zzUnknown" })
end

-- ── the merge model ────────────────────────────────────────────────────
-- Section 3 of the display teaches three rules. This pins that the code
-- implements the rules the prose claims. It does NOT prove the rules are
-- Neovim's — nothing headless can — which is exactly why M.report() also
-- reads the real cell and the display diffs the two.
T["lean"]["inspector: the composition model matches the rules it teaches"] = function()
  local got = ins([[
    local function L(priority, group, attrs)
      return { priority = priority, group = group, attrs = attrs, defined = true }
    end
    -- Priority-ASCENDING, as M.compose requires.
    local c = M.compose({
      L(50,  "syntax",  { fg = 0x111111, bold = true, underdouble = true }),
      L(125, "type",    { fg = 0x222222 }),
      L(128, "synth",   { fg = 0x333333, italic = true, underdotted = true,
                          sp = 0x444444 }),
    })
    local function at(k) return c[k] and { c[k].value, c[k].group } or nil end
    return {
      fg = at("fg"), sp = at("sp"),
      -- OR: nothing above 50 mentions bold, so the syntax layer's survives.
      bold = at("bold"), italic = at("italic"),
      -- one underline slot: 128's dotted replaces 50's double outright
      underdouble = at("underdouble"), underdotted = at("underdotted"),
      -- and an undefined layer contributes nothing at any priority
      ignored = (function()
        local d = M.compose({ L(50, "syntax", { fg = 0x111111 }),
          { priority = 9999, group = "dead", attrs = {}, defined = false } })
        return d.fg and d.fg.group
      end)(),
    }
  ]])
  expect.equality(got.fg, { "#333333", "synth" })
  expect.equality(got.sp, { "#444444", "synth" })
  -- The point of the section: an attribute the winner never mentions still
  -- reaches the cell, from a layer 78 priorities below it.
  expect.equality(got.bold, { true, "syntax" })
  expect.equality(got.italic, { true, "synth" })
  expect.equality(got.underdouble, nil)
  expect.equality(got.underdotted, { true, "synth" })
  -- An undefined group at priority 9999 loses to a defined one at 50.
  expect.equality(got.ignored, "syntax")
end

-- The seven standard LSP modifiers NAMES.md records as "kept for legend
-- compatibility and never set". The module flags a token that carries one,
-- because that means the server's vocabulary moved and every gloss in the
-- file was written against the old meaning. Three ways that can rot: a name
-- drops out of the legend, a name gains a real gloss without leaving the
-- never-set table, or a real modifier is wrongly listed as never-set.
T["lean"]["inspector: the never-set modifiers are consistent with the legend"] = function()
  need_legend_src()
  local _, mods = lean_legend()
  local got = ins([[
    local never, glossed_never = {}, {}
    for k in pairs(M.MOD_NEVER_SET) do never[#never + 1] = k end
    -- Which names carry the never-set gloss, whatever the table says.
    local NEVER_TEXT = M.MOD_GLOSS.definition
    for k, v in pairs(M.MOD_GLOSS) do
      if v == NEVER_TEXT then glossed_never[#glossed_never + 1] = k end
    end
    table.sort(never) table.sort(glossed_never)
    return { never = never, glossed_never = glossed_never,
             text = NEVER_TEXT,
             -- ...and none of them may occupy a slot in the display order
             -- ahead of a modifier that is actually sent.
             ordered = (function()
               local out = {}
               for k in pairs(M.MOD_NEVER_SET) do
                 if (M.MOD_ORDER[k] or 0) < (M.MOD_ORDER.defaultLibrary or 0) then
                   out[#out + 1] = k
                 end
               end
               table.sort(out)
               return out
             end)() }
  ]])
  expect.equality(got.never, {
    "abstract", "async", "definition", "documentation", "modification",
    "readonly", "static",
  })
  -- The table and the glosses must name exactly the same seven; a name in one
  -- and not the other is the display saying two different things about it.
  expect.equality(got.glossed_never, got.never)
  expect.equality(got.text:find("never set by this server", 1, true) ~= nil, true)
  expect.equality(got.ordered, {})
  -- Every one must still be IN the legend — that is what "kept for
  -- compatibility" means, and if one were dropped the flag could never fire.
  local absent = {}
  for _, k in ipairs(got.never) do
    if not mods[k] then
      table.insert(absent, k)
    end
  end
  expect.equality(absent, {})
end

-- 'cursorlineopt' DEFAULTS to "both", so a substring test for "line" misses
-- the default outright — which is the only configuration the synthetic
-- CursorLine layer exists to explain. Latent when it was written (this config
-- has 'cursorline' off), which is exactly why it needs a test rather than an
-- observation.
T["lean"]["inspector: CursorLine is recognised under every cursorlineopt"] = function()
  local got = ins([[
    local prev_win = vim.api.nvim_get_current_win()
    vim.cmd("new")
    local w, b = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(b, 0, -1, false, { "abc" })
    vim.api.nvim_win_set_cursor(w, { 1, 1 })
    local out = {}
    local function seen(cul, opt)
      vim.wo[w].cursorline = cul
      vim.wo[w].cursorlineopt = opt
      local R = M.report(w, b, 0, 1)
      for _, L in ipairs(R.layers) do
        if L.group == "CursorLine" then return true end
      end
      return false
    end
    out["off"] = seen(false, "both")
    out["both"] = seen(true, "both")          -- the DEFAULT
    out["line"] = seen(true, "line")
    out["screenline"] = seen(true, "screenline")
    out["number"] = seen(true, "number")      -- paints the gutter only
    out["number,line"] = seen(true, "number,line")
    vim.cmd("bwipeout!")
    if vim.api.nvim_win_is_valid(prev_win) then
      vim.api.nvim_set_current_win(prev_win)
    end
    return out
  ]])
  expect.equality(got["off"], false)
  expect.equality(got["both"], true)
  expect.equality(got["line"], true)
  expect.equality(got["screenline"], true)
  -- 'number' paints the number column, not the line: it must NOT be credited
  -- with a background on the token's cell.
  expect.equality(got["number"], false)
  expect.equality(got["number,line"], true)
end

-- GOTCHAS A4: `nvim_get_hl` cannot tell an undefined group from a cleared one
-- from a typo, so `defined` here means one thing only — "resolves to at least
-- one attribute that affects the rendered cell". A cterm-only definition must
-- NOT count, or a group that paints nothing in a truecolour terminal would be
-- reported as the winner.
T["lean"]["inspector: a cterm-only group does not count as defined"] = function()
  local got = ins([[
    vim.api.nvim_set_hl(0, "InspectProbeCtermOnly", { cterm = { bold = true } })
    vim.api.nvim_set_hl(0, "InspectProbeReal", { fg = "#89b4fa" })
    vim.api.nvim_set_hl(0, "InspectProbeCleared", {})
    return {
      cterm = M.resolve("InspectProbeCtermOnly").defined,
      real = M.resolve("InspectProbeReal").defined,
      cleared = M.resolve("InspectProbeCleared").defined,
      never_named = M.resolve("InspectProbeNeverDefinedAtAll").defined,
      describes = M.resolve("InspectProbeCleared").defined == false
        and M.describe({ group = "x", defined = false, attrs = {} }) or "",
    }
  ]])
  expect.equality(got.cterm, false)
  expect.equality(got.real, true)
  expect.equality(got.cleared, false)
  expect.equality(got.never_named, false)
  -- ...and the display says why that matters, rather than leaving a blank.
  expect.equality(got.describes:find("contributes nothing", 1, true) ~= nil, true)
end

-- ╭──────────────────────────────────────────────────────────────────────╮
-- │ END: <leader>K token inspector                                       │
-- ╰──────────────────────────────────────────────────────────────────────╯

-- LspInlayHint is styled in the catppuccin overrides (so it survives a
-- colorscheme reload, as with LineNrWrap). catppuccin's stock value is
-- Comment's exact fg, which makes a hint read as a comment; ours must not be.
T["lean"]["LspInlayHint is distinguishable from Comment"] = function()
  -- `fgs`, not `hl`: `hl()` is the file-level helper that runs a body against
  -- a fresh highlights module, and a local of that name inside a case makes
  -- the helper unreachable exactly where someone would reach for it.
  local fgs = child.lua_get([[(function()
    local hint = vim.api.nvim_get_hl(0, { name = "LspInlayHint", link = false })
    local comment = vim.api.nvim_get_hl(0, { name = "Comment", link = false })
    return { hint = hint.fg or "MISSING", comment = comment.fg or "MISSING" }
  end)()]])
  expect.no_equality(fgs.hint, "MISSING")
  expect.no_equality(fgs.hint, fgs.comment)
end

-- \? reads this at press time; a rename would fail silently into the fallback.
T["lean"]["cheatsheet file exists"] = function()
  local path = H.cfg .. "/lean-cheatsheet.md"
  expect.equality(vim.uv.fs_stat(path) ~= nil, true)
end

-- ── the `gr` prefix, reclaimed ─────────────────────────────────────────
-- mini.operators' replace operator used to sit on `gr`, and its setup does not
-- merely shadow the built-in LSP maps — operators.lua:726-734 DELETES `gra`,
-- `gri`, `grn`, `grr`, `grt` and `grx` when the prefix is exactly "gr". The
-- VS Code parity audit measured all five as UNMAPPED in a live Lean buffer.
-- plugins/mini.lua moves the operator to `gR`, which is enough: Neovim creates
-- these in runtime/lua/vim/_defaults.lua at startup, so not deleting them is
-- the whole fix — nothing re-binds them here or in the ftplugin.
--
-- Non-vacuous by construction: every one of these read "UNMAPPED" before the
-- prefix moved, and restoring `prefix = "gr"` turns all six cases below red.
T["lean"]["built-in gr* LSP maps are alive in a Lean buffer"] = new_set({
  parametrize = {
    { "grn", "vim.lsp.buf.rename()" },
    { "gra", "vim.lsp.buf.code_action()" },
    { "grr", "vim.lsp.buf.references()" },
    { "gri", "vim.lsp.buf.implementation()" },
    { "grt", "vim.lsp.buf.type_definition()" },
  },
}, {
  test = function(lhs, desc)
    expect.equality(
      child.lua_get(
        string.format([[vim.fn.maparg(%q, "n", false, true).desc or "UNMAPPED"]], lhs)
      ),
      desc
    )
  end,
})

-- The other half: the operator really did move, all three variants came with
-- it, and `gr` itself is free rather than still holding a stale mapping.
T["lean"]["mini.operators' replace lives at gR, leaving gr free"] = function()
  local maps = child.lua_get([[(function()
    local function d(mode, lhs)
      local m = vim.fn.maparg(lhs, mode, false, true)
      return m.desc or m.rhs or "UNMAPPED"
    end
    return {
      n_gr = d("n", "gr"),
      n_gR = d("n", "gR"),
      n_gRR = d("n", "gRR"),
      x_gR = d("x", "gR"),
    }
  end)()]])
  expect.equality(maps, {
    n_gr = "UNMAPPED",
    n_gR = "Replace",
    n_gRR = "Replace line",
    x_gR = "Replace selection",
  })
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
    -- Module paths WERE plain text; they no longer are. `leanModulePath`
    -- linked to Normal on purpose and that is exactly what was wrong with it:
    -- the first line of every file was the least coloured thing on screen.
    -- The path is now split by POSITION into leanPathC{i} / leanPathDot{i} /
    -- leanPathF{i} (see tests/test_lean_namespaces.lua); this case just pins
    -- that the first component is reached at all.
    { 1, "Mathlib.Data.Real.Basic", "leanPathC1" },
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
      -- snapshot(), not a bare nvim_get_hl: the read shape is not the write
      -- shape (config/hl.lua), and this restore runs in a finally hook where
      -- a throw would leave the colorscheme wrecked for later cases.
      local HL = require("config.hl")
      local normal = HL.snapshot("Normal")
      local func = HL.snapshot("Function")
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

-- ── \y · module name (parity audit #10) ────────────────────────────────
-- Pure resolver, tested in the parent like config.lean.book above: no editor,
-- no server, no filesystem. The cases are the ones MEASURED in a pty-hosted
-- TUI against MIL, where `vim.lsp.get_clients{bufnr=0}[1].root_dir` came back
-- as the MIL project root for a mathlib buffer as well as for a MIL one. That
-- is what makes the naive `path − root` wrong, and it is the second case here.
T["module name"] = new_set()

T["module name"]["resolves project, package and toolchain files"] = function()
  local mn = dofile(H.cfg .. "/lua/config/lean/module_name.lua")
  local root = "/Users/dan/LeanCourse/MathematicsInLean"
  local function of(path)
    local name, err = mn.of(path, root)
    return name or ("ERR: " .. tostring(err))
  end

  -- project source
  expect.equality(
    of(root .. "/MIL/C05_Elementary_Number_Theory/S02_Induction.lean"),
    "MIL.C05_Elementary_Number_Theory.S02_Induction"
  )
  expect.equality(of(root .. "/MIL/Common.lean"), "MIL.Common")

  -- A DEPENDENCY, with the SAME root_dir. Rule 1: the module namespace starts
  -- at the Lake package, not at the workspace. Without it this answers
  -- ".lake.packages.mathlib.Mathlib.Tactic.Ring".
  expect.equality(
    of(root .. "/.lake/packages/mathlib/Mathlib/Tactic/Ring.lean"),
    "Mathlib.Tactic.Ring"
  )
  expect.equality(
    of(root .. "/.lake/packages/batteries/Batteries/Data/List/Basic.lean"),
    "Batteries.Data.List.Basic"
  )
  -- A dependency of a dependency: the INNERMOST .lake/packages wins.
  expect.equality(
    of(root .. "/.lake/packages/mathlib/.lake/packages/Qq/Qq/Macro.lean"),
    "Qq.Macro"
  )

  -- Rule 2: `gd` into core Lean lands under a toolchain, outside every root.
  expect.equality(
    mn.of("/Users/dan/.elan/toolchains/lean4-rich/src/lean/Init/Prelude.lean", root),
    "Init.Prelude"
  )
  expect.equality(
    mn.of("/Users/dan/.elan/toolchains/lean4-rich/src/lean/Init/Prelude.lean", nil),
    "Init.Prelude"
  )
end

T["module name"]["declines rather than inventing a name"] = function()
  local mn = dofile(H.cfg .. "/lua/config/lean/module_name.lua")
  local root = "/proj"
  local function err(path, r)
    local name, e = mn.of(path, r)
    return name == nil and e or ("UNEXPECTED: " .. name)
  end
  expect.equality(err("", root):find("no file name") ~= nil, true)
  expect.equality(err("/proj/notes.md", root):find("not a .lean") ~= nil, true)
  -- Outside the root, outside any package, outside any toolchain.
  expect.equality(err("/elsewhere/Foo.lean", root):find("not inside") ~= nil, true)
  -- No root known and no other rule matches: decline, do not fall back to the
  -- absolute path (which would yield ".Users.dan.…").
  expect.equality(err("/Users/dan/scratch/Foo.lean", nil):find("not inside") ~= nil, true)
end

-- ── :LeanSetupInfo (parity audit #57, #56) ─────────────────────────────
-- The generator is pure — table in, Markdown out — so it is tested in the
-- parent against a fixture, and the elan-shaped fixture below is the SHAPE
-- MEASURED on this machine from a live `require('elan').state()`, directory
-- override and all, not an invented one.
T["setup info"] = new_set()

local ELAN_STATE_FIXTURE = {
  elan_version = { current = "4.2.3" },
  toolchains = {
    active_override = {
      reason = { OverrideDB = "/Users/dan/LeanCourse/MathematicsInLean" },
      unresolved = { Local = { name = "lean4-rich" } },
    },
    default = {
      resolved = { cached = "leanprover/lean4:v4.33.0", live = { Ok = "leanprover/lean4:v4.33.0" } },
      unresolved = { Remote = { origin = "leanprover/lean4", release = "stable" } },
    },
    installed = {
      { path = "/Users/dan/.elan/toolchains/lean4-rich", resolved_name = "lean4-rich" },
      { path = "/x", resolved_name = "leanprover/lean4:v4.30.0" },
    },
    resolved_active = { cached = "lean4-rich", live = { Ok = "lean4-rich" } },
  },
}

T["setup info"]["reads the directory override out of elan.state()"] = function()
  local si = dofile(H.cfg .. "/lua/config/lean/setup_info.lua")
  local e = si.elan_fields(ELAN_STATE_FIXTURE)
  -- The single most load-bearing fact on this machine, and the one the
  -- roadmap worried elan.state() might report badly. It does not.
  expect.equality(e.active, "lean4-rich")
  expect.equality(e.override.name, "lean4-rich")
  expect.equality(e.override.reason, "/Users/dan/LeanCourse/MathematicsInLean")
  expect.equality(e.default, "leanprover/lean4:v4.33.0")
  expect.equality(e.installed, { "lean4-rich", "leanprover/lean4:v4.30.0" })
end

T["setup info"]["survives elan being absent entirely"] = function()
  local si = dofile(H.cfg .. "/lua/config/lean/setup_info.lua")
  local e = si.elan_fields(nil)
  expect.equality(e.active, nil)
  expect.equality(e.override, nil)
  expect.equality(e.installed, {})
  -- ...and rendering must still produce a block rather than throwing.
  local md = si.markdown({ elan = e })
  expect.equality(md:find("### Lean setup information", 1, true), 1)
  expect.equality(md:find("*(not found)*", 1, true) ~= nil, true)
end

T["setup info"]["renders every field it was given"] = function()
  local si = dofile(H.cfg .. "/lua/config/lean/setup_info.lua")
  local md = si.markdown({
    os = "Darwin 25.5.0 (arm64)",
    cpu = "Apple M3 Max x14",
    ram = "36.0 GiB",
    nvim = "0.12.0-dev",
    project = "/Users/dan/LeanCourse/MathematicsInLean",
    file = "/x/S01.lean",
    tools = { curl = "curl 8.7.1", git = "git version 2.49", elan = "elan 4.2.3" },
    elan = si.elan_fields(ELAN_STATE_FIXTURE),
    rich_tokens = "rich",
  })
  for _, needle in ipairs({
    "Darwin 25.5.0 (arm64)",
    "Apple M3 Max x14",
    "36.0 GiB",
    "curl 8.7.1",
    "`lean4-rich` (/Users/dan/LeanCourse/MathematicsInLean)",
    "leanprover/lean4:v4.30.0",
    "| Rich tokens | rich |",
  }) do
    expect.equality({ needle, md:find(needle, 1, true) ~= nil }, { needle, true })
  end
  -- lake and lean were not supplied: absent, not blank or "nil".
  expect.equality(md:find("| lake | *(not found)* |", 1, true) ~= nil, true)
  expect.equality(md:find("nil", 1, true), nil)
end

-- ── unicode input in telescope prompts, and the \la crash (#40, #44) ───
-- lua/config/lean/abbreviations.lua. What needed a real editor — that
-- `\alpha`+space in a prompt produces α, that the column arithmetic survives
-- the prompt prefix, and that <Tab>/<CR> come back to telescope afterwards —
-- was measured in a pty-hosted TUI against MIL and is recorded in that file's
-- header and in the commit. What is checkable here is the wiring.

T["lean"]["abbreviations: the telescope-prompt hook is registered"] = function()
  local n = child.lua_get([[
    #vim.api.nvim_get_autocmds({
      group = "LeanAbbreviationsInPrompts",
      event = "FileType",
      pattern = "TelescopePrompt",
    })
  ]])
  expect.equality(n, 1)
end

-- The hook's whole job. Buffer-SCOPED autocmds, which is what makes this work
-- at all: `enable('TelescopePrompt')` would match a file pattern against a
-- buffer telescope never names, register three autocmds that can never fire,
-- and look installed.
T["lean"]["abbreviations: init_prompt arms a buffer with all three events"] = function()
  local events = child.lua_get([[(function()
    local b = vim.api.nvim_create_buf(false, true)
    local armed = require("config.lean.abbreviations").init_prompt(b)
    local out = {}
    for _, a in ipairs(vim.api.nvim_get_autocmds({ group = "LeanAbbreviations", buffer = b })) do
      table.insert(out, a.event)
    end
    table.sort(out)
    vim.api.nvim_buf_delete(b, { force = true })
    return { armed = armed, events = out }
  end)()]])
  expect.equality(events.armed, true)
  expect.equality(events.events, { "BufLeave", "InsertCharPre", "InsertLeave" })
end

-- Gating, so opening a telescope picker in a Lua buffer does not drag
-- lean.nvim in through lazy's require hook. Checked in the PARENT, which has
-- loaded no plugins at all — the honest "lean.nvim is absent" environment.
T["lean"]["abbreviations: inert when lean.nvim has not loaded"] = function()
  local a = dofile(H.cfg .. "/lua/config/lean/abbreviations.lua")
  expect.equality(a.available(), false)
  expect.equality(a.init_prompt(0), false)
end

-- ── the \la crash (parity audit #44, wrongly recorded as `parity`) ─────
-- `abbreviations.load()` locates its JSON from `debug.getinfo(2, 'S')` — the
-- CALLER's frame — so it works from `lua/lean/*` and throws from anywhere
-- else, including lean.nvim's own telescope extension at
-- lua/telescope/_extensions/lean_abbreviations.lua. `\la` therefore threw on
-- every press while three tests for it passed.
--
-- This calls load() from outside `lua/lean/`, which is exactly the failing
-- call site's situation, and requires a real table back.
T["lean"]["abbreviations: load() works from outside lua/lean (the \\la crash)"] = function()
  local report = child.lua_get([[(function()
    local ok, res = pcall(require("lean.abbreviations").load)
    if not ok then return { ok = false, n = 0, err = tostring(res):sub(1, 120) } end
    local n = 0
    for _ in pairs(res) do n = n + 1 end
    return { ok = true, n = n, alpha = res["alpha"] }
  end)()]])
  expect.equality(report.ok, true)
  -- Non-vacuity: an empty or stub table would satisfy "ok".
  expect.equality(report.n > 1000, true)
  expect.equality(report.alpha, "α")
end

-- ── lean.nvim's snippets reach the completion menu (parity audit #41) ──
-- lean.nvim ships snippets/lean.json through its own package.json and
-- `require('luasnip').get_snippets('lean')` returned 0 in a live MIL buffer.
-- Its own child so the assertion is about a cold start, not about whatever
-- the shared T["lean"] child has already loaded.
T["snippets"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(snippet_child)
      snippet_child.lua([[require("lazy").load({ plugins = { "LuaSnip" } })]])
      snippet_child.lua([[vim.wait(2000, function()
        return package.loaded["luasnip"] ~= nil
      end)]])
    end,
    post_once = function() snippet_child.stop() end,
  },
})

-- Note what is NOT done here: no .lean file is opened, so lean.nvim never
-- loads. That is the strongest form of the claim — the fix resolves the
-- snippet directory from lazy's SPEC rather than from the runtimepath, so it
-- cannot depend on load ordering at all. `enew` + `set ft=lean` fires
-- LuaSnip's FileType hook without matching lean.nvim's `BufReadPre *.lean`.
T["snippets"]["lean.nvim's snippets are loaded"] = function()
  local triggers = snippet_child.lua_get([[(function()
    vim.cmd("enew")
    vim.bo.filetype = "lean"
    vim.wait(1000)
    local out = {}
    for _, s in ipairs(require("luasnip").get_snippets("lean") or {}) do
      table.insert(out, tostring(s.trigger))
    end
    table.sort(out)
    return out
  end)()]])
  -- Measured live in a MIL buffer: five triggers, not the four the audit and
  -- the roadmap both say (`ns` is a second trigger for the namespace snippet).
  expect.equality(triggers, { "calc", "example", "namespace", "ns", "section" })
end

-- The fix is a SECOND lazy_load call and not a `paths` argument on the
-- existing one, because `paths` REPLACES the runtimepath scan
-- (from_vscode.lua:455-474). This is the case that would catch someone
-- "simplifying" the two calls into one and silently unloading
-- friendly-snippets for every other language in the config.
T["snippets"]["friendly-snippets still load for other filetypes"] = function()
  local n = snippet_child.lua_get([[(function()
    vim.cmd("enew")
    vim.bo.filetype = "lua"
    vim.wait(1000)
    return #(require("luasnip").get_snippets("lua") or {})
  end)()]])
  expect.equality(n > 0, true)
end

-- ── \q / \Q · the message census (parity audit #1 and #37) ─────────────
-- The interesting case is the ROADMAP'S TRAP, and it is the reason these two
-- are separate keys: research/12-parity-roadmap.md §3 item 3 prescribes
-- `vim.diagnostic.setqflist({ bufnr = 0 })` for the whole-FILE census, and
-- `setqflist` has no `bufnr` option — `set_list()` leaves the buffer filter
-- nil whenever it is not building a location list
-- (runtime/lua/vim/diagnostic.lua:1004-1015). Written that way, #1 would have
-- shipped as #37 and passed any single-buffer test.
--
-- Diagnostics and list windows work perfectly well headless, so this runs in
-- the parent — no child, no Lean server, no plugins.
T["messages"] = new_set()

local function two_buffers_with_diagnostics()
  local ns = vim.api.nvim_create_namespace("test_lean_messages")
  local a = vim.api.nvim_create_buf(true, true)
  local b = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_lines(a, 0, -1, false, { "one", "two", "three" })
  vim.api.nvim_buf_set_lines(b, 0, -1, false, { "one", "two" })
  local S = vim.diagnostic.severity
  vim.diagnostic.set(ns, a, {
    { lnum = 0, col = 0, message = "A-err", severity = S.ERROR },
    { lnum = 1, col = 0, message = "A-warn1", severity = S.WARN },
    { lnum = 2, col = 0, message = "A-warn2", severity = S.WARN },
  })
  vim.diagnostic.set(ns, b, {
    { lnum = 0, col = 0, message = "B-err", severity = S.ERROR },
  })
  MiniTest.finally(function()
    vim.diagnostic.reset(ns)
    -- `vim.cmd` is a callable TABLE, not a function; wrap it (see 4824293).
    pcall(function() vim.cmd("lclose") end)
    pcall(function() vim.cmd("cclose") end)
    vim.fn.setqflist({})
    vim.api.nvim_buf_delete(a, { force = true })
    vim.api.nvim_buf_delete(b, { force = true })
  end)
  return a, b
end

T["messages"]["setqflist ignores bufnr — the trap that made these two keys"] = function()
  local a = two_buffers_with_diagnostics()
  vim.api.nvim_win_set_buf(0, a)
  -- Exactly the call the roadmap prescribes.
  vim.diagnostic.setqflist({ bufnr = a, open = false })
  local msgs = {}
  for _, item in ipairs(vim.fn.getqflist()) do
    table.insert(msgs, item.text)
  end
  table.sort(msgs)
  -- Non-vacuity: it gathered SOMETHING.
  expect.equality(#msgs, 4)
  -- ...and "something" includes the other buffer's diagnostic, which is the
  -- whole point. If a future Neovim honours `bufnr`, this fails and
  -- config.lean.messages can be simplified — that is a wanted failure.
  expect.equality(vim.tbl_contains(msgs, "B-err"), true)
end

T["messages"]["file() is one buffer, workspace() is all of them"] = function()
  local a = two_buffers_with_diagnostics()
  local m = dofile(H.cfg .. "/lua/config/lean/messages.lua")
  vim.api.nvim_win_set_buf(0, a)
  local win = vim.api.nvim_get_current_win()

  m.file()
  local loc = {}
  for _, item in ipairs(vim.fn.getloclist(win)) do
    table.insert(loc, item.text)
  end
  table.sort(loc)
  expect.equality(loc, { "A-err", "A-warn1", "A-warn2" })
  -- The tally VS Code shows in the All Messages header.
  expect.equality(vim.fn.getloclist(win, { title = 0 }).title, "Lean messages — 1 error, 2 warnings")
  pcall(function() vim.cmd("lclose") end)

  vim.api.nvim_win_set_buf(0, a)
  m.workspace()
  expect.equality(#vim.fn.getqflist(), 4)
  pcall(function() vim.cmd("cclose") end)
end

T["messages"]["tally counts and pluralises"] = function()
  local m = dofile(H.cfg .. "/lua/config/lean/messages.lua")
  expect.equality(m.tally({ error = 0, warn = 0, info = 0, hint = 0, total = 0 }), "No messages")
  expect.equality(
    m.tally({ error = 1, warn = 0, info = 0, hint = 0, total = 1 }),
    "1 error"
  )
  expect.equality(
    m.tally({ error = 2, warn = 1, info = 0, hint = 3, total = 6 }),
    "2 errors, 1 warning, 3 hints"
  )
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

-- ── bindings recovered from the VS Code parity audit ───────────────────
-- research/11-vscode-parity.md §2.2 lists capabilities that were installed,
-- working, and reachable only by typing a command name in full — which the
-- audit counts, correctly, as not reachable at all. These pin the three
-- properties that make a binding real: it EXISTS, it is DISCOVERABLE from the
-- `\` clue window, and it is in the cheatsheet `\?` displays. A binding can
-- fail any one of those independently, so all three are checked per key.
local PARITY_MAPS = {
  { "\\D", "Declaration (parser/elaborator)" },
  { "\\mi", "Imports of this module" },
  { "\\mI", "Modules importing this one" },
  { "\\ll", "Loogle (by type pattern)" },
  { "\\lw", "Workspace symbols (by name)" },
  { "\\la", "Unicode abbreviations" },
  -- Second wave, 2026-08-13: research/12-parity-roadmap.md §3 items 2, 3, 6.
  { "\\y", "Yank module name" },
  { "\\q", "Messages in this file" },
  { "\\Q", "Messages in all buffers" },
  { "\\z", "Fill open goals with sorry" },
  { "\\R", "Restart the Lean SERVER" },
  { "\\k", "Incoming calls" },
  { "\\K", "Outgoing calls" },
  { "\\eg", "Goal, as a popup" },
  { "\\et", "Term goal, as a popup" },
  { "\\em", "Messages on this line" },
}

local parity_parametrize = {}
for _, m in ipairs(PARITY_MAPS) do
  table.insert(parity_parametrize, m)
end

T["lean"]["parity bindings exist, buffer-locally"] = new_set({
  parametrize = parity_parametrize,
}, {
  test = function(lhs, desc)
    local got = child.lua_get(string.format(
      [[(function()
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
          if m.lhs == %q then return m.desc or "" end
        end
        return "MISSING"
      end)()]],
      lhs
    ))
    expect.equality(got, desc)
    -- ...and NOT globally. Every one of these is Lean-specific; a global map
    -- would fire the Lean command from a Lua buffer.
    expect.equality(
      child.lua_get(string.format(
        [[(function()
          for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
            if m.lhs == %q then return true end
          end
          return false
        end)()]],
        lhs
      )),
      false
    )
  end,
})

T["lean"]["parity bindings have mini.clue entries"] = new_set({
  parametrize = parity_parametrize,
}, {
  test = function(lhs, _)
    -- vim.b.miniclue_config stores keys in <LocalLeader> notation.
    local keys = lhs:gsub("^\\", "<LocalLeader>")
    local desc = child.lua_get(string.format(
      [[(function()
        for _, c in ipairs((vim.b.miniclue_config or {}).clues or {}) do
          if c.keys == %q then return c.desc or "" end
        end
        return false
      end)()]],
      keys
    ))
    expect.equality(type(desc), "string")
    expect.no_equality(desc, "")
  end,
})

-- \? renders lean-cheatsheet.md verbatim, so a key absent from that file is a
-- key nobody finds even after pressing the discovery key. Read in the parent:
-- this is a property of the file, not of the child.
T["lean"]["parity bindings are in the cheatsheet"] = new_set({
  parametrize = parity_parametrize,
}, {
  test = function(lhs, _)
    local f = assert(io.open(H.cfg .. "/lean-cheatsheet.md", "r"))
    local text = f:read("*a")
    f:close()
    -- Backticked, as every other key in that file is written.
    expect.equality(text:find("`" .. lhs .. "`", 1, true) ~= nil, true)
  end,
})

-- WHY THE GROUPS ARE \m AND \l AND NOT \s, WHICH WAS THE FIRST CHOICE.
-- lean.nvim owns \s ("Accept the first infoview suggestion"), the key that
-- makes `exact?` and `rw?` worth using. Hanging a group off it would not cost
-- a timeoutlen stall — it would cost the key: mini.clue drives <LocalLeader>
-- and executes only when exactly one clue matches the query (clue.lua:1507),
-- so \s with \s? children under it stops firing until you add a <CR>.
--
-- This case is the guard against re-introducing that shape anywhere: no
-- <LocalLeader> map may be a strict prefix of another, and \s must still be
-- a leaf. Same invariant tests/test_keymap_ownership.lua enforces for <Leader>,
-- which cannot see buffer-local maps and so cannot cover these.
T["lean"]["no <LocalLeader> map is a prefix of another"] = function()
  local report = child.lua_get([[(function()
    local lhs = {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
      if m.lhs:sub(1, 1) == "\\" then table.insert(lhs, m.lhs) end
    end
    local out = {}
    for _, a in ipairs(lhs) do
      for _, b in ipairs(lhs) do
        -- #a > 1 skips the bare `\` map itself: mini.clue's <LocalLeader>
        -- trigger, which manages continuation rather than stalling on it.
        if a ~= b and #a > 1 and b:sub(1, #a) == a then
          table.insert(out, a .. " stalls under " .. b)
        end
      end
    end
    table.sort(out)
    return {
      stalls = table.concat(out, "; "),
      n = #lhs,
      -- The specific key the group prefixes were chosen to protect.
      accept_suggestion = vim.fn.maparg("\\s", "n", false, true).desc or "UNMAPPED",
    }
  end)()]])
  -- Non-vacuity: lean.nvim's own maps alone put a dozen keys here, so an empty
  -- list would mean the scan found nothing rather than nothing being wrong.
  expect.equality(report.n > 10, true)
  expect.equality(report.stalls, "")
  -- And \s is still a working leaf, not a group prefix.
  expect.equality(report.accept_suggestion, "Accept the first infoview suggestion.")
end

-- EVERY `<Cmd>…<CR>` RHS MUST NAME A COMMAND THAT EXISTS.
--
-- The PARITY_MAPS cases above assert a map's `desc`, which is satisfied by a
-- key that throws E492 the moment it is pressed. That is exactly how `\la`
-- shipped broken, and `\R` nearly repeated it: the audit calls `:LspRestart`
-- a Neovim built-in, but it is nvim-lspconfig's, and lspconfig defines none
-- of the `:Lsp*` commands on a Neovim that ships `:lsp`
-- (plugin/lspconfig.lua:6-8). Measured live: exists(":LspRestart") == 0.
--
-- Generic on purpose: it covers every present and future `<Cmd>` binding in
-- the Lean namespace rather than the one that was caught.
T["lean"]["every <Cmd> binding names a real command"] = function()
  local report = child.lua_get([[(function()
    local bad, checked = {}, {}
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
      local rhs = m.rhs or ""
      local name = rhs:match("^<Cmd>(%a[%w_]*)") or rhs:match("^:(%a[%w_]*)")
      if name and m.lhs:sub(1, 1) == "\\" then
        table.insert(checked, m.lhs .. " -> :" .. name)
        if vim.fn.exists(":" .. name) ~= 2 then
          table.insert(bad, m.lhs .. " -> :" .. name .. " (exists=" .. vim.fn.exists(":" .. name) .. ")")
        end
      end
    end
    table.sort(bad); table.sort(checked)
    return { bad = table.concat(bad, "; "), n = #checked, checked = checked }
  end)()]])
  -- Non-vacuity: the Lean namespace has several <Cmd> bindings, so a zero
  -- here would mean the scan found nothing rather than nothing being wrong.
  expect.equality({ n = report.n > 5, checked = report.checked }, { n = true, checked = report.checked })
  expect.equality(report.bad, "")
end

-- Group prefixes are CLUE ENTRIES, NEVER MAPS. mini.clue auto-executes only
-- when exactly one clue matches the query (clue.lua:1507), so mapping `\e`
-- itself would not merely stall `\eg`/`\et`/`\em` — it would stop `\e` firing
-- and need a trailing <CR>. The case above catches the reverse mistake (a
-- live leaf gaining children); this one catches the prefix itself being
-- bound, which that scan cannot see because a mapped `\e` with `\eg` under it
-- IS reported by it — but only if someone reads the failure correctly. This
-- states the rule directly.
T["lean"]["group prefixes have clues and no mapping"] = new_set({
  parametrize = { { "d", "+diff pins" }, { "l", "+lemma search" }, { "m", "+module hierarchy" }, { "e", "+examine (text popups)" } },
}, {
  test = function(letter, desc)
    local report = child.lua_get(string.format(
      [[(function()
        local clue
        for _, c in ipairs((vim.b.miniclue_config or {}).clues or {}) do
          if c.keys == "<LocalLeader>%s" then clue = c.desc end
        end
        local mapped = false
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
          if m.lhs == "\\%s" then mapped = true end
        end
        local children = 0
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
          if #m.lhs > 2 and m.lhs:sub(1, 2) == "\\%s" then children = children + 1 end
        end
        return { clue = clue or "MISSING", mapped = mapped, children = children }
      end)()]],
      letter,
      letter,
      letter
    ))
    expect.equality(report.clue, desc)
    expect.equality(report.mapped, false)
    -- Non-vacuity: a prefix with no children would satisfy "not mapped".
    expect.equality(report.children > 1, true)
  end,
})

-- ── occurrence highlighting ────────────────────────────────────────────
-- lua/config/lean/document_highlight.lua. The server has advertised
-- documentHighlightProvider all along (Watchdog.lean:1579) and nothing called
-- it. Everything below is testable without a Lean server: the gating is
-- ordinary autocmd and client-capability logic, and a five-line in-process LSP
-- client is enough to exercise it. What needed a real one — that the server
-- answers, and that the highlights actually paint — was checked in a
-- pty-hosted TUI against MIL (see the commit).

-- An in-process language server advertising whatever capabilities it is given.
-- Neovim's `cmd`-as-a-function form, so no process is spawned, no Lean is
-- involved, and the capability set is a parameter rather than a fixture.
-- Prefixed onto a chunk that must itself be an expression, hence the wrapper.
local FAKE_LEANLS = [[(function()
  local function make_server(caps)
    return function(dispatchers)
      local closing = false
      return {
        request = function(method, _params, callback)
          if method == "initialize" then
            callback(nil, { capabilities = caps })
          elseif method == "shutdown" then
            callback(nil, nil)
          end
          return true, 1
        end,
        notify = function() return true end,
        is_closing = function() return closing end,
        terminate = function() closing = true; dispatchers.on_exit(0, 0) end,
      }
    end
  end
]]
local END_CHUNK = "\nend)()"

T["lean"]["occurrence highlighting is wired at startup"] = function()
  local events = child.lua_get([[(function()
    local out = {}
    for _, au in ipairs(vim.api.nvim_get_autocmds({ group = "LeanDocumentHighlight" })) do
      if au.buflocal ~= true then table.insert(out, au.event) end
    end
    table.sort(out)
    return out
  end)()]])
  -- The augroup existing at all is the "did the require() ever run" check:
  -- nvim_get_autocmds on an unknown group raises, so a missing wire-up is a
  -- hard error here rather than an empty list.
  expect.equality(events, { "LspAttach", "LspDetach" })
end

-- CursorHold waits 'updatetime', which is global-only — there is no buffer
-- scope for it. At Neovim's default 4000 ms the feature works and is never
-- seen, which is indistinguishable from broken.
T["lean"]["updatetime is short enough for CursorHold to be useful"] = function()
  expect.equality(child.lua_get("vim.o.updatetime") <= 500, true)
end

-- End to end in this child: a real Lean buffer, a real leanls attach (which
-- happens even here, where there is no lakefile — the client starts and
-- advertises documentHighlightProvider whether or not `lake serve` can go on
-- to serve anything), and the pair of autocmds armed on it.
T["lean"]["a real Lean buffer is armed"] = function()
  -- Earlier cases in this shared child :edit away from the probe buffer and
  -- back, which detaches and re-attaches leanls. Arming happens on LspAttach,
  -- which is async, so this must WAIT for it rather than sample once — reading
  -- the list immediately is a race that passes or fails on scheduling. The
  -- assertion below is unchanged; only the sampling is made deterministic.
  local events = child.lua_get([[(function()
    local function armed()
      local buf = vim.fn.bufnr("probe.lean")
      if buf < 0 then return {} end
      local out = {}
      for _, au in ipairs(vim.api.nvim_get_autocmds({
        group = "LeanDocumentHighlight", buffer = buf
      })) do
        table.insert(out, au.event)
      end
      table.sort(out)
      return out
    end
    vim.cmd.edit(vim.fn.fnamemodify(vim.fn.bufname(vim.fn.bufnr("probe.lean")), ":p"))
    vim.wait(8000, function() return #armed() == 4 end)
    return armed()
  end)()]])
  expect.equality(events, { "CursorHold", "CursorMoved", "InsertEnter", "WinLeave" })
end

-- The two gates, measured against clients that differ in exactly one thing
-- each: the capability, and the filetype. Anything else being equal is what
-- makes an empty list mean "the gate held" rather than "the client never
-- started".
T["lean"]["arming is gated on the capability and on the filetype"] = function()
  local got = child.lua_get(FAKE_LEANLS .. [[
    local function probe(ft, caps)
      local buf = vim.api.nvim_create_buf(false, true)
      vim.bo[buf].filetype = ft
      local id = vim.lsp.start(
        { name = "leanls", cmd = make_server(caps) },
        { bufnr = buf, reuse_client = function() return false end }
      )
      vim.wait(2000, function() return id ~= nil and vim.lsp.get_client_by_id(id) ~= nil end)
      local events = {}
      for _, au in ipairs(vim.api.nvim_get_autocmds({
        group = "LeanDocumentHighlight", buffer = buf
      })) do
        table.insert(events, au.event)
      end
      table.sort(events)
      local supported = vim.lsp.get_client_by_id(id)
        :supports_method("textDocument/documentHighlight", buf)
      vim.lsp.stop_client(id, true)
      vim.api.nvim_buf_delete(buf, { force = true })
      return { events = events, supported = supported }
    end
    return {
      capable = probe("lean", { documentHighlightProvider = true }),
      incapable = probe("lean", {}),
      infoview = probe("leaninfo", { documentHighlightProvider = true }),
    }
  ]] .. END_CHUNK)

  -- The control: same fake server, capability on, ordinary Lean buffer.
  expect.equality(got.capable.supported, true)
  expect.equality(
    got.capable.events,
    { "CursorHold", "CursorMoved", "InsertEnter", "WinLeave" }
  )

  -- A server that cannot answer must not be asked once per CursorHold.
  expect.equality(got.incapable.supported, false)
  expect.equality(got.incapable.events, {})

  -- The infoview: identical, capable client — only the filetype differs.
  expect.equality(got.infoview.supported, true)
  expect.equality(got.infoview.events, {})
end

-- The two runtime guards inside the CursorHold callback, which the autocmd
-- list above cannot show. Stubbing vim.lsp.buf.document_highlight is the only
-- way to see "was it called?" without a server that would answer.
--
-- The infoview half matters more than it looks: the autocmds are buffer-scoped
-- to a `lean` buffer, but lean.nvim rewrites buffer contents and filetypes
-- freely, and "the cursor is in a rendered goal state" must never produce
-- highlight requests over pretty-printed text.
T["lean"]["CursorHold fires only in normal mode, and never in the infoview"] = function()
  local calls = child.lua_get(FAKE_LEANLS .. [[
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = "lean"
    local id = vim.lsp.start(
      { name = "leanls", cmd = make_server({ documentHighlightProvider = true }) },
      { bufnr = buf, reuse_client = function() return false end }
    )
    vim.wait(2000, function() return id ~= nil and vim.lsp.get_client_by_id(id) ~= nil end)

    local n = 0
    local real = vim.lsp.buf.document_highlight
    vim.lsp.buf.document_highlight = function() n = n + 1 end

    local out = {}
    local function hold() vim.api.nvim_exec_autocmds("CursorHold", { buffer = buf }) end

    -- 1. normal mode, filetype lean: the whole point.
    hold()
    out.normal = n

    -- 2. insert mode. Genuinely in it, not simulated: `<Cmd>` runs a command
    --    WITHOUT leaving the mode it was pressed in, which is the only way to
    --    observe insert mode from a synchronous test. mode_during is returned
    --    rather than asserted in here so a feedkeys that failed shows up as a
    --    failure instead of a vacuous pass.
    _G.__lean_probe = function()
      out.mode_during = vim.fn.mode()
      hold()
      out.after_insert = n
    end
    vim.api.nvim_feedkeys(vim.keycode("i<Cmd>lua __lean_probe()<CR><Esc>"), "x", false)
    _G.__lean_probe = nil

    -- 3. back in normal mode, but the buffer is now an infoview.
    vim.bo[buf].filetype = "leaninfo"
    hold()
    out.after_leaninfo = n

    vim.lsp.buf.document_highlight = real
    vim.lsp.stop_client(id, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    return out
  ]] .. END_CHUNK)
  expect.equality(calls.mode_during, "i")
  expect.equality(calls.normal, 1)
  -- Both guards hold the count where it was.
  expect.equality(calls.after_insert, 1)
  expect.equality(calls.after_leaninfo, 1)
end

-- ── nvim-lightbulb and satellite.nvim ──────────────────────────────────
-- Both recover VS Code behaviour lean.nvim or the plugin already implements
-- (audit #49, #60, #61). What can be checked without a UI is that they load
-- when they should, that they are configured to be quiet, and — the one with
-- teeth — that neither writes a global option behind the Lean filetype's back.

T["lean"]["nvim-lightbulb loads for Lean and announces only in the sign column"] = function()
  local got = child.lua_get([[(function()
    local spec = require("lazy.core.config").spec.plugins["nvim-lightbulb"]
    local o = spec.opts
    return {
      loaded = require("lazy.core.config").plugins["nvim-lightbulb"]._.loaded ~= nil,
      ft = spec.ft,
      sign = o.sign.enabled,
      -- Every other announcement channel the plugin has. A float would steal
      -- attention mid-proof; virtual text would land on lean.nvim's ⚒ marker.
      noisy = {
        float = o.float.enabled,
        virtual_text = o.virtual_text.enabled,
        status_text = o.status_text.enabled,
        number = o.number.enabled,
        line = o.line.enabled,
      },
      pattern = o.autocmd.pattern,
      events = o.autocmd.events,
      updatetime_opt = o.autocmd.updatetime,
    }
  end)()]])
  -- `ft` is what keeps it unloaded elsewhere; it must have loaded HERE.
  expect.equality(got.ft, "lean")
  expect.equality(got.loaded, true)
  expect.equality(got.sign, true)
  expect.equality(got.noisy, {
    float = false,
    virtual_text = false,
    status_text = false,
    number = false,
    line = false,
  })
  -- `ft` alone leaks: the autocmd is created once and would then fire in every
  -- buffer for the rest of the session. The pattern is the second half.
  expect.equality(got.pattern, { "*.lean" })
  -- CursorHoldI, in the plugin's default set, would flicker while typing.
  expect.equality(got.events, { "CursorHold" })
  -- A NEGATIVE value means "leave 'updatetime' alone". The plugin's default is
  -- to set it to 200 at setup — a global write triggered by opening a Lean
  -- file, which is exactly what the breakat leak case above forbids.
  expect.equality(got.updatetime_opt < 0, true)
end

-- The consequence of the line above, measured rather than inferred: the value
-- lua/config/lean/document_highlight.lua chose at startup is still standing
-- after a Lean buffer (and therefore nvim-lightbulb) has loaded.
T["lean"]["nvim-lightbulb did not rewrite updatetime"] = function()
  expect.equality(child.lua_get("vim.o.updatetime"), 500)
end

T["lean"]["satellite is configured to stay out of lean.nvim's own panes"] = function()
  local got = child.lua_get([[(function()
    local ok, cfg = pcall(require, "satellite.config")
    if not ok then return "satellite.config not loadable" end
    local u = cfg.user_config
    local handlers = {}
    for name, h in pairs(u.handlers or {}) do handlers[name] = h.enable end
    return {
      excluded = u.excluded_filetypes,
      current_only = u.current_only,
      handlers = handlers,
    }
  end)()]])
  -- A scrollbar over a rendered goal state or the server's stderr tail reports
  -- nothing; with current_only it would appear the moment `\<Tab>` moves there.
  expect.equality(got.excluded, { "leaninfo", "leanstderr" })
  expect.equality(got.current_only, true)
  -- The two that justify the plugin, and the stock cursor mark that duplicates
  -- 'relativenumber'.
  expect.equality(got.handlers.diagnostic, true)
  expect.equality(got.handlers.cursor, false)
end

-- lean.nvim ships a Satellite.Handler for whole-file elaboration progress and
-- requires it from nowhere, so it is inert unless the config asks. Registering
-- is not enough either: satellite calls a handler's setup() only from
-- handlers.init(), which runs at the first render — and lean.nvim's handler
-- does not exist yet at that point, because the plugin loads on BufReadPre
-- *.lean. Its setup() is what defines the `leanProgressBar` highlight, so
-- without the by-hand call in lua/plugins/lean.lua the marks are drawn in an
-- undefined group, i.e. invisible.
T["lean"]["lean.nvim's satellite progress handler is registered AND set up"] = function()
  local got = child.lua_get([[(function()
    local ok, sat = pcall(require, "satellite.handlers")
    if not ok then return "satellite.handlers not loadable" end
    local names = {}
    for _, h in ipairs(sat.handlers or {}) do table.insert(names, h.name) end
    table.sort(names)
    return {
      registered = vim.tbl_contains(names, "lean.nvim"),
      all = names,
      -- The augroup exists only if handler.setup() ran.
      setup_ran = pcall(vim.api.nvim_get_autocmds, { group = "LeanSatellite" }),
      progress_hl = vim.api.nvim_get_hl(0, { name = "leanProgressBar", link = false }).fg
        ~= nil,
    }
  end)()]])
  expect.equality(got.registered, true)
  expect.equality(got.setup_ran, true)
  expect.equality(got.progress_hl, true)
  -- Non-vacuity: the builtin handlers must be there too, which is what proves
  -- satellite itself initialised rather than the list happening to hold one
  -- entry. `cursor`, `marks` and `quickfix` are disabled, so absent.
  expect.equality(got.all, { "diagnostic", "gitsigns", "lean.nvim", "search" })
end

return T
