local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local child = MiniTest.new_child_neovim()

local cfg = vim.fn.stdpath("config")

T["options"] = new_set({
  hooks = {
    pre_once = function()
      child.restart({ "-u", cfg .. "/init.lua", "--cmd", "set rtp^=" .. cfg })
      child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
    end,
    post_once = function()
      child.stop()
    end,
  },
})

T["options"]["tabstop=4"] = function()
  expect.equality(child.lua_get("vim.o.tabstop"), 4)
end

T["options"]["shiftwidth=4"] = function()
  expect.equality(child.lua_get("vim.o.shiftwidth"), 4)
end

T["options"]["relativenumber=true"] = function()
  expect.equality(child.lua_get("vim.o.relativenumber"), true)
end

T["options"]["number=true"] = function()
  expect.equality(child.lua_get("vim.o.number"), true)
end

T["options"]["wrap=false"] = function()
  expect.equality(child.lua_get("vim.o.wrap"), false)
end

T["options"]["termguicolors=true"] = function()
  expect.equality(child.lua_get("vim.o.termguicolors"), true)
end

T["options"]["autoread=true"] = function()
  expect.equality(child.lua_get("vim.o.autoread"), true)
end

T["options"]["mapleader=space"] = function()
  expect.equality(child.lua_get("vim.g.mapleader"), " ")
end

T["options"]["maplocalleader=backslash"] = function()
  expect.equality(child.lua_get("vim.g.maplocalleader"), "\\")
end

return T
