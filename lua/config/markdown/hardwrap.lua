-- Per-buffer toggle for markdown auto-hard-wrapping.
--
-- "On" (the ftplugin default) means 'formatoptions' contains 'a'
-- (paragraphs reflow as you edit) and 't' (insert-mode wrap at
-- 'textwidth'): after/ftplugin/markdown.lua appends "aw" and the
-- runtime ftplugin contributes 't'. "Off" removes 'a' and 't' so
-- nvim stops rewriting lines while you type — 'textwidth', the
-- colorcolumn guide and manual gq/gw formatting stay intact.
--
-- The choice is recorded in vim.b.hardwrap_off so a :e reload (which
-- re-runs both ftplugins) restores it instead of silently re-enabling
-- auto-wrap.

local M = {}

-- The two flags that hard-wrap while typing.
local FLAGS = { "a", "t" }

--- Is auto-hard-wrap active in a buffer?
---@param buf integer|nil buffer id (default: current)
---@return boolean
function M.enabled(buf)
  local fo = vim.bo[buf or 0].formatoptions
  for _, f in ipairs(FLAGS) do
    if fo:find(f, 1, true) then
      return true
    end
  end
  return false
end

-- Enforce the state recorded in vim.b.hardwrap_off on the CURRENT
-- buffer. Idempotent; called from after/ftplugin/markdown.lua.
function M.apply()
  for _, f in ipairs(FLAGS) do
    if vim.b.hardwrap_off then
      vim.opt_local.formatoptions:remove(f)
    else
      vim.opt_local.formatoptions:append(f)
    end
  end
end

function M.toggle()
  vim.b.hardwrap_off = M.enabled()
  M.apply()
  vim.notify("hard-wrap " .. (M.enabled() and "on" or "off"))
end

-- Buffer-local wiring: must run for EVERY markdown buffer.
function M.attach()
  M.apply()
  vim.keymap.set("n", "<leader>tw", M.toggle, {
    buffer = true,
    desc = "Toggle hard-wrap (markdown)",
  })
end

-- Global command: registered once (under the ftplugin's once-guard).
function M.setup()
  vim.api.nvim_create_user_command("HardWrapToggle", M.toggle, {
    desc = "Toggle auto hard-wrap ('formatoptions' a/t) for this buffer",
  })
end

return M
