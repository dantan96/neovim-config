-- after/ftplugin/leaninfo.lua — the Lean infoview buffer.
--
-- Runs after lean.nvim's own ftplugin/leaninfo.lua, which sets the window
-- options (winfixbuf, wrap, breakat...). Only the background is ours; see
-- lua/config/lean/infoview_hl.lua for why it is applied through a window
-- highlight namespace instead of 'winhighlight'.
--
-- No autocmds here, and nothing global: tests/test_invariants.lua holds every
-- ftplugin to that.

require("config.lean.infoview_hl").attach(vim.api.nvim_get_current_buf())
