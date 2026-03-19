local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["autocmds"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

T["autocmds"]["TextYankPost highlight-yank exists"] = function()
  local count = child.lua_get([[
    #vim.api.nvim_get_autocmds({ group = "highlight-yank", event = "TextYankPost" })
  ]])
  expect.equality(count > 0, true)
end

T["autocmds"]["TermOpen custom-term-open exists"] = function()
  local count = child.lua_get([[
    #vim.api.nvim_get_autocmds({ group = "custom-term-open", event = "TermOpen" })
  ]])
  expect.equality(count > 0, true)
end

T["autocmds"]["FileType=fsharp autocmd exists"] = function()
  local found = child.lua_get([[
    (function()
      for _, a in ipairs(vim.api.nvim_get_autocmds({ event = "FileType", pattern = "fsharp" })) do
        return true
      end
      return false
    end)()
  ]])
  expect.equality(found, true)
end

T["autocmds"]["spthy filetype detection"] = function()
  local ft = child.lua_get([[vim.filetype.match({ filename = "test.spthy" })]])
  expect.equality(ft, "spthy")
end

T["autocmds"]["sapic filetype detection"] = function()
  local ft = child.lua_get([[vim.filetype.match({ filename = "test.sapic" })]])
  expect.equality(ft, "spthy")
end

return T
