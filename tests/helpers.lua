-- tests/helpers.lua — shared test utilities
local H = {}
local cfg = vim.fn.stdpath("config")

H.cfg = cfg
H.child_args = { "-u", cfg .. "/init.lua", "--cmd", "set rtp^=" .. cfg }

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
