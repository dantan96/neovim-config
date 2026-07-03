-- tests/test_option_scope.lua — option SCOPE discipline.
--
-- Guards against the "global where local was intended" bug class: the
-- TermOpen handler used to set vim.opt.number (global), silently
-- re-enabling numbers session-wide whenever a terminal opened. Also
-- pins the ftplugin-local overrides and checks they never leak into
-- globals.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

local tmp_dir

T["option scope"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

T["option scope"]["TermOpen does not resurrect global number"] = function()
  child.lua([[
    vim.o.number = false
    vim.o.relativenumber = false
    vim.cmd.terminal()
  ]])
  -- Window-local values are set for the terminal window...
  expect.equality(child.lua_get("vim.wo.number"), true)
  expect.equality(child.lua_get("vim.wo.relativenumber"), true)
  -- ...but the GLOBAL values must stay off (this was the bug).
  expect.equality(child.lua_get("vim.go.number"), false)
  expect.equality(child.lua_get("vim.go.relativenumber"), false)
  -- restore for later cases
  child.lua([[
    vim.cmd.bwipeout({ bang = true })
    vim.o.number = true
    vim.o.relativenumber = true
  ]])
end

local function edit_tmp(name, lines)
  local path = tmp_dir .. "/" .. name
  vim.fn.writefile(lines or { "" }, path)
  child.lua(string.format("vim.cmd.edit(%q)", path))
  return path
end

T["option scope"]["lua ftplugin sets full 2-space block locally"] = function()
  edit_tmp("scope_probe.lua", { "return 1" })
  expect.equality(child.lua_get("vim.bo.shiftwidth"), 2)
  expect.equality(child.lua_get("vim.bo.tabstop"), 2)
  expect.equality(child.lua_get("vim.bo.softtabstop"), 2)
  expect.equality(child.lua_get("vim.bo.expandtab"), true)
  -- globals untouched
  expect.equality(child.lua_get("vim.go.shiftwidth"), 4)
  expect.equality(child.lua_get("vim.go.tabstop"), 4)
end

T["option scope"]["fsharp ftplugin sets 4-space + comments locally"] = function()
  edit_tmp("scope_probe.fs", { "let x = 1" })
  expect.equality(child.lua_get("vim.bo.shiftwidth"), 4)
  expect.equality(child.lua_get("vim.bo.expandtab"), true)
  expect.equality(child.lua_get("vim.bo.commentstring"), "// %s")
  expect.equality(child.lua_get("vim.bo.comments"), ":///,://!,://")
end

T["option scope"]["markdown ftplugin sets textwidth locally"] = function()
  edit_tmp("scope_probe.md", { "# hi" })
  expect.equality(child.lua_get("vim.bo.textwidth"), 65)
  -- global textwidth must not have been dragged along
  expect.equality(child.lua_get("vim.go.textwidth"), 0)
end

T["option scope"]["ftplugin visits leave globals intact"] = function()
  -- After editing lua, fsharp and markdown buffers above, the global
  -- indent contract from init.lua must still hold.
  expect.equality(child.lua_get("vim.go.shiftwidth"), 4)
  expect.equality(child.lua_get("vim.go.tabstop"), 4)
  expect.equality(child.lua_get("vim.go.number"), true)
  expect.equality(child.lua_get("vim.go.relativenumber"), true)
end

return T
