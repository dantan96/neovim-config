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
