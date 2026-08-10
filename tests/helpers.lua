-- tests/helpers.lua — shared test utilities
local H = {}
local cfg = vim.fn.stdpath("config")

H.cfg = cfg
-- noswapfile + shortmess+=A: test children may open files that other
-- (possibly killed) test/probe sessions also touched; without these, an
-- existing swap file triggers the ATTENTION path and a headless child
-- silently ends up with an empty buffer — flaky tests.
H.child_args = {
  "-u",
  cfg .. "/init.lua",
  "--cmd",
  "set rtp^=" .. cfg,
  "--cmd",
  "set noswapfile shortmess+=A",
  -- Children inherit the parent environment: without this scrub, running the
  -- suite from a derived Ghostty profile (GhosttyNu/GhosttyXonsh inject
  -- GHOSTTY_NVIM_THEME) would flip the profile-theme path mid-suite. Empty
  -- string reads as "absent" in config.ghostty_profile.
  "--cmd",
  "let $GHOSTTY_NVIM_THEME = ''",
}

-- Start child neovim with full config loaded
function H.setup_child(child)
  child.restart(H.child_args)
  child.lua([[vim.wait(5000, function() return pcall(require, "lazy") end)]])
end

-- LSP configs live in EITHER lsp/ or after/lsp/. The after/ copies are
-- not stylistic: nvim-lspconfig ships its own lsp/<name>.lua, and on a
-- plain lsp/ file its values win the tbl_deep_extend, silently dropping
-- ours (35d1c1d, 25f9964). Tests must resolve by search, not by a
-- hardcoded dir — hardcoding "/lsp/" is exactly what left four tests
-- failing after remark_ls moved.

--- Path to an lsp config, after/ taking precedence (as rtp does).
---@param name string server name, no extension
---@return string|nil
function H.lsp_config_path(name)
  for _, dir in ipairs({ "/after/lsp/", "/lsp/" }) do
    local p = cfg .. dir .. name .. ".lua"
    if vim.uv.fs_stat(p) then
      return p
    end
  end
end

--- Every lsp config present, discovered rather than listed, so a new
--- server is covered the moment it lands.
---@return string[] sorted server names
function H.lsp_config_names()
  local seen, names = {}, {}
  for _, dir in ipairs({ "/lsp/", "/after/lsp/" }) do
    for _, p in ipairs(vim.fn.glob(cfg .. dir .. "*.lua", false, true)) do
      local n = vim.fn.fnamemodify(p, ":t:r")
      if not seen[n] then
        seen[n] = true
        table.insert(names, n)
      end
    end
  end
  table.sort(names)
  return names
end

-- Temp dir with guaranteed cleanup via finally()
function H.with_temp_dir(fn)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  MiniTest.finally(function()
    vim.fn.delete(dir, "rf")
  end)
  return fn(dir)
end

-- Check keymap exists (child must be running)
function H.has_keymap(child, mode, lhs)
  return child.lua_get(string.format(
    [[(function()
      for _, m in ipairs(vim.api.nvim_get_keymap(%q)) do
        if m.lhs == %q then return true end
      end
      return false
    end)()]],
    mode, lhs
  ))
end

-- Check command exists (child must be running)
function H.cmd_exists(child, name)
  return child.lua_get(string.format('vim.fn.exists(":%s") == 2', name))
end

return H
