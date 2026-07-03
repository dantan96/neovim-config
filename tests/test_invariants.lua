-- tests/test_invariants.lua — config-wide hygiene invariants.
--
-- Unlike the regression tests, these quantify over the WHOLE config, so
-- they catch the next instance of each bug class, not just the ones
-- already found:
--   * every autocmd defined by config code is in an augroup (or once),
--     so re-sourcing can never stack duplicates;
--   * re-sourcing any ftplugin leaves the autocmd population unchanged;
--   * visiting buffers of every configured filetype (plus a terminal
--     and a yank) changes NO global option value;
--   * none of the above produces a deprecation warning.

local new_set = MiniTest.new_set
local expect = MiniTest.expect
local H = dofile("tests/helpers.lua")
local T = new_set()

local child = MiniTest.new_child_neovim()

local tmp_dir

-- One probe file per filetype that has config-level ftplugin/module
-- machinery. Extend this list when a new filetype gains config code.
local PROBES = {
  { "probe.lua", { "return 1" } },
  { "probe.md", { "# hi", "", "text" } },
  { "probe.fs", { "let x = 1" } },
  { "probe.spthy", { "theory T", "begin", "end" } },
  { "probe.py", { "x = 1" } },
  { "probe.sh", { "#!/bin/sh", "true" } },
}

local function write_probes()
  for _, p in ipairs(PROBES) do
    vim.fn.writefile(p[2], tmp_dir .. "/" .. p[1])
  end
end

local function child_edit(name)
  child.lua(string.format("vim.cmd.edit(%q)", tmp_dir .. "/" .. name))
end

T["invariants"] = new_set({
  hooks = {
    pre_once = function()
      H.setup_child(child)
      tmp_dir = vim.fn.tempname()
      vim.fn.mkdir(tmp_dir, "p")
      write_probes()
    end,
    post_once = function()
      child.stop()
      if tmp_dir then
        vim.fn.delete(tmp_dir, "rf")
      end
    end,
  },
})

T["invariants"]["no global option changes from buffer visits"] = function()
  -- Snapshot every global-scope option value. Exclusions, all verified
  -- to be third-party mutations rather than config bugs:
  --  * runtimepath/packpath: lazy.nvim mutates them while lazy-loading
  --    plugins during the exercise;
  --  * wildignore: Neovim's own runtime ftplugin/python.vim does
  --    `set wildignore+=*.pyc` (global-only option; upstream wart).
  child.lua([[
    _G.__opt_snap = {}
    local skip = { runtimepath = true, packpath = true, wildignore = true }
    for name, info in pairs(vim.api.nvim_get_all_options_info()) do
      if info.scope == "global" and not skip[name] then
        _G.__opt_snap[name] = vim.go[name]
      end
    end
  ]])
  -- ...exercise every configured filetype, a terminal, and a yank...
  for _, p in ipairs(PROBES) do
    child_edit(p[1])
  end
  child.lua([[
    vim.cmd.terminal()
    vim.cmd.bwipeout({ bang = true })
    vim.cmd("normal! ggyy")
  ]])
  -- ...and diff. Any entry here is a global option some ftplugin or
  -- autocmd mutated (the vim.opt-vs-vim.opt_local bug class).
  local changed = child.lua_get([[(function()
    local out = {}
    for name, old in pairs(_G.__opt_snap) do
      local now = vim.go[name]
      if not vim.deep_equal(now, old) then
        out[name] = { old = old, new = now }
      end
    end
    return out
  end)()]])
  expect.equality(changed, {})
end

T["invariants"]["config autocmds are grouped (or once)"] = function()
  -- MiniTest runs cases in definition order, so every configured
  -- filetype was already visited by the option-leak case and lazily
  -- registered autocmds exist. Belt and braces: visit them again.
  --
  -- KNOWN BLIND SPOT: only function callbacks can be attributed to the
  -- config via debug.getinfo. Autocmds registered with a command STRING
  -- are invisible here (and Vim's own runtime keeps ~8 ungrouped
  -- command-string Syntax autocmds, so a blanket check would false-
  -- positive). Prefer callbacks over `command =` in config autocmds.
  for _, p in ipairs(PROBES) do
    child_edit(p[1])
  end
  local offenders = child.lua_get(string.format(
    [[(function()
      local cfg = %q
      local out = {}
      for _, au in ipairs(vim.api.nvim_get_autocmds({})) do
        if type(au.callback) == "function" and not au.group and not au.once then
          local info = debug.getinfo(au.callback, "S")
          local src = (info.source or ""):gsub("^@", "")
          if vim.startswith(src, cfg) then
            table.insert(
              out,
              string.format("%%s @ %%s:%%s", au.event, src, info.linedefined)
            )
          end
        end
      end
      return out
    end)()]],
    vim.fn.stdpath("config")
  ))
  expect.equality(offenders, {})
end

T["invariants"]["ftplugin re-source keeps autocmds stable"] = new_set({
  parametrize = (function()
    local p = {}
    for _, probe in ipairs(PROBES) do
      table.insert(p, { probe[1] })
    end
    return p
  end)(),
}, {
  test = function(name)
    -- Count only autocmds whose callback lives in this config: core and
    -- plugins register their own transient machinery per buffer reload
    -- (nvim.diagnostic.buf_wipeout, SafeState, ...), which is not ours
    -- to police. Config-defined autocmds must not grow on re-source.
    local count_config_autocmds = string.format(
      [[(function()
        local cfg = %q
        local n = 0
        for _, au in ipairs(vim.api.nvim_get_autocmds({})) do
          if type(au.callback) == "function" then
            local src = (debug.getinfo(au.callback, "S").source or ""):gsub("^@", "")
            if vim.startswith(src, cfg) then
              n = n + 1
            end
          end
        end
        return n
      end)()]],
      vim.fn.stdpath("config")
    )
    child_edit(name)
    local before = child.lua_get(count_config_autocmds)
    -- Re-source the ftplugin twice via :edit!
    child.lua([[vim.cmd.edit({ bang = true })]])
    child.lua([[vim.cmd.edit({ bang = true })]])
    local after = child.lua_get(count_config_autocmds)
    expect.equality(before, after)
  end,
})

T["invariants"]["no deprecation warnings from config paths"] = function()
  -- By this point the child has visited every configured filetype,
  -- opened a terminal and yanked. The vim.deprecate override in
  -- init.lua only silences plugin-originated warnings, so any config
  -- deprecation would surface via vim.notify. snacks.notifier OWNS
  -- vim.notify in this config (such messages never reach :messages), so
  -- scan both :messages and the snacks history. To prove the detector
  -- is not vacuous, inject a sentinel first and require exactly it.
  local hits = child.lua_get([[(function()
    vim.notify("SENTINEL_fn is deprecated", vim.log.levels.WARN)
    local hits = {}
    local msgs = vim.fn.execute("messages"):lower()
    if msgs:find("deprecated", 1, true) then
      table.insert(hits, "messages")
    end
    local ok, hist = pcall(function()
      return Snacks.notifier.get_history()
    end)
    if ok and hist then
      for _, n in ipairs(hist) do
        local text = tostring(n.msg or ""):lower()
        if text:find("deprecated", 1, true) then
          table.insert(hits, text:sub(1, 80))
        end
      end
    end
    return hits
  end)()]])
  expect.equality(hits, { "sentinel_fn is deprecated" })
end

return T
