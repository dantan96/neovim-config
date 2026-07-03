local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["keymap behavior"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
    pre_case = function()
      child.ensure_normal_mode()
      -- Reset to a clean scratch buffer
      child.cmd("enew!")
      child.lua("vim.api.nvim_buf_set_lines(0, 0, -1, false, {})")
    end,
  },
})

T["keymap behavior"]["<leader># inserts shebang for sh"] = function()
  child.lua("vim.bo.filetype = 'sh'")
  child.type_keys(" #")
  local line1 = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]")
  expect.equality(line1, "#!/usr/bin/env bash")
end

T["keymap behavior"]["<leader># inserts shebang for python"] = function()
  child.lua("vim.bo.filetype = 'python'")
  child.type_keys(" #")
  local line1 = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]")
  expect.equality(line1, "#!/usr/bin/env python3.14")
end

T["keymap behavior"]["<leader># skips when shebang already present"] = function()
  child.lua("vim.bo.filetype = 'sh'")
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {"#!/bin/sh", "echo hi"})]])
  child.type_keys(" #")
  local line1 = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]")
  expect.equality(line1, "#!/bin/sh") -- unchanged
end

T["keymap behavior"]["<leader># uses default for unknown filetype"] = function()
  child.lua("vim.bo.filetype = 'text'")
  child.type_keys(" #")
  local line1 = child.lua_get("vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]")
  expect.equality(line1, "#!/usr/bin/env sh")
end

T["keymap behavior"]["<leader>- opens Oil"] = function()
  child.type_keys(" -")
  child.lua("vim.wait(1000, function() return vim.bo.filetype == 'oil' end)")
  local ft = child.lua_get("vim.bo.filetype")
  expect.equality(ft, "oil")
end

T["keymap behavior"]["<leader>d deletes to void register"] = function()
  child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {"hello", "world"})]])
  -- Set unnamed register to something known first
  child.lua([[vim.fn.setreg('"', 'preserve_me')]])
  child.type_keys("gg", " d", "d") -- go to line 1, <leader>dd deletes line
  -- The unnamed register should NOT contain "hello" — it was voided
  local reg = child.lua_get([[vim.fn.getreg('"')]])
  expect.equality(reg, "preserve_me")
end

T["keymap behavior"]["<leader>lx toggles diagnostics off"] = function()
  local before = child.lua_get("vim.diagnostic.is_enabled({ bufnr = 0 })")
  expect.equality(before, true)
  child.type_keys(" lx")
  local after = child.lua_get("vim.diagnostic.is_enabled({ bufnr = 0 })")
  expect.equality(after, false)
end

T["keymap behavior"]["<leader>lx toggles diagnostics back on"] = function()
  child.type_keys(" lx") -- off
  child.type_keys(" lx") -- on again
  local enabled = child.lua_get("vim.diagnostic.is_enabled({ bufnr = 0 })")
  expect.equality(enabled, true)
end

T["keymap behavior"]["<leader>ts toggles statusline"] = function()
  local before = child.lua_get("vim.o.laststatus")
  child.type_keys(" ts")
  local after = child.lua_get("vim.o.laststatus")
  expect.no_equality(before, after)
end

return T
