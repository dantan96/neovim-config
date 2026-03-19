local new_set = MiniTest.new_set
local expect = MiniTest.expect
local T = new_set()

local child = MiniTest.new_child_neovim()
local cfg = vim.fn.stdpath("config")

T["keymaps"] = new_set({
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

-- Helper: check if a keymap exists in a given mode
local function has_keymap(mode, lhs)
  local found = child.lua_get(string.format(
    [[
    (function()
      for _, m in ipairs(vim.api.nvim_get_keymap(%q)) do
        if m.lhs == %q then return true end
      end
      return false
    end)()
    ]],
    mode, lhs
  ))
  return found
end

-- nvim_get_keymap returns lhs with literal space for <Space>/<leader>
local keymaps = {
  { "n", "  x" },    -- <space><space>x
  { "n", " st" },    -- <leader>st
  { "n", " -" },     -- <leader>-
  { "n", " vim" },   -- <leader>vim
  { "n", " p" },     -- <leader>p
  { "n", " y" },     -- <leader>y
  { "n", " d" },     -- <leader>d
  { "n", " lx" },    -- <leader>lx
  { "n", " S" },     -- <leader>S
  { "n", " ts" },    -- <leader>ts
  { "n", " f" },     -- <leader>f
  { "n", " ha" },    -- <leader>ha
  { "n", " hh" },    -- <leader>hh
}

T["keymaps"]["critical keymaps exist"] = new_set({
  parametrize = keymaps,
}, {
  test = function(mode, lhs)
    expect.equality(has_keymap(mode, lhs), true)
  end,
})

return T
