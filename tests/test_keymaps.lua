local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["keymaps"] = new_set({
  hooks = {
    pre_once = function() H.setup_child(child) end,
    post_once = function() child.stop() end,
  },
})

-- nvim_get_keymap returns lhs with literal space for <Space>/<leader>
local keymaps = {
  { "n", "  x" },    -- <space><space>x
  { "n", " T" },     -- <leader>T (terminal)
  { "n", " -" },     -- <leader>-
  { "n", " vim" },   -- <leader>vim
  { "n", " p" },     -- <leader>p
  { "n", " y" },     -- <leader>y
  { "n", " d" },     -- <leader>d
  { "n", " lx" },    -- <leader>lx
  { "n", " #" },     -- <leader># (shebang)
  { "n", " ts" },    -- <leader>ts
  { "n", " F" },     -- <leader>F (format)
  { "n", " ha" },    -- <leader>ha
  { "n", " hh" },    -- <leader>hh
}

T["keymaps"]["critical keymaps exist"] = new_set({
  parametrize = keymaps,
}, {
  test = function(mode, lhs)
    expect.equality(H.has_keymap(child, mode, lhs), true)
  end,
})

return T
