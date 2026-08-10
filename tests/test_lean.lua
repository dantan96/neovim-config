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
local tmp_dir

T["lean"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      -- No lakefile here on purpose: lean.nvim finds no project and starts
      -- no language server, so these cases test the config, not the server.
      vim.fn.writefile({ "example : 1 = 1 := rfl" }, tmp_dir .. "/probe.lean")
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
T["lean"]["no deprecation warnings from opening a Lean buffer"] = function()
  local hits = child.lua_get([[(function()
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
  expect.equality(hits, {})
end

-- Configuring through lazy's `opts` is what triggered the deprecation: it makes
-- lazy call require("lean").setup(). The config must reach lean.nvim via the
-- global instead, and must actually be populated.
T["lean"]["configured via vim.g.lean_config, not setup()"] = function()
  expect.equality(child.lua_get("type(vim.g.lean_config)"), "table")
  expect.equality(child.lua_get("vim.g.lean_config.mappings"), true)
  expect.equality(child.lua_get("vim.g.lean_config.infoview.width"), 55)
end

-- textwidth=100 alone hard-wraps Lean terms mid-expression, because the global
-- formatoptions is "tcqj". The ftplugin must drop `t`.
T["lean"]["ftplugin: mathlib style without auto-wrap"] = function()
  expect.equality(child.lua_get("vim.bo.textwidth"), 100)
  expect.equality(child.lua_get("vim.bo.shiftwidth"), 2)
  expect.equality(child.lua_get("vim.bo.expandtab"), true)
  expect.equality(child.lua_get([[vim.bo.formatoptions:find("t") ~= nil]]), false)
  expect.equality(child.lua_get("vim.wo.colorcolumn"), "100")
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
  parametrize = { { "\\?" }, { "\\n" }, { "\\a" }, { "\\f" } },
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

T["lean"]["mini.clue trigger is registered for this buffer"] = function()
  expect.equality(
    child.lua_get([[(vim.b.miniclue_config or {}).triggers ~= nil]]),
    true
  )
end

-- \? reads this at press time; a rename would fail silently into the fallback.
T["lean"]["cheatsheet file exists"] = function()
  local path = H.cfg .. "/lean-cheatsheet.md"
  expect.equality(vim.uv.fs_stat(path) ~= nil, true)
end

return T
