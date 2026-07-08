-- Per-buffer toggle for markdown LIVE hard-wrapping.
--
-- Default is OFF: type freely with no auto-wrap; prettier
-- (lua/plugins/format.lua, --prose-wrap always) hard-wraps the file
-- at 'textwidth' on save and never breaks inside a `backtick span`.
-- Vim's internal formatter, by contrast, splits spans that contain
-- spaces — so toggling live wrap ON (the formatoptions flags 'a',
-- paragraphs reflow as you edit, and 't', insert-mode wrap at
-- 'textwidth') accepts that a span may sit split on screen until the
-- next save repairs it.
--
-- The choice is recorded in vim.b.hardwrap_live so a :e reload
-- (which re-runs both ftplugins) restores it instead of silently
-- resetting to the default.

local M = {}

-- The two flags that hard-wrap while typing.
local FLAGS = { "a", "t" }

--- Is live hard-wrap active in a buffer?
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

-- Enforce the state recorded in vim.b.hardwrap_live on the CURRENT
-- buffer. Idempotent; called from after/ftplugin/markdown.lua (which
-- runs after $VIMRUNTIME/ftplugin/markdown.vim has added 't').
function M.apply()
  for _, f in ipairs(FLAGS) do
    if vim.b.hardwrap_live then
      vim.opt_local.formatoptions:append(f)
    else
      vim.opt_local.formatoptions:remove(f)
    end
  end
end

function M.toggle()
  vim.b.hardwrap_live = not M.enabled()
  M.apply()
  vim.notify("live hard-wrap " .. (M.enabled() and "on" or "off"))
end

-- Buffer-local wiring: must run for EVERY markdown buffer.
function M.attach()
  M.apply()
  vim.keymap.set("n", "<leader>tw", M.toggle, {
    buffer = true,
    desc = "Toggle live hard-wrap (markdown)",
  })
end

-- Global command: registered once (under the ftplugin's once-guard).
function M.setup()
  vim.api.nvim_create_user_command("HardWrapToggle", M.toggle, {
    desc = "Toggle live hard-wrap ('formatoptions' a/t) for this buffer",
  })
end

return M
