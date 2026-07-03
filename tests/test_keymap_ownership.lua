-- tests/test_keymap_ownership.lua — keymap collision discipline.
--
-- Two invariants this config cares about:
--  1. The STALL invariant: no single-key <leader>X map may coexist (in
--     the same mode, globally) with a longer <leader>X... map, or every
--     press of the short one waits for timeoutlen. This config already
--     eliminated several of these (see commit "Eliminate leader-key
--     timeout stalls and collisions"); this test keeps them out.
--  2. OWNERSHIP: keys deliberately ceded to one plugin stay with it —
--     e.g. n/x <Up>/<Down> belong to multicursor (add cursor), not to
--     display-line motion.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

T["ownership"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
    end,
    post_once = function() child.stop() end,
  },
})

-- Fetch all global lhs for a mode, keycodes normalized.
local function mode_lhs(mode)
  return child.lua_get(string.format(
    [[(function()
      local out = {}
      for _, m in ipairs(vim.api.nvim_get_keymap(%q)) do
        table.insert(out, m.lhs)
      end
      return out
    end)()]],
    mode
  ))
end

T["ownership"]["no leader-prefix stalls (normal mode)"] = function()
  local lhs = mode_lhs("n")
  local stalls = {}
  for _, a in ipairs(lhs) do
    for _, b in ipairs(lhs) do
      -- #a > 1 skips the bare <leader> map itself: that's mini.clue's
      -- trigger, which manages continuation without timeoutlen stalls.
      if a ~= b and #a > 1 and a:sub(1, 1) == " " and b:sub(1, #a) == a then
        table.insert(stalls, string.format("%q stalls under %q", a, b))
      end
    end
  end
  expect.equality(table.concat(stalls, "; "), "")
end

T["ownership"]["no leader-prefix stalls (visual mode)"] = function()
  local lhs = mode_lhs("x")
  local stalls = {}
  for _, a in ipairs(lhs) do
    for _, b in ipairs(lhs) do
      -- #a > 1 skips the bare <leader> map itself: that's mini.clue's
      -- trigger, which manages continuation without timeoutlen stalls.
      if a ~= b and #a > 1 and a:sub(1, 1) == " " and b:sub(1, #a) == a then
        table.insert(stalls, string.format("%q stalls under %q", a, b))
      end
    end
  end
  expect.equality(table.concat(stalls, "; "), "")
end

T["ownership"]["multicursor owns n/x arrow keys"] = function()
  local function down_desc()
    return child.lua_get([[(function()
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        -- nvim_get_keymap returns lhs in printable notation ("<Down>")
        if m.lhs == "<Down>" then return m.desc or "" end
      end
      return "UNMAPPED"
    end)()]])
  end
  -- Before multicursor loads (VeryLazy does not fire in the embedded
  -- headless child), nothing else may claim the n-mode arrows — this
  -- catches init.lua reintroducing its display-line arrow maps.
  expect.equality(down_desc(), "UNMAPPED")
  -- After loading, multicursor owns them.
  child.lua([[require("lazy").load({ plugins = { "multicursor.nvim" } })]])
  expect.equality(down_desc(), "MC add cursor below")
end

T["ownership"]["j/k move by display line"] = function()
  local rhs = child.lua_get([[(function()
    for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
      if m.lhs == "j" then return m.rhs or "" end
    end
    return "UNMAPPED"
  end)()]])
  expect.equality(rhs, "gj")
end

-- New-plugin keymaps registered at startup (lazy `keys` handlers create
-- the mapping immediately; the plugin loads on first press).
local plugin_keymaps = {
  { "n", " gg" }, -- lazygit (snacks)
  { "n", " q" }, -- quicker toggle
  { "n", " fr" }, -- grug-far
  { "x", " fr" }, -- grug-far (visual)
  { "n", "<F9>" }, -- dap breakpoint
  { "n", "<F5>" }, -- dap continue
}

T["ownership"]["plugin keymaps exist"] = new_set({
  parametrize = plugin_keymaps,
}, {
  test = function(mode, lhs)
    expect.equality(H.has_keymap(child, mode, lhs), true)
  end,
})

T["ownership"]["gitsigns maps attach to repo buffers"] = function()
  -- init.lua is tracked by the config repo, so gitsigns attaches.
  child.lua(string.format(
    "vim.cmd.edit(%q)",
    vim.fn.stdpath("config") .. "/init.lua"
  ))
  -- Poll from the PARENT: a long child-side vim.wait runs inside an
  -- active RPC request, where gitsigns' async attach callbacks may not
  -- get serviced. Short reads with parent-side sleeps leave the child's
  -- main loop free between checks.
  local attached = false
  for _ = 1, 40 do
    attached = child.lua_get("vim.b.gitsigns_status_dict ~= nil")
    if attached then
      break
    end
    vim.uv.sleep(250)
  end
  expect.equality(attached, true)
  local has = child.lua_get([[(function()
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
      if m.lhs == "]h" then return true end
    end
    return false
  end)()]])
  expect.equality(has, true)
end

return T
