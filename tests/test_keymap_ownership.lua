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

-- ── Static cross-file duplicate scan ───────────────────────────────────
-- Two files both defining the same GLOBAL (mode, lhs) means one silently
-- wins by load order — the class of bug where init.lua's <Up>/<Down>
-- display-line maps were dead under multicursor's. Scans literal
-- vim.keymap.set calls (plus per-file `local x = vim.keymap.set`
-- aliases) in global-map territory; buffer-local domains (ftplugins)
-- and lazy `keys` specs (whose stub/real duplication is intentional)
-- are out of scope.
T["ownership"]["no cross-file duplicate global keymaps"] = function()
  local files = { H.cfg .. "/init.lua" }
  vim.list_extend(files, vim.fn.glob(H.cfg .. "/lua/**/*.lua", false, true))
  vim.list_extend(files, vim.fn.glob(H.cfg .. "/after/plugin/*.lua", false, true))

  -- (mode .. lhs) -> { file, ... }
  local defs = {}

  local function note(file, mode, lhs, span)
    -- Skip calls that pass buffer-local opts. Match the assignment form
    -- ("buffer =", "buffer=bufnr"), not the bare word: a desc like
    -- "Delete buffer" must not exempt a global map from the scan.
    if span:find("buffer%s*=") then
      return
    end
    -- Normalize: <leader>/<space> are the same physical key; special
    -- keys are case-insensitive.
    lhs = lhs:gsub("<[Ll]eader>", " "):gsub("<[Ss]pace>", " ")
    if lhs:find("<") then
      lhs = lhs:lower()
    end
    local key = mode .. " " .. lhs
    defs[key] = defs[key] or {}
    if not vim.tbl_contains(defs[key], file) then
      table.insert(defs[key], file)
    end
  end

  for _, file in ipairs(files) do
    local src = table.concat(vim.fn.readfile(file), "\n")
    local callers = { "vim%.keymap%.set" }
    for alias in src:gmatch("local%s+([%w_]+)%s*=%s*vim%.keymap%.set") do
      table.insert(callers, "%f[%w_]" .. alias)
    end
    local Q = "[\"']" -- either quote character
    for _, caller in ipairs(callers) do
      -- form: set("n", "<lhs>", ...)
      local pat1 = caller
        .. "%s*%(%s*"
        .. Q
        .. "([nvxsoitc]+)"
        .. Q
        .. "%s*,%s*"
        .. Q
        .. "([^\"']+)"
        .. Q
        .. "()"
      for mode, lhs, span in src:gmatch(pat1) do
        note(file, mode, lhs, src:sub(span, span + 160))
      end
      -- form: set({ "n", "x" }, "<lhs>", ...)
      local pat2 = caller
        .. "%s*%(%s*(%b{})%s*,%s*"
        .. Q
        .. "([^\"']+)"
        .. Q
        .. "()"
      for modes, lhs, span in src:gmatch(pat2) do
        for mode in modes:gmatch(Q .. "([nvxsoitc]+)" .. Q) do
          note(file, mode, lhs, src:sub(span, span + 160))
        end
      end
    end
  end

  local dups = {}
  for key, where in pairs(defs) do
    if #where > 1 then
      table.insert(
        dups,
        string.format("%q defined in: %s", key, table.concat(where, ", "))
      )
    end
  end
  table.sort(dups)
  expect.equality(table.concat(dups, "\n"), "")
end

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
